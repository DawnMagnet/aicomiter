use std::{env, fs, path::PathBuf};

use secrecy::{ExposeSecret, SecretString};
use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::cli::{ConfigArgs, ProviderArg};

const CONFIG_FILE: &str = ".aicomiter.yaml";

#[derive(Debug, Clone, Copy, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Provider {
    #[default]
    Openai,
    Anthropic,
}

#[derive(Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct AiConfig {
    pub provider: Provider,
    pub api_key: SecretString,
    pub api_key_env: Option<String>,
    pub api_key_file: Option<PathBuf>,
    pub base_url: Option<String>,
    pub model: Option<String>,
    pub temperature: f64,
    pub top_p: f64,
    pub max_tokens: u32,
    pub timeout: u64,
}

impl Default for AiConfig {
    fn default() -> Self {
        Self {
            provider: Provider::Openai,
            api_key: SecretString::from(String::new()),
            api_key_env: None,
            api_key_file: None,
            base_url: None,
            model: None,
            temperature: 0.7,
            top_p: 1.0,
            max_tokens: 500,
            timeout: 30,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct GenerateConfig {
    pub language: String,
    pub count: u8,
    /// Built-in template name or custom template text.
    pub template: Option<String>,
}

impl Default for GenerateConfig {
    fn default() -> Self {
        Self {
            language: "en".into(),
            count: 1,
            template: None,
        }
    }
}

#[derive(Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Config {
    pub ai: AiConfig,
    pub generate: GenerateConfig,
}

#[derive(Clone)]
pub struct LoadedConfig {
    pub value: Config,
    pub source: ConfigSource,
}

#[derive(Debug, Clone)]
pub enum ConfigSource {
    Defaults,
    File(PathBuf),
}

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("could not determine the user's home directory")]
    HomeUnavailable,
    #[error("failed to read configuration at {path}: {source}")]
    Read {
        path: PathBuf,
        source: std::io::Error,
    },
    #[error("invalid configuration at {path}: {source}")]
    Parse {
        path: PathBuf,
        source: serde_yml::Error,
    },
    #[error("invalid configuration: {0}")]
    Validation(String),
    #[error("failed to read API key file at {path}: {source}")]
    ApiKeyFile {
        path: PathBuf,
        source: std::io::Error,
    },
}

impl Config {
    pub fn load(args: &ConfigArgs) -> Result<LoadedConfig, ConfigError> {
        let path = match &args.config {
            Some(path) => Some(path.clone()),
            None => default_path().filter(|path| path.exists()),
        };

        let (mut value, source) = match path {
            Some(path) => {
                let content = fs::read_to_string(&path).map_err(|source| ConfigError::Read {
                    path: path.clone(),
                    source,
                })?;
                let config =
                    serde_yml::from_str(&content).map_err(|source| ConfigError::Parse {
                        path: path.clone(),
                        source,
                    })?;
                (config, ConfigSource::File(path))
            }
            None => (Self::default(), ConfigSource::Defaults),
        };

        value.validate_api_key_source()?;
        value.resolve_api_key()?;
        value.apply_environment();
        value.apply_cli(args);
        value.validate()?;
        Ok(LoadedConfig { value, source })
    }

    fn resolve_api_key(&mut self) -> Result<(), ConfigError> {
        self.resolve_api_key_with(&|name| env::var(name).ok())
    }

    fn resolve_api_key_with(
        &mut self,
        get_env: &dyn Fn(&str) -> Option<String>,
    ) -> Result<(), ConfigError> {
        let api_key = if !self.ai.api_key.expose_secret().is_empty() {
            self.ai.api_key.expose_secret().to_owned()
        } else if let Some(name) = &self.ai.api_key_env {
            get_env(name)
                .filter(|value| !value.is_empty())
                .unwrap_or_default()
        } else if let Some(path) = &self.ai.api_key_file {
            fs::read_to_string(path)
                .map_err(|source| ConfigError::ApiKeyFile {
                    path: path.clone(),
                    source,
                })?
                .trim()
                .to_owned()
        } else {
            first_value(
                &[
                    "AICOMITER_AI_API_KEY",
                    "OPENAI_API_KEY",
                    "ANTHROPIC_API_KEY",
                    "API_KEY",
                ],
                get_env,
            )
            .unwrap_or_default()
        };
        self.ai.api_key = SecretString::from(api_key);
        Ok(())
    }

    fn apply_environment(&mut self) {
        self.apply_environment_with(&|name| env::var(name).ok());
    }

    fn apply_environment_with(&mut self, get_env: &dyn Fn(&str) -> Option<String>) {
        set_first_option_with(
            &mut self.ai.base_url,
            &["AICOMITER_AI_BASE_URL", "OPENAI_API_BASE", "API_BASE_URL"],
            get_env,
        );
        if let Some(value) = first_value(&["AICOMITER_AI_PROVIDER"], get_env) {
            self.ai.provider = match value.to_ascii_lowercase().as_str() {
                "anthropic" => Provider::Anthropic,
                _ => Provider::Openai,
            };
        }
        set_first_option_with(
            &mut self.ai.model,
            &["AICOMITER_AI_MODEL", "MODEL"],
            get_env,
        );
        if let Some(value) = first_value(&["AICOMITER_GENERATE_LANGUAGE"], get_env) {
            self.generate.language = value;
        }
        set_first_option_with(
            &mut self.generate.template,
            &["AICOMITER_GENERATE_TEMPLATE"],
            get_env,
        );
    }

    fn apply_cli(&mut self, args: &ConfigArgs) {
        if let Some(value) = args.provider {
            self.ai.provider = match value {
                ProviderArg::Openai => Provider::Openai,
                ProviderArg::Anthropic => Provider::Anthropic,
            };
        }
        if let Some(value) = &args.api_key {
            self.ai.api_key = SecretString::from(value.clone());
        }
        assign(&mut self.ai.base_url, &args.base_url);
        assign(&mut self.ai.model, &args.model);
        assign_copy(&mut self.ai.temperature, args.temperature);
        assign_copy(&mut self.ai.top_p, args.top_p);
        assign_copy(&mut self.ai.max_tokens, args.max_tokens);
        assign_copy(&mut self.ai.timeout, args.timeout);
        if let Some(value) = &args.language {
            self.generate.language.clone_from(value);
        }
        assign(&mut self.generate.template, &args.template);
        assign_copy(&mut self.generate.count, args.count);
    }

    fn validate_api_key_source(&self) -> Result<(), ConfigError> {
        let configured_sources = usize::from(!self.ai.api_key.expose_secret().is_empty())
            + usize::from(self.ai.api_key_env.is_some())
            + usize::from(self.ai.api_key_file.is_some());
        if configured_sources > 1 {
            return Err(ConfigError::Validation(
                "only one of ai.api_key, ai.api_key_env, and ai.api_key_file may be set".into(),
            ));
        }
        if self.ai.api_key_env.as_deref().is_some_and(str::is_empty) {
            return Err(ConfigError::Validation(
                "ai.api_key_env cannot be empty".into(),
            ));
        }
        Ok(())
    }

    fn validate(&self) -> Result<(), ConfigError> {
        if !(0.0..=2.0).contains(&self.ai.temperature) {
            return Err(ConfigError::Validation(
                "ai.temperature must be between 0 and 2".into(),
            ));
        }
        if !(0.0..=1.0).contains(&self.ai.top_p) {
            return Err(ConfigError::Validation(
                "ai.top_p must be between 0 and 1".into(),
            ));
        }
        if self.ai.max_tokens == 0 || self.ai.timeout == 0 {
            return Err(ConfigError::Validation(
                "ai.max_tokens and ai.timeout must be positive".into(),
            ));
        }
        if !(1..=10).contains(&self.generate.count) {
            return Err(ConfigError::Validation(
                "generate.count must be between 1 and 10".into(),
            ));
        }
        if self.generate.language.trim().is_empty() {
            return Err(ConfigError::Validation(
                "generate.language cannot be empty".into(),
            ));
        }
        if self
            .generate
            .template
            .as_deref()
            .is_some_and(|template| template.trim().is_empty())
        {
            return Err(ConfigError::Validation(
                "generate.template cannot be empty".into(),
            ));
        }
        if self.generate.template.as_deref().is_some_and(|template| {
            template.chars().count() > crate::message_template::MAX_TEMPLATE_LENGTH
        }) {
            return Err(ConfigError::Validation(format!(
                "generate.template cannot exceed {} characters",
                crate::message_template::MAX_TEMPLATE_LENGTH
            )));
        }
        Ok(())
    }

    pub fn redacted(&self) -> RedactedConfig<'_> {
        RedactedConfig {
            ai: RedactedAiConfig {
                provider: self.ai.provider,
                api_key: "***hidden***",
                api_key_env: self.ai.api_key_env.as_deref(),
                api_key_file: self.ai.api_key_file.as_deref(),
                base_url: self.ai.base_url.as_deref(),
                model: self.ai.model.as_deref(),
                temperature: self.ai.temperature,
                top_p: self.ai.top_p,
                max_tokens: self.ai.max_tokens,
                timeout: self.ai.timeout,
            },
            generate: &self.generate,
        }
    }

    pub fn has_api_key(&self) -> bool {
        !self.ai.api_key.expose_secret().is_empty()
    }
}

#[derive(Serialize)]
pub struct RedactedConfig<'a> {
    ai: RedactedAiConfig<'a>,
    generate: &'a GenerateConfig,
}

#[derive(Serialize)]
struct RedactedAiConfig<'a> {
    provider: Provider,
    api_key: &'static str,
    api_key_env: Option<&'a str>,
    api_key_file: Option<&'a std::path::Path>,
    base_url: Option<&'a str>,
    model: Option<&'a str>,
    temperature: f64,
    top_p: f64,
    max_tokens: u32,
    timeout: u64,
}

pub fn default_path() -> Option<PathBuf> {
    env::var_os("HOME")
        .or_else(|| env::var_os("USERPROFILE"))
        .map(PathBuf::from)
        .map(|home| home.join(CONFIG_FILE))
}

fn first_value(names: &[&str], get_env: &dyn Fn(&str) -> Option<String>) -> Option<String> {
    names
        .iter()
        .find_map(|name| get_env(name).filter(|value| !value.is_empty()))
}

fn set_first_option_with(
    target: &mut Option<String>,
    names: &[&str],
    get_env: &dyn Fn(&str) -> Option<String>,
) {
    if let Some(value) = first_value(names, get_env) {
        *target = Some(value);
    }
}

fn assign(target: &mut Option<String>, source: &Option<String>) {
    if let Some(value) = source {
        *target = Some(value.clone());
    }
}

fn assign_copy<T: Copy>(target: &mut T, source: Option<T>) {
    if let Some(value) = source {
        *target = value;
    }
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use super::*;

    fn config(yaml: &str) -> Config {
        serde_yml::from_str(yaml).unwrap()
    }

    fn environment<'a>(values: &'a [(&'a str, &'a str)]) -> impl Fn(&str) -> Option<String> + 'a {
        move |name| {
            values
                .iter()
                .find_map(|(key, value)| (*key == name).then(|| (*value).to_owned()))
        }
    }

    #[test]
    fn parses_nested_yaml_and_redacts_secret() {
        let config = config(
            "ai:\n  provider: anthropic\n  api_key: secret\n  temperature: 0.4\ngenerate:\n  language: zh\n  count: 3\n",
        );

        assert_eq!(config.ai.provider, Provider::Anthropic);
        assert_eq!(config.generate.count, 3);
        let json = serde_json::to_string(&config.redacted()).unwrap();
        assert!(!json.contains("secret"));
        assert!(json.contains("***hidden***"));
    }

    #[test]
    fn redacted_config_preserves_credential_source_metadata() {
        let config = config("ai:\n  api_key_env: OPENAI_API_KEY\n");

        let json = serde_json::to_string(&config.redacted()).unwrap();
        assert!(json.contains("OPENAI_API_KEY"));
        assert!(json.contains("***hidden***"));
    }

    #[test]
    fn rejects_unknown_fields() {
        assert!(serde_yml::from_str::<Config>("ai:\n  typo: value\n").is_err());
    }

    #[test]
    fn rejects_each_pair_of_api_key_sources() {
        for yaml in [
            "ai:\n  api_key: secret\n  api_key_env: OPENAI_API_KEY\n",
            "ai:\n  api_key: secret\n  api_key_file: /run/secrets/openai\n",
            "ai:\n  api_key_env: OPENAI_API_KEY\n  api_key_file: /run/secrets/openai\n",
        ] {
            let config = config(yaml);
            assert!(matches!(
                config.validate_api_key_source(),
                Err(ConfigError::Validation(message)) if message.contains("only one")
            ));
        }
    }

    #[test]
    fn rejects_empty_api_key_environment_variable_name() {
        let config = config("ai:\n  api_key_env: ''\n");

        assert!(matches!(
            config.validate_api_key_source(),
            Err(ConfigError::Validation(message)) if message == "ai.api_key_env cannot be empty"
        ));
    }

    #[test]
    fn explicit_api_key_takes_precedence_over_available_environment_values() {
        let mut config = config("ai:\n  api_key: configured-secret\n");
        let get_env = environment(&[("AICOMITER_AI_API_KEY", "environment-secret")]);

        config.resolve_api_key_with(&get_env).unwrap();

        assert_eq!(config.ai.api_key.expose_secret(), "configured-secret");
    }

    #[test]
    fn resolves_api_key_from_named_environment_variable() {
        let mut config = config("ai:\n  api_key_env: CUSTOM_API_KEY\n");
        let get_env = environment(&[
            ("CUSTOM_API_KEY", "custom-secret"),
            ("AICOMITER_AI_API_KEY", "fallback-secret"),
        ]);

        config.resolve_api_key_with(&get_env).unwrap();

        assert_eq!(config.ai.api_key.expose_secret(), "custom-secret");
    }

    #[test]
    fn named_environment_variable_does_not_fall_back_when_missing() {
        let mut config = config("ai:\n  api_key_env: CUSTOM_API_KEY\n");
        let get_env = environment(&[("AICOMITER_AI_API_KEY", "fallback-secret")]);

        config.resolve_api_key_with(&get_env).unwrap();

        assert!(!config.has_api_key());
    }

    #[test]
    fn default_api_key_environment_variables_follow_documented_priority() {
        let mut config = Config::default();
        let get_env = environment(&[
            ("API_KEY", "generic-secret"),
            ("ANTHROPIC_API_KEY", "anthropic-secret"),
            ("OPENAI_API_KEY", "openai-secret"),
            ("AICOMITER_AI_API_KEY", "preferred-secret"),
        ]);

        config.resolve_api_key_with(&get_env).unwrap();

        assert_eq!(config.ai.api_key.expose_secret(), "preferred-secret");
    }

    #[test]
    fn empty_default_environment_values_are_skipped() {
        let mut config = Config::default();
        let get_env = environment(&[
            ("AICOMITER_AI_API_KEY", ""),
            ("OPENAI_API_KEY", "openai-secret"),
        ]);

        config.resolve_api_key_with(&get_env).unwrap();

        assert_eq!(config.ai.api_key.expose_secret(), "openai-secret");
    }

    #[test]
    fn resolves_api_key_from_file_and_trims_surrounding_whitespace() {
        let mut file = tempfile::NamedTempFile::new().unwrap();
        writeln!(file, "  file-secret  ").unwrap();
        let mut config = config(&format!("ai:\n  api_key_file: {}\n", file.path().display()));

        config.resolve_api_key_with(&environment(&[])).unwrap();

        assert_eq!(config.ai.api_key.expose_secret(), "file-secret");
    }

    #[test]
    fn reports_api_key_file_read_errors_with_the_path() {
        let path = PathBuf::from("/definitely/missing/aicomiter-api-key");
        let mut config = config(&format!("ai:\n  api_key_file: {}\n", path.display()));

        assert!(matches!(
            config.resolve_api_key_with(&environment(&[])),
            Err(ConfigError::ApiKeyFile { path: error_path, .. }) if error_path == path
        ));
    }

    #[test]
    fn environment_overrides_non_secret_file_values() {
        let mut configured = config(
            "ai:\n  provider: openai\n  base_url: https://configured.example\n  model: configured-model\ngenerate:\n  language: en\n",
        );
        let get_env = environment(&[
            ("AICOMITER_AI_PROVIDER", "anthropic"),
            ("AICOMITER_AI_BASE_URL", "https://environment.example"),
            ("AICOMITER_AI_MODEL", "environment-model"),
            ("AICOMITER_GENERATE_LANGUAGE", "zh"),
        ]);

        configured.apply_environment_with(&get_env);

        assert_eq!(configured.ai.provider, Provider::Anthropic);
        assert_eq!(
            configured.ai.base_url.as_deref(),
            Some("https://environment.example")
        );
        assert_eq!(configured.ai.model.as_deref(), Some("environment-model"));
        assert_eq!(configured.generate.language, "zh");

        let mut template_config = config("generate:\n  template: simple\n");
        template_config
            .apply_environment_with(&environment(&[("AICOMITER_GENERATE_TEMPLATE", "angular")]));
        assert_eq!(
            template_config.generate.template.as_deref(),
            Some("angular")
        );
    }

    #[test]
    fn cli_values_override_environment_and_file_values() {
        let mut configured = config(
            "ai:\n  provider: openai\n  api_key: file-secret\n  base_url: https://configured.example\n  model: configured-model\n  temperature: 0.1\ngenerate:\n  language: en\n  count: 1\n",
        );
        configured.apply_environment_with(&environment(&[
            ("AICOMITER_AI_PROVIDER", "anthropic"),
            ("AICOMITER_AI_BASE_URL", "https://environment.example"),
            ("AICOMITER_AI_MODEL", "environment-model"),
        ]));
        let args = ConfigArgs {
            provider: Some(ProviderArg::Openai),
            api_key: Some("cli-secret".into()),
            base_url: Some("https://cli.example".into()),
            model: Some("cli-model".into()),
            temperature: Some(0.9),
            language: Some("ja".into()),
            template: Some("{type}: {subject}".into()),
            count: Some(3),
            ..ConfigArgs::default()
        };

        configured.apply_cli(&args);

        assert_eq!(configured.ai.provider, Provider::Openai);
        assert_eq!(configured.ai.api_key.expose_secret(), "cli-secret");
        assert_eq!(
            configured.ai.base_url.as_deref(),
            Some("https://cli.example")
        );
        assert_eq!(configured.ai.model.as_deref(), Some("cli-model"));
        assert_eq!(configured.ai.temperature, 0.9);
        assert_eq!(configured.generate.language, "ja");
        assert_eq!(
            configured.generate.template.as_deref(),
            Some("{type}: {subject}")
        );
        assert_eq!(configured.generate.count, 3);
    }

    #[test]
    fn template_is_optional_but_empty_and_oversized_values_are_rejected() {
        assert!(Config::default().validate().is_ok());

        let mut config = Config::default();
        config.generate.template = Some("  ".into());
        assert!(
            matches!(config.validate(), Err(ConfigError::Validation(message)) if message.contains("template cannot be empty"))
        );

        config.generate.template =
            Some("x".repeat(crate::message_template::MAX_TEMPLATE_LENGTH + 1));
        assert!(
            matches!(config.validate(), Err(ConfigError::Validation(message)) if message.contains("cannot exceed"))
        );
    }

    #[test]
    fn custom_and_builtin_templates_round_trip_through_yaml() {
        let custom = config("generate:\n  template: 'type: {type}\\nsubject: {subject}'\n");
        assert_eq!(
            custom.generate.template.as_deref(),
            Some("type: {type}\\nsubject: {subject}")
        );
        let builtin = config("generate:\n  template: gitmoji\n");
        assert_eq!(builtin.generate.template.as_deref(), Some("gitmoji"));
    }

    #[test]
    fn validation_accepts_documented_boundaries_and_rejects_invalid_values() {
        let mut config = Config::default();
        config.ai.temperature = 0.0;
        config.ai.top_p = 1.0;
        config.ai.max_tokens = 1;
        config.ai.timeout = 1;
        config.generate.count = 10;
        assert!(config.validate().is_ok());

        config.ai.temperature = 2.1;
        assert!(
            matches!(config.validate(), Err(ConfigError::Validation(message)) if message.contains("temperature"))
        );
        config.ai.temperature = 0.7;
        config.ai.top_p = -0.1;
        assert!(
            matches!(config.validate(), Err(ConfigError::Validation(message)) if message.contains("top_p"))
        );
        config.ai.top_p = 1.0;
        config.generate.language = " \t ".into();
        assert!(
            matches!(config.validate(), Err(ConfigError::Validation(message)) if message.contains("language"))
        );
    }
}

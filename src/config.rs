use std::{env, fs, path::PathBuf};

use directories::UserDirs;
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
}

impl Default for GenerateConfig {
    fn default() -> Self {
        Self {
            language: "en".into(),
            count: 1,
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

        value.apply_environment();
        value.apply_cli(args);
        value.validate()?;
        Ok(LoadedConfig { value, source })
    }

    fn apply_environment(&mut self) {
        set_first(
            &mut self.ai.api_key,
            &[
                "AICOMITER_AI_API_KEY",
                "OPENAI_API_KEY",
                "ANTHROPIC_API_KEY",
                "API_KEY",
            ],
        );
        set_first_option(
            &mut self.ai.base_url,
            &["AICOMITER_AI_BASE_URL", "OPENAI_API_BASE", "API_BASE_URL"],
        );
        if let Some(value) = first_env(&["AICOMITER_AI_PROVIDER"]) {
            self.ai.provider = match value.to_ascii_lowercase().as_str() {
                "anthropic" => Provider::Anthropic,
                _ => Provider::Openai,
            };
        }
        set_first_option(&mut self.ai.model, &["AICOMITER_AI_MODEL", "MODEL"]);
        if let Some(value) = first_env(&["AICOMITER_GENERATE_LANGUAGE"]) {
            self.generate.language = value;
        }
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
        assign_copy(&mut self.generate.count, args.count);
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
        Ok(())
    }

    pub fn redacted(&self) -> RedactedConfig<'_> {
        RedactedConfig {
            ai: RedactedAiConfig {
                provider: self.ai.provider,
                api_key: "***hidden***",
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
    base_url: Option<&'a str>,
    model: Option<&'a str>,
    temperature: f64,
    top_p: f64,
    max_tokens: u32,
    timeout: u64,
}

pub fn default_path() -> Option<PathBuf> {
    UserDirs::new().map(|dirs| dirs.home_dir().join(CONFIG_FILE))
}

fn first_env(names: &[&str]) -> Option<String> {
    names
        .iter()
        .find_map(|name| env::var(name).ok().filter(|value| !value.is_empty()))
}

fn set_first(target: &mut SecretString, names: &[&str]) {
    if let Some(value) = first_env(names) {
        *target = SecretString::from(value);
    }
}

fn set_first_option(target: &mut Option<String>, names: &[&str]) {
    if let Some(value) = first_env(names) {
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
    use super::*;

    #[test]
    fn parses_nested_yaml_and_redacts_secret() {
        let config: Config = serde_yml::from_str(
            "ai:\n  provider: anthropic\n  api_key: secret\n  temperature: 0.4\ngenerate:\n  language: zh\n  count: 3\n",
        )
        .unwrap();

        assert_eq!(config.ai.provider, Provider::Anthropic);
        assert_eq!(config.generate.count, 3);
        let json = serde_json::to_string(&config.redacted()).unwrap();
        assert!(!json.contains("secret"));
        assert!(json.contains("***hidden***"));
    }

    #[test]
    fn rejects_unknown_fields() {
        assert!(serde_yml::from_str::<Config>("ai:\n  typo: value\n").is_err());
    }
}

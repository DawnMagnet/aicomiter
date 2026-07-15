use std::{fs::OpenOptions, io::Write, path::Path};

use anyhow::{Context, bail};

use crate::{
    ai::AiClient,
    cli::{Cli, Command, GenerateArgs, OutputFormat, ShowConfigArgs},
    config::{Config, ConfigSource, default_path},
    git::Git,
};

const CONFIG_TEMPLATE: &str = r#"# aicomiter configuration
ai:
  provider: openai
  # Set exactly one of api_key, api_key_env, or api_key_file.
  # When all are omitted, AICOMITER_AI_API_KEY is used.
  # api_key_env: OPENAI_API_KEY
  # api_key_file: /run/secrets/openai_api_key
  base_url: null
  model: null
  temperature: 0.7
  top_p: 1.0
  max_tokens: 500
  timeout: 30

generate:
  language: en
  count: 1
"#;

pub fn run(cli: Cli) -> anyhow::Result<()> {
    match cli.command {
        Command::Init => init(),
        Command::Generate(args) => generate(args),
        Command::ShowConfig(args) => show_config(args),
    }
}

fn init() -> anyhow::Result<()> {
    let path = default_path().context("could not determine the user's home directory")?;
    if path.exists() {
        println!("Configuration already exists at {}", path.display());
        return Ok(());
    }
    write_new_config(&path)?;
    println!("Created configuration at {}", path.display());
    Ok(())
}

fn write_new_config(path: &Path) -> anyhow::Result<()> {
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .with_context(|| format!("failed to create {}", path.display()))?;
    file.write_all(CONFIG_TEMPLATE.as_bytes())
        .with_context(|| format!("failed to write {}", path.display()))
}

fn generate(args: GenerateArgs) -> anyhow::Result<()> {
    let loaded = Config::load(&args.config)?;
    if args.show_config_sources {
        eprintln!(
            "Configuration: {} -> environment -> CLI",
            source_name(&loaded.source)
        );
    }
    if args.all {
        eprintln!("Staging all changes...");
        Git::stage_all()?;
    }

    let diff = Git::staged_diff()?;
    if diff.is_empty() {
        bail!("no staged changes found; stage files with `git add` or pass `--all`");
    }
    if !loaded.value.has_api_key() {
        bail!(
            "API key is required; configure ai.api_key, ai.api_key_env, or ai.api_key_file; set AICOMITER_AI_API_KEY; or pass --api-key"
        );
    }

    let messages = AiClient::new(&loaded.value).generate(&diff)?;
    print_messages(&messages);

    if args.commit || args.push {
        eprintln!("Creating commit...");
        Git::commit(&messages[0])?;
    }
    if args.push {
        eprintln!("Pushing changes...");
        Git::push()?;
    }
    Ok(())
}

fn show_config(args: ShowConfigArgs) -> anyhow::Result<()> {
    let loaded = Config::load(&args.config)?;
    match args.format {
        OutputFormat::Json => println!(
            "{}",
            serde_json::to_string_pretty(&loaded.value.redacted())?
        ),
        OutputFormat::Text => print!("{}", serde_yml::to_string(&loaded.value.redacted())?),
    }
    Ok(())
}

fn print_messages(messages: &[String]) {
    if messages.len() == 1 {
        println!("{}", messages[0]);
    } else {
        for (index, message) in messages.iter().enumerate() {
            println!("{}. {message}", index + 1);
        }
    }
}

fn source_name(source: &ConfigSource) -> String {
    match source {
        ConfigSource::Defaults => "defaults".into(),
        ConfigSource::File(path) => format!("defaults -> {}", path.display()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::LoadedConfig;

    #[test]
    fn formats_multiple_candidates() {
        let loaded = LoadedConfig {
            value: Config::default(),
            source: ConfigSource::Defaults,
        };
        assert_eq!(source_name(&loaded.source), "defaults");
    }
}

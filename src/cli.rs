use std::path::PathBuf;

use clap::{Args, Parser, Subcommand, ValueEnum};

#[derive(Debug, Parser)]
#[command(version, about, propagate_version = true)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Debug, Subcommand)]
pub enum Command {
    /// Create the default configuration file.
    Init,
    /// Generate commit messages from staged changes.
    #[command(alias = "gen")]
    Generate(GenerateArgs),
    /// Print the effective configuration with the API key redacted.
    ShowConfig(ShowConfigArgs),
}

#[derive(Debug, Clone, Args, Default)]
pub struct ConfigArgs {
    /// Read configuration from this YAML file.
    #[arg(long, value_name = "PATH")]
    pub config: Option<PathBuf>,
    #[arg(long, value_enum)]
    pub provider: Option<ProviderArg>,
    #[arg(long)]
    pub api_key: Option<String>,
    #[arg(long)]
    pub base_url: Option<String>,
    #[arg(long)]
    pub model: Option<String>,
    #[arg(long)]
    pub temperature: Option<f64>,
    #[arg(long)]
    pub top_p: Option<f64>,
    #[arg(long, value_parser = clap::value_parser!(u32).range(1..))]
    pub max_tokens: Option<u32>,
    #[arg(long, value_parser = clap::value_parser!(u64).range(1..))]
    pub timeout: Option<u64>,
    #[arg(short, long)]
    pub language: Option<String>,
    #[arg(short, long, value_parser = clap::value_parser!(u8).range(1..=10))]
    pub count: Option<u8>,
}

#[derive(Debug, Args)]
pub struct GenerateArgs {
    #[command(flatten)]
    pub config: ConfigArgs,
    /// Stage all tracked and untracked changes before generation.
    #[arg(short, long)]
    pub all: bool,
    /// Commit using the first generated message.
    #[arg(short = 'C', long)]
    pub commit: bool,
    /// Commit and push the current branch.
    #[arg(short, long)]
    pub push: bool,
    /// Print the configuration layers used for this invocation.
    #[arg(long, default_value_t = true, action = clap::ArgAction::Set)]
    pub show_config_sources: bool,
}

#[derive(Debug, Args)]
pub struct ShowConfigArgs {
    #[command(flatten)]
    pub config: ConfigArgs,
    #[arg(long, value_enum, default_value_t = OutputFormat::Text)]
    pub format: OutputFormat,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum ProviderArg {
    Openai,
    Anthropic,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum OutputFormat {
    Text,
    Json,
}

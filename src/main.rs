use clap::Parser;

use aicomiter::{app, cli::Cli};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    app::run(Cli::parse()).await
}

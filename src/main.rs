use clap::Parser;

use aicomiter::{app, cli::Cli};

fn main() -> anyhow::Result<()> {
    app::run(Cli::parse())
}

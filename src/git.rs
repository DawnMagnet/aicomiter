use std::process::{Command, ExitStatus};

use thiserror::Error;

const MAX_DIFF_BYTES: usize = 1024 * 1024;

#[derive(Debug, Error)]
pub enum GitError {
    #[error("Git command failed: {0}")]
    Command(#[from] std::io::Error),
    #[error("git {command} exited with {status}")]
    Failed {
        command: &'static str,
        status: ExitStatus,
    },
    #[error("the staged diff exceeds the {MAX_DIFF_BYTES} byte limit")]
    DiffTooLarge,
    #[error("Git returned non-UTF-8 diff output")]
    InvalidUtf8(#[from] std::string::FromUtf8Error),
}

pub struct Git;

impl Git {
    pub fn stage_all() -> Result<(), GitError> {
        run("add", ["add", "-A"])
    }

    pub fn staged_diff() -> Result<String, GitError> {
        let output = Command::new("git")
            .args(["diff", "--cached", "--no-ext-diff", "--binary"])
            .output()?;
        if !output.status.success() {
            return Err(GitError::Failed {
                command: "diff",
                status: output.status,
            });
        }
        if output.stdout.len() > MAX_DIFF_BYTES {
            return Err(GitError::DiffTooLarge);
        }
        Ok(String::from_utf8(output.stdout)?)
    }

    pub fn commit(message: &str) -> Result<(), GitError> {
        run("commit", ["commit", "-m", message])
    }

    pub fn push() -> Result<(), GitError> {
        run("push", ["push"])
    }
}

fn run<'a>(command: &'static str, args: impl IntoIterator<Item = &'a str>) -> Result<(), GitError> {
    let status = Command::new("git").args(args).status()?;
    if status.success() {
        Ok(())
    } else {
        Err(GitError::Failed { command, status })
    }
}

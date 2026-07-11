use duct::cmd;
use thiserror::Error;

const MAX_DIFF_BYTES: usize = 1024 * 1024;

#[derive(Debug, Error)]
pub enum GitError {
    #[error("Git command failed: {0}")]
    Command(#[from] std::io::Error),
    #[error("the staged diff exceeds the {MAX_DIFF_BYTES} byte limit")]
    DiffTooLarge,
    #[error("Git returned non-UTF-8 diff output")]
    InvalidUtf8(#[from] std::string::FromUtf8Error),
}

pub struct Git;

impl Git {
    pub fn stage_all() -> Result<(), GitError> {
        cmd!("git", "add", "-A").run()?;
        Ok(())
    }

    pub fn staged_diff() -> Result<String, GitError> {
        let output = cmd!("git", "diff", "--cached", "--no-ext-diff", "--binary")
            .stdout_capture()
            .run()?;
        if output.stdout.len() > MAX_DIFF_BYTES {
            return Err(GitError::DiffTooLarge);
        }
        Ok(String::from_utf8(output.stdout)?)
    }

    pub fn commit(message: &str) -> Result<(), GitError> {
        cmd!("git", "commit", "-m", message).run()?;
        Ok(())
    }

    pub fn push() -> Result<(), GitError> {
        cmd!("git", "push").run()?;
        Ok(())
    }
}

use std::fs;

use assert_cmd::Command;
use predicates::prelude::*;
use tempfile::tempdir;

#[test]
fn custom_config_is_loaded_and_secret_is_redacted() {
    let temp = tempdir().unwrap();
    let config = temp.path().join("config.yaml");
    fs::write(
        &config,
        "ai:\n  provider: anthropic\n  api_key: super-secret\ngenerate:\n  language: zh\n  count: 2\n",
    )
    .unwrap();

    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .args([
            "show-config",
            "--config",
            config.to_str().unwrap(),
            "--format",
            "json",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains("\"provider\": \"anthropic\""))
        .stdout(predicate::str::contains("super-secret").not())
        .stdout(predicate::str::contains("***hidden***"));
}

#[test]
fn template_can_be_selected_from_cli_and_is_shown_in_effective_config() {
    let temp = tempdir().unwrap();
    let config = temp.path().join("config.yaml");
    fs::write(&config, "generate:\n  template: simple\n").unwrap();

    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .args([
            "show-config",
            "--config",
            config.to_str().unwrap(),
            "--template",
            "conventional",
            "--format",
            "json",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains("\"template\": \"conventional\""));
}

#[test]
fn custom_template_is_accepted_from_cli() {
    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .args([
            "show-config",
            "--template",
            "{type}: {subject}",
            "--format",
            "json",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains("{type}: {subject}"));
}

#[test]
fn malformed_config_fails_with_context() {
    let temp = tempdir().unwrap();
    let config = temp.path().join("config.yaml");
    fs::write(&config, "ai:\n  temperature: nope\n").unwrap();

    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .args(["show-config", "--config", config.to_str().unwrap()])
        .assert()
        .failure()
        .stderr(predicate::str::contains("invalid configuration"));
}

#[test]
fn invalid_cli_range_is_rejected() {
    Command::cargo_bin("aicomiter")
        .unwrap()
        .args(["generate", "--count", "0"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("invalid value"));
}

#[test]
fn invalid_float_range_is_rejected_by_domain_validation() {
    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .args(["show-config", "--temperature", "2.1"])
        .assert()
        .failure()
        .stderr(predicate::str::contains(
            "ai.temperature must be between 0 and 2",
        ));
}

#[test]
fn named_environment_key_source_is_accepted_and_redacted() {
    let temp = tempdir().unwrap();
    let config = temp.path().join("config.yaml");
    fs::write(&config, "ai:\n  api_key_env: TEST_AICOMITER_API_KEY\n").unwrap();

    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .env("TEST_AICOMITER_API_KEY", "environment-secret")
        .args([
            "show-config",
            "--config",
            config.to_str().unwrap(),
            "--format",
            "json",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains("TEST_AICOMITER_API_KEY"))
        .stdout(predicate::str::contains("environment-secret").not())
        .stdout(predicate::str::contains("***hidden***"));
}

#[test]
fn file_key_source_is_accepted_trimmed_and_redacted() {
    let temp = tempdir().unwrap();
    let key_file = temp.path().join("api-key");
    let config = temp.path().join("config.yaml");
    fs::write(&key_file, " file-secret\n").unwrap();
    fs::write(
        &config,
        format!("ai:\n  api_key_file: {}\n", key_file.display()),
    )
    .unwrap();

    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .args([
            "show-config",
            "--config",
            config.to_str().unwrap(),
            "--format",
            "json",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains(key_file.to_str().unwrap()))
        .stdout(predicate::str::contains("file-secret").not())
        .stdout(predicate::str::contains("***hidden***"));
}

#[test]
fn conflicting_credential_sources_are_rejected_before_execution() {
    let temp = tempdir().unwrap();
    let config = temp.path().join("config.yaml");
    fs::write(
        &config,
        "ai:\n  api_key: plaintext-secret\n  api_key_env: TEST_AICOMITER_API_KEY\n",
    )
    .unwrap();

    Command::cargo_bin("aicomiter")
        .unwrap()
        .env_clear()
        .args(["show-config", "--config", config.to_str().unwrap()])
        .assert()
        .failure()
        .stderr(predicate::str::contains(
            "only one of ai.api_key, ai.api_key_env, and ai.api_key_file may be set",
        ));
}

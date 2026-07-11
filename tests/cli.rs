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

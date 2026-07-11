# aicomiter

`aicomiter` generates conventional Git commit messages from staged changes using OpenAI-compatible or Anthropic APIs. It is a structured Rust 1.97 CLI with strict configuration validation and no language runtime dependency.

## Features

- OpenAI and Anthropic providers
- Multiple candidates with `--count`
- YAML, environment, and CLI configuration layers
- Automatic staging, committing, and pushing
- API keys redacted from configuration output
- Bounded Git diff input and HTTP request timeouts

## Build

Rust 1.97.0 is pinned by `rust-toolchain.toml`:

```bash
cargo build --release --locked
./target/release/aicomiter --help
```

## Quick Start

```bash
cargo run -- init
# Edit ~/.aicomiter.yaml, then:
git add -A
cargo run -- generate
```

Common operations:

```bash
aicomiter gen --count 3 --language zh
aicomiter gen --all --commit
aicomiter gen --all --push
aicomiter show-config --format json
```

`--push` implies `--commit`; when multiple candidates are returned, the first is used for an automatic commit.

## Configuration

The default file is `~/.aicomiter.yaml`. Use `--config PATH` to load another file.

```yaml
ai:
  provider: openai
  api_key: sk-xxx
  base_url: null
  model: gpt-4o-mini
  temperature: 0.7
  top_p: 1.0
  max_tokens: 500
  timeout: 30

generate:
  language: en
  count: 1
```

Configuration priority, highest first:

1. CLI flags
2. Environment variables
3. YAML file
4. Built-in defaults

Environment variables:

- `AICOMITER_AI_PROVIDER`
- `AICOMITER_AI_API_KEY`
- `AICOMITER_AI_BASE_URL`
- `AICOMITER_AI_MODEL`
- `AICOMITER_GENERATE_LANGUAGE`

Compatibility aliases include `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_BASE`, `API_BASE_URL`, `API_KEY`, and `MODEL`.

## Development

```bash
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets
```

## Releases

Tagged releases are built and packaged by GoReleaser. Release assets include:

- statically linked MUSL executables for Linux x86_64 and arm64
- native executables for macOS x86_64 and Apple Silicon
- statically linked Windows executables for x86_64 and arm64
- `tar.gz` installers for Linux and macOS, and `zip` installers for Windows
- Linux `deb`, `rpm`, `apk`, and Arch Linux packages
- SHA-256 checksums for all published artifacts

To validate or create a local snapshot, install GoReleaser v2, Zig, and `cargo-zigbuild`, then run:

```bash
goreleaser check
goreleaser release --snapshot --clean
```

The implementation is split by responsibility across `app`, `cli`, `config`, `git`, and `ai` modules. Provider protocols are delegated to `genai`; process execution, serialization, secret storage, and CLI parsing are likewise delegated to maintained crates.

## License

MIT

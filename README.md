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

## Nix (Flake)

A `flake.nix` is provided for **deployment only** — it does not build
from source. Instead it fetches the pre-built binaries published to the
corresponding GitHub Release, so installation is fast and reproducible.

Supported systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.
(`x86_64-darwin` binaries are also published; use the overlay with a
nixpkgs pin ≤ 26.05 if you need that platform.)

### Try it without installing

```bash
nix run github:DawnMagnet/aicomiter -- --help
```

### Install into a NixOS system

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    aicomiter.url = "github:DawnMagnet/aicomiter";
  };

  outputs = { self, nixpkgs, aicomiter, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        aicomiter.nixosModules.default
        { programs.aicomiter.enable = true; }
      ];
    };
  };
}
```

### Install via Home-Manager

```nix
{
  imports = [ aicomiter.homeManagerModules.default ];

  programs.aicomiter = {
    enable = true;

    # Optional: declaratively manage ~/.aicomiter.yaml
    settings = {
      ai = {
        provider = "openai";
        api_key = "sk-…";
        model = "gpt-4o-mini";
        temperature = 0.4;
      };
      generate = {
        language = "zh";
        count = 1;
      };
    };
  };
}
```

Leave `settings` unset (the default) to keep `~/.aicomiter.yaml` under
manual control via `aicomiter config`.

### Use the overlay

```nix
{
  nixpkgs.overlays = [ aicomiter.overlays.default ];
  environment.systemPackages = [ pkgs.aicomiter ];
}
```

### Bumping the pinned version

The flake pins one version and its per-platform SHA-256 hashes. To
upgrade:

1. Update `version` in `flake.nix`.
2. Refresh the `sha256` fields under `sources` from the release's
   `checksums.txt`:

   ```bash
   curl -sL https://github.com/DawnMagnet/aicomiter/releases/download/vX.Y.Z/checksums.txt
   ```

3. Run `nix flake check` to verify.

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

# aicomiter

`aicomiter` generates conventional Git commit messages from staged changes using OpenAI-compatible or Anthropic APIs. It is a structured Rust 1.97 CLI with strict configuration validation and no language runtime dependency.

## Features

- OpenAI and Anthropic providers
- Multiple candidates with `--count`
- YAML, environment, and CLI configuration layers
- Automatic staging, committing, and pushing
- API keys redacted from configuration output
- Bounded Git diff input and HTTP request timeouts
- Optional built-in or custom commit-message templates

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
  # Set exactly one of these credential sources:
  # api_key: sk-xxx
  api_key_env: OPENAI_API_KEY
  # api_key_file: /run/secrets/openai_api_key
  base_url: null
  model: gpt-4o-mini
  temperature: 0.7
  top_p: 1.0
  max_tokens: 500
  timeout: 30

generate:
  language: en
  count: 1
  # Optional built-in name or custom text. See the template catalog below.
  template: conventional
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
- `AICOMITER_GENERATE_TEMPLATE`

Use exactly one of `ai.api_key` (a plaintext key), `ai.api_key_env` (the name of an environment variable), or `ai.api_key_file` (a file containing the key). If all three are omitted, aicomiter reads `AICOMITER_AI_API_KEY` by default.

`generate.template` (or `--template`) accepts a built-in name or custom text. The selected template is added to the model instruction; it does not alter the provider request schema. When unset, the original default prompt is used.

### Template Catalog

| Name | Format and intended use |
| --- | --- |
| `conventional` | Conventional Commits 1.0: `type(scope): subject`, with standard types and `BREAKING CHANGE:` footer. Aliases: `default`, `conventional-commits`. |
| `angular` | Angular-style `type(scope): subject` with Angular's common type vocabulary. |
| `semantic-release` | Conventional Commits tuned for semantic-release version bumps. Alias: `semantic`. |
| `gitmoji` | One Gitmoji followed by a Conventional Commit-style subject. |
| `emoji` | One relevant emoji followed by a short imperative subject, without a type prefix. |
| `simple` | Exactly one short imperative sentence. |
| `imperative` | Present-tense imperative subject such as `Add`, `Fix`, or `Update`. |
| `descriptive` | Clear subject plus an optional explanatory body, without a required prefix. |
| `github` | GitHub-friendly imperative subject and optional wrapped body. Alias: `github-pr`. |
| `jira` | Optional issue key followed by `type(scope): subject`; never invents an issue key. Aliases: `ticket`, `jira-smart-commit`. |
| `linux` | Linux kernel style: lowercase subsystem prefix, imperative subject, optional problem/solution body. Alias: `kernel`. |
| `keep-a-changelog` | Changelog categories such as `Added`, `Changed`, `Fixed`, or `Security`. Alias: `changelog`. |
| `release` | Release preparation messages such as `chore(release): prepare v1.2.3`. Aliases: `release-note`, `release-notes`. |

### Template Examples

The following examples show one possible style for a generated message. They are illustrative, not fixed output contracts; the exact wording and structure depend on the staged diff.

| Template | Example message |
| --- | --- |
| `conventional` | `feat(auth): add token refresh support`<br><br>`BREAKING CHANGE: refresh tokens now require rotation` |
| `angular` | `fix(router): preserve query parameters on redirect` |
| `semantic-release` | `feat(api): expose repository health endpoint` |
| `gitmoji` | `✨ feat: add export support` |
| `emoji` | `🔒 rotate expired session tokens` |
| `simple` | `Add repository health checks` |
| `imperative` | `Update the deployment timeout` |
| `descriptive` | `Improve cache invalidation`<br><br>`Avoid serving stale user permissions after role changes.` |
| `github` | `fix: handle empty pull request descriptions`<br><br>`Return a validation error before creating the pull request.` |
| `jira` | `ACME-421: fix(auth): reject expired refresh tokens` |
| `linux` | `net: handle malformed packet headers`<br><br>`Validate the header length before reading optional fields.` |
| `keep-a-changelog` | `Added: support exporting audit events as JSON` |
| `release` | `chore(release): prepare v1.4.0` |

Examples:

```bash
aicomiter gen --template semantic-release
aicomiter gen --template linux
aicomiter gen --template jira
```

Custom templates are sent as instructions and may use `{type}`, `{scope}`, `{subject}`, `{body}`, and `{breaking}` placeholders:

```yaml
generate:
  template: "{type}({scope}): {subject}\n\n{body}\n\nBREAKING CHANGE: {breaking}"
```

Built-in templates use strong format instructions and should be treated as the selected convention. They still guide the model rather than acting as a local parser or output validator. User-defined templates are intentionally softer: the model may fill, adapt, reorder, or omit placeholders when that produces a better message for the staged diff. Empty or whitespace-only templates are rejected, and templates are limited to 4,000 characters.

Compatibility aliases include `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_BASE`, `API_BASE_URL`, `API_KEY`, and `MODEL`. The API-key aliases are only used when no credential source is configured.

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

The release workflow automatically updates the pinned version's
per-platform SHA-256 hashes after GoReleaser publishes the assets. To
prepare a release:

1. Update the package version in `Cargo.toml` and `Cargo.lock`.
2. Update `version` in `flake.nix` to the same value.
3. Push the version commit and a matching tag, for example
   `git push origin main v0.2.3`.
4. The `update-flake-hashes` job downloads the release's `checksums.txt`,
   updates the four flake hashes, validates the flake, and commits the
   change to `main`.

The hash update job only runs for published tag releases, not for
ordinary pushes to `main`. To recover an already-published release after a
workflow failure, run the standalone `Update Flake Hashes` workflow and set
`release_tag` to the existing tag, for example `v0.2.3`. This avoids rebuilding
the release.

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

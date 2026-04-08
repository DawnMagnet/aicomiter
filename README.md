# aicomiter

A CLI tool that generates Git commit messages from staged changes using AI providers.

Single binary, no third-party runtime library dependencies, and under 500KB in the Nix release build.

## Features

- Generate commit messages from `git diff --cached`
- Support multiple providers: OpenAI and Anthropic
- Support configurable model parameters
- Support multiple output candidates (`--count`)
- Support language selection (`--language`)
- Support config from file, environment variables, and CLI flags
- Optional automation: stage all (`--all`), commit (`--commit`), push (`--push`)
- No third-party runtime library dependencies (single Zig binary)
- Small release binary size: Nix output is typically <500KB

## Requirements

- Zig 0.15.2+
- Git
- API key for OpenAI or Anthropic

## Build

```bash
zig build -Doptimize=ReleaseSafe
```

Binary path:

```bash
./zig-out/bin/aicomiter
```

## Quick Start

1. Initialize config:

```bash
./zig-out/bin/aicomiter init
```

2. Edit `~/.aicomiter.yaml` and set your API key.

3. Stage changes and generate message:

```bash
git add -A
./zig-out/bin/aicomiter generate
```

## Commands

```bash
aicomiter init
aicomiter generate | aicomiter gen
aicomiter show-config
aicomiter help
```

## Common Usage

Generate one message:

```bash
./zig-out/bin/aicomiter gen
```

Generate multiple suggestions:

```bash
./zig-out/bin/aicomiter gen --count 3
```

Generate Chinese message:

```bash
./zig-out/bin/aicomiter gen --language zh
```

Stage all changes before generation:

```bash
./zig-out/bin/aicomiter gen --all
```

Auto-commit and push:

```bash
./zig-out/bin/aicomiter gen --all --commit --push
```

## Configuration

Default config file: `~/.aicomiter.yaml`

```yaml
ai:
  provider: openai
  api_key: sk-xxx
  base_url: https://api.openai.com/v1
  model: gpt-4o-mini
  temperature: 0.7
  top_p: 1.0
  max_tokens: 500
  timeout: 30

generate:
  language: en
  count: 1
```

## Environment Variables

- `AICOMITER_AI_PROVIDER`
- `AICOMITER_AI_API_KEY`
- `AICOMITER_AI_BASE_URL`
- `AICOMITER_AI_MODEL`
- `AICOMITER_GENERATE_LANGUAGE`

Compatibility variables:

- `API_KEY`
- `MODEL`

## Config Priority

From highest to lowest:

1. CLI flags
2. Environment variables
3. Config file
4. Defaults

## Nix

Build with Nix:

```bash
nix build
./result/bin/aicomiter --help
```

Current measured size:

- `./result/bin/aicomiter`: 267KB

## Project Structure

- `src/main.zig`: command dispatch and flow
- `src/cli.zig`: CLI parsing
- `src/config.zig`: config loading and overrides
- `src/git.zig`: git command wrapper
- `src/ai.zig`: provider requests and response parsing
- `src/util.zig`: utility helpers

## License

MIT

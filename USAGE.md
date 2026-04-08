# aicomiter Usage

This guide focuses on day-to-day usage.

## Build

```bash
zig build -Doptimize=ReleaseSafe
```

Use the built binary:

```bash
./zig-out/bin/aicomiter
```

## Initialize Configuration

```bash
./zig-out/bin/aicomiter init
```

Then edit `~/.aicomiter.yaml` and set `ai.api_key`.

## Basic Flow

```bash
git add -A
./zig-out/bin/aicomiter generate
```

Copy the output and commit manually, or use `--commit`.

## Common Commands

Generate one message:

```bash
./zig-out/bin/aicomiter gen
```

Generate three suggestions:

```bash
./zig-out/bin/aicomiter gen -c 3
```

Use Chinese output:

```bash
./zig-out/bin/aicomiter gen -l zh
```

Stage all changes before generating:

```bash
./zig-out/bin/aicomiter gen --all
```

Generate and auto-commit:

```bash
./zig-out/bin/aicomiter gen --all --commit
```

Generate, auto-commit, and push:

```bash
./zig-out/bin/aicomiter gen --all --commit --push
```

## Override by CLI Flags

```bash
./zig-out/bin/aicomiter gen \
  --provider openai \
  --api-key sk-xxx \
  --model gpt-4o-mini \
  --temperature 0.7 \
  --top-p 1.0 \
  --max-tokens 500 \
  --timeout 30 \
  --language en \
  --count 1
```

## show-config

Show current config:

```bash
./zig-out/bin/aicomiter show-config
```

Show JSON output:

```bash
./zig-out/bin/aicomiter show-config --format json
```

## Troubleshooting

Missing API key:

- Ensure `ai.api_key` is set in `~/.aicomiter.yaml`
- Or pass `--api-key`
- Or set `AICOMITER_AI_API_KEY`

No staged changes:

```bash
git add -A
./zig-out/bin/aicomiter gen
```

Network/API errors:

- Check internet connectivity
- Check provider endpoint and API key
- Increase timeout with `--timeout`

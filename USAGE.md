# aicomiter Usage

## Initialize

```bash
aicomiter init
```

This creates `~/.aicomiter.yaml` without overwriting an existing file. Add the selected provider's API key before generating a message.

## Generate

```bash
git add -A
aicomiter generate
```

Useful variants:

```bash
aicomiter gen -c 3
aicomiter gen -l zh
aicomiter gen --all
aicomiter gen --all --commit
aicomiter gen --all --push
```

Pass provider settings for one invocation:

```bash
aicomiter gen \
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

## Inspect Configuration

```bash
aicomiter show-config
aicomiter show-config --format json
aicomiter show-config --config ./experiment.yaml
```

The API key is always redacted. Unknown YAML fields and out-of-range numeric values fail before an API request is made.

## Troubleshooting

- No staged changes: run `git add -A` or pass `--all`.
- Missing API key: set it in YAML, `AICOMITER_AI_API_KEY`, or `--api-key`.
- Provider errors: verify `base_url`, credentials, model access, and increase `--timeout` when appropriate.
- Oversized diff: split the staged changes into smaller commits; input is limited to 1 MiB.

# aicomiter Usage

## Initialize

```bash
aicomiter init
```

This creates `~/.aicomiter.yaml` without overwriting an existing file. Configure one API-key source before generating a message: `ai.api_key`, `ai.api_key_env`, or `ai.api_key_file`. If none is configured, `AICOMITER_AI_API_KEY` is used.

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
- Missing API key: configure one of `ai.api_key`, `ai.api_key_env`, or `ai.api_key_file`; set `AICOMITER_AI_API_KEY`; or pass `--api-key`.
- Provider errors: verify `base_url`, credentials, model access, and increase `--timeout` when appropriate.
- Oversized diff: split the staged changes into smaller commits; input is limited to 1 MiB.

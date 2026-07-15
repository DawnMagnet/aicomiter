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
# Use a built-in template or custom template text
aicomiter gen --template conventional
aicomiter gen --template "{type}({scope}): {subject}"
aicomiter gen --template semantic-release
aicomiter gen --template jira
aicomiter gen --template linux
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

## Message Templates

`generate.template` is optional. It can be set in YAML, with `AICOMITER_GENERATE_TEMPLATE`, or with `--template`; the precedence is CLI, environment, YAML, then the disabled default.

Available built-ins:

| Template | Use it for |
| --- | --- |
| `conventional` | Standard Conventional Commits; aliases `default`, `conventional-commits` |
| `angular` | Angular commit convention |
| `semantic-release` | Commits that drive semantic versioning; alias `semantic` |
| `gitmoji` / `emoji` | Emoji-led commit subjects |
| `simple` / `imperative` | Short subject-only messages |
| `descriptive` | Subject plus an optional explanatory body |
| `github` | GitHub-oriented subject and body; alias `github-pr` |
| `jira` | Issue-key-aware messages; aliases `ticket`, `jira-smart-commit` |
| `linux` | Linux kernel style; alias `kernel` |
| `keep-a-changelog` | Changelog categories; alias `changelog` |
| `release` | Release preparation commits; aliases `release-note`, `release-notes` |

For project-specific preferences, use a custom template. Placeholders are `{type}`, `{scope}`, `{subject}`, `{body}`, and `{breaking}`. Built-ins give the model strong convention-specific instructions; custom templates are softer guidance, so the model may adapt or omit parts when the diff calls for it. Review the final message before `--commit` or `--push`.

## Troubleshooting

- No staged changes: run `git add -A` or pass `--all`.
- Missing API key: configure one of `ai.api_key`, `ai.api_key_env`, or `ai.api_key_file`; set `AICOMITER_AI_API_KEY`; or pass `--api-key`.
- Provider errors: verify `base_url`, credentials, model access, and increase `--timeout` when appropriate.
- Oversized diff: split the staged changes into smaller commits; input is limited to 1 MiB.

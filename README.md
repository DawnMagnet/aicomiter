# aicomiter

一个基于 Go 语言的 CLI 工具，使用 AI（OpenAI/Anthropic）生成有意义的 Git commit messages。

## ✨ 功能

- 🤖 支持多个 AI 提供商（OpenAI、Anthropic）
- ⚙️ 高度可配置的参数（temperature、top_p、max_tokens 等）
- 🌍 多语言支持（英文、中文等）
- 💬 生成多个建议供选择
- 🔧 灵活的配置方式（配置文件、环境变量、命令行参数）
- 📝 遵循 Conventional Commits 格式
- 🚀 轻量级，零依赖额外的 AI SDK

## 📦 安装

### 从源码构建

```bash
git clone https://github.com/yourusername/aicomiter.git
cd aicomiter
go build -o aicomiter main.go
```

## 🚀 快速开始

### 1. 初始化配置

```bash
./aicomiter init
```

这将在 `~/.aicomiter.yaml` 创建一个配置文件模板。

### 2. 编辑配置文件

```bash
nano ~/.aicomiter.yaml
```

添加你的 API 密钥和其他设置。

### 3. 生成 commit message

```bash
# 暂存你的文件
git add src/main.go

# 生成 commit message
./aicomiter generate
```

## 📖 使用方式

### 基本用法

```bash
# 使用默认配置生成单个 commit message
./aicomiter generate
# 简写: ./aicomiter gen

# 生成 3 个建议
./aicomiter gen --count 3

# 用中文生成
./aicomiter gen --language zh

# 生成多个中文建议
./aicomiter gen -l zh -c 5

# Stage 所有变动并生成 commit message
./aicomiter gen --all

# 生成 commit message 后自动 push
./aicomiter gen --push

# 综合使用：Stage 所有变动、生成消息、自动 push
./aicomiter gen -a -p -l zh -c 1
```

### Git 操作快捷方式

```bash
# Stage 所有未暂存的变动
./aicomiter generate --all
# 等同于: git add -A && ./aicomiter generate

# 生成后自动 push
./aicomiter generate --push
# 生成消息后会自动执行: git push

# 组合使用
./aicomiter generate --all --push
# 等同于: git add -A && ./aicomiter generate && git push
```

### 配置管理

```bash
# 初始化配置文件
./aicomiter init

# 显示当前配置
./aicomiter show-config

# 显示 JSON 格式的配置
./aicomiter show-config --format json

# 隐藏配置来源信息
./aicomiter generate --show-config-sources=false
```

### 命令行参数

所有配置项都可以通过命令行参数覆盖：

```bash
./aicomiter generate \
  --api-key sk-xxx \
  --provider openai \
  --model gpt-4o-mini \
  --temperature 0.8 \
  --top-p 0.95 \
  --max-tokens 500 \
  --timeout 60 \
  --language en \
  --count 1
```

## ⚙️ 配置

### 配置文件 (~/.aicomiter.yaml)

```yaml
# AI 提供商配置
ai:
  provider: openai                           # openai 或 anthropic
  api_key: sk-your-api-key-here             # API 密钥
  base_url: https://api.openai.com/v1       # 自定义 API 端点（可选）
  model: gpt-4o-mini                        # 模型名称（可选，使用默认值）
  temperature: 0.7                          # 0-2，越低越确定
  top_p: 1.0                                # 0-1，核抽样
  max_tokens: 500                           # 最大响应长度
  timeout: 30                               # 请求超时（秒）

# 生成配置
generate:
  language: en                              # 语言：en, zh 等
  count: 1                                  # 生成建议数量
```

### 环境变量

所有配置项都可以通过环境变量设置：

```bash
# AI 配置
export AICOMITER_AI_PROVIDER=openai
export AICOMITER_AI_API_KEY=sk-xxx
export AICOMITER_AI_BASE_URL=https://api.openai.com/v1
export AICOMITER_AI_MODEL=gpt-4o-mini
export AICOMITER_AI_TEMPERATURE=0.7
export AICOMITER_AI_TOP_P=1.0
export AICOMITER_AI_MAX_TOKENS=500
export AICOMITER_AI_TIMEOUT=30

# 生成配置
export AICOMITER_GENERATE_LANGUAGE=en
export AICOMITER_GENERATE_COUNT=1

# 向后兼容的环境变量
export API_KEY=sk-xxx
export PROVIDER=openai
export MODEL=gpt-4o-mini
```

### 命令行参数

```bash
./aicomiter generate --help

Flags (generate command):
  -a, --all                Stage all unstaged changes before generating
  -p, --push               Automatically push changes after generating

Global Flags:
  --api-key string         API key for the AI provider
  --provider string        AI provider: openai or anthropic
  --model string           Model name
  --base-url string        Base URL for the API endpoint
  --temperature float      Temperature (0-2, controls randomness)
  --top-p float           Top-P (0-1, nucleus sampling)
  --max-tokens int        Maximum tokens in response
  --timeout int           Request timeout in seconds
  -l, --language string   Language for commit message (en, zh, etc.)
  -c, --count int         Number of suggestions
  --config string         Path to config file
  --show-config-sources   Show configuration source information (default: true)
```

### 配置优先级

配置加载优先级（从高到低）：

1. **命令行参数** (最高优先级)

   ```bash
   ./aicomiter generate --api-key sk-xxx --temperature 0.8
   ```

1. **环境变量**

   ```bash
   export AICOMITER_AI_API_KEY=sk-xxx
   export AICOMITER_AI_TEMPERATURE=0.8
   ./aicomiter generate
   ```

1. **配置文件** (~/.aicomiter.yaml)

   ```yaml
   ai:
     api_key: sk-xxx
     temperature: 0.8
   ```

1. **默认值** (最低优先级)

- Provider: openai
- Temperature: 0.7
- Top-P: 1.0
- Max tokens: 500
- Timeout: 30
- Language: en
- Count: 1

#### 示例：优先级覆盖

```bash
# 配置文件中设置 temperature: 0.7
# 环境变量中设置 AICOMITER_AI_TEMPERATURE=0.8
# 命令行参数中设置 --temperature 0.9
# 最终使用的值是 0.9 (命令行参数最高优先级)
./aicomiter generate --temperature 0.9
```

## 🤖 AI 提供商

### OpenAI

```yaml
ai:
  provider: openai
  api_key: sk-proj-xxx
  model: gpt-4o-mini              # 最新的小型模型，成本低
  # 或
  # model: gpt-4-turbo            # 更强大的模型
  temperature: 0.7
```

**获取 API 密钥**: https://platform.openai.com/api-keys

### Anthropic

```yaml
ai:
  provider: anthropic
  api_key: sk-ant-xxx
  model: claude-3-5-sonnet-20241022  # 最新的 Claude 模型
  temperature: 1.0
```

**获取 API 密钥**: https://console.anthropic.com

## 📝 使用示例

### 完整工作流

#### 基础工作流

```bash
# 1. 修改代码
vim src/main.go

# 2. 暂存文件
git add src/main.go

# 3. 生成 commit message（自动显示配置来源）
./aicomiter generate

# 4. 提交
git commit -m "$(./aicomiter generate)"
```

#### 快速工作流（使用 --all 和 --push）

```bash
# 1. 修改代码
vim src/main.go src/utils.go

# 2. 一键完成：Stage + 生成消息 + 自动 Push
./aicomiter generate --all --push

# 等同于：
# git add -A
# ./aicomiter generate（显示配置来源）
# git commit -m "..."
# git push
```

#### 多语言工作流

```bash
# 生成中文 commit message，并自动 push
./aicomiter generate --all -l zh -p

# 生成 5 个中文建议，Stage 所有变动但不 push
./aicomiter generate --all -l zh -c 5
```

### 生成多个建议

```bash
# 生成 5 个英文建议
./aicomiter generate -l en -c 5

# 生成 3 个中文建议
./aicomiter generate -l zh -c 3
```

### 自定义模型参数

```bash
# 使用更高的 temperature 获得更多创意的消息
./aicomiter generate --temperature 1.5

# 使用更低的 temperature 获得更确定的消息
./aicomiter generate --temperature 0.2

# 调整 max_tokens 处理更大的变更
./aicomiter generate --max-tokens 1000

# 设置更长的超时时间
./aicomiter generate --timeout 60
```

### 与其他工具集成

```bash
# 复制到剪贴板（macOS）
./aicomiter generate | pbcopy

# 复制到剪贴板（Linux）
./aicomiter generate | xclip -selection clipboard

# 保存到文件
./aicomiter generate > commit_msg.txt

# 直接提交
git commit -m "$(./aicomiter generate)"
```

## 🏗️ 项目结构

```
.
├── main.go                    # 入口点
├── cmd/
│   ├── root.go               # 根命令
│   ├── generate.go           # generate 命令
│   ├── init.go               # init 命令
│   └── show_config.go        # show-config 命令
├── internal/
│   ├── ai/
│   │   ├── client.go         # AI 客户端接口
│   │   ├── openai.go         # OpenAI 实现
│   │   ├── anthropic.go      # Anthropic 实现
│   │   └── prompt.go         # Prompt 构建
│   ├── config/
│   │   └── config.go         # 配置管理
│   └── git/
│       └── git.go            # Git 操作
├── go.mod                    # Go 模块定义
└── README.md                 # 本文件
```

## ⚡ 性能和成本

### 成本估算

- **OpenAI (gpt-4o-mini)**: ~$0.01-0.05 每个请求
- **Anthropic (Claude 3.5)**: ~$0.01-0.03 每个请求

### 优化建议

1. 使用 `gpt-4o-mini` 或更小的模型以降低成本
2. 合理设置 `max_tokens`（通常 500 足够）
3. 为大型变更集使用更高的 `max_tokens`

## 🐛 故障排除

### API 密钥错误

```
Error: API key is required
```

**解决方案:**
1. 检查 API 密钥是否正确设置
2. 尝试通过 `--api-key` 参数直接指定
3. 检查 `~/.aicomiter.yaml` 配置

### 没有暂存的变更

```
No staged changes found.
```

**解决方案:**
```bash
git add <files>
./aicomiter generate
```

### 网络错误

```
Error: failed to send request
```

**解决方案:**
1. 检查网络连接
2. 如果在中国，配置代理或使用兼容的 API 端点
3. 增加 `--timeout` 值

### 模型不存在

```
Error: openai API error: The model gpt-5 does not exist
```

**解决方案:**
使用支持的模型名称，如 `gpt-4o-mini`, `gpt-4-turbo`, `claude-3-5-sonnet-20241022`

## 📚 Commit 消息格式

生成的消息遵循 Conventional Commits 格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**常见类型:**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码风格变更（不影响功能）
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建、依赖等维护性工作

**示例:**
```
feat(auth): add JWT token refresh mechanism

- Implement refresh token endpoint
- Update token expiration handling
- Add tests for token refresh flow

Closes #123
```

## 📄 许可证

MIT

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 获取帮助

```bash
./aicomiter --help
./aicomiter generate --help
./aicomiter init --help
./aicomiter show-config --help
```

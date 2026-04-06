# aicomiter 使用指南

## 快速开始

### 1. 构建

```bash
go build -o aicomiter main.go
```

### 2. 配置 API Key

有三种方式设置 API Key：

#### 方式一：环境变量（推荐）

```bash
export API_KEY=sk-xxx
./aicomiter generate
```

#### 方式二：配置文件

创建 `~/.aicomiter.yaml`：

```yaml
api-key: sk-xxx
provider: openai
model: gpt-4o-mini
```

然后运行：
```bash
./aicomiter generate
```

#### 方式三：命令行参数

```bash
./aicomiter generate --api-key sk-xxx
```

## 基本用法

### 生成单个提交信息

```bash
# 使用 OpenAI（默认）
./aicomiter generate --api-key sk-xxx

# 使用 Anthropic
./aicomiter generate --provider anthropic --api-key sk-ant-xxx
```

### 生成多个建议

```bash
./aicomiter generate --count 3
```

输出示例：
```
feat: add dark mode support

refactor: improve error handling in auth module

docs: update API documentation for new endpoints
```

### 用中文生成

```bash
./aicomiter generate --language zh
```

## 完整选项

```bash
./aicomiter generate --help
```

**主要参数：**

- `--api-key` - API 密钥（必需，可用环境变量 `API_KEY` 替代）
- `--provider` - AI 提供商：`openai` 或 `anthropic`（默认：openai）
- `--model` - 模型名称（默认取决于提供商）
  - OpenAI: `gpt-4o-mini`
  - Anthropic: `claude-3-5-sonnet-20241022`
- `--language` / `-l` - 语言（默认：en，支持 zh/en）
- `--count` / `-c` - 建议数量（默认：1）
- `--config` - 配置文件路径

## 工作流示例

### 1. 修改代码并暂存

```bash
git add src/main.go src/utils.go
```

### 2. 生成提交信息

```bash
./aicomiter generate
```

### 3. 使用生成的信息提交

```bash
git commit -m "生成的提交信息"
```

### 完整一行命令

```bash
# 生成并复制到剪贴板（macOS）
./aicomiter generate | pbcopy

# Linux
./aicomiter generate | xclip -selection clipboard

# Windows
./aicomiter generate | clip
```

## 提供商对比

### OpenAI

优点：
- 更便宜的 API 成本
- 支持多个模型版本
- 更快的响应速度

使用：
```bash
./aicomiter generate --provider openai --api-key sk-xxx
```

### Anthropic

优点：
- 更长的上下文窗口
- 更好的推理能力
- 更安全的内容过滤

使用：
```bash
./aicomiter generate --provider anthropic --api-key sk-ant-xxx
```

## 高级用法

### 自定义模型

```bash
# 使用更强大的模型（成本更高）
./aicomiter generate --model gpt-4-turbo

# 使用更经济的模型
./aicomiter generate --model gpt-3.5-turbo
```

### 多语言支持

```bash
# 中文
./aicomiter generate -l zh

# 英文（默认）
./aicomiter generate -l en

# 其他语言
./aicomiter generate -l ja  # 日文
./aicomiter generate -l ko  # 韩文
./aicomiter generate -l fr  # 法文
```

### 生成多个建议供选择

```bash
./aicomiter generate --count 5
```

## 常见问题

### Q: 提交信息格式是什么？

A: 遵循 Conventional Commits 格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

常见类型：
- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档
- `style`: 代码风格（不改变功能）
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试
- `chore`: 构建、依赖等

示例：
```
feat(auth): add JWT token refresh mechanism
```

### Q: API 密钥安全吗？

A: 
- 不要将 API 密钥提交到 git
- 使用环境变量或配置文件（添加到 .gitignore）
- 定期轮换 API 密钥

### Q: 如何处理大的代码变更？

A: 工具自动处理，但建议：
- 将大的变更分解成多个提交
- 每次提交只修改相关的文件

### Q: 支持 IDE 集成吗？

A: 可以创建脚本和快捷键：

**VS Code 集成示例：**
```json
{
  "key": "ctrl+shift+m",
  "command": "workbench.action.terminal.sendSequence",
  "args": { "text": "./aicomiter generate\n" }
}
```

### Q: 成本大约是多少？

A: 
- OpenAI (gpt-4o-mini): ~$0.01-0.05 每个请求
- Anthropic (Claude 3.5): ~$0.01-0.03 每个请求

## 故障排除

### 错误：API key 无效

```
Error: openai API error: Invalid API key
```

解决：
1. 检查 API 密钥是否正确
2. 确保 API 密钥有效且有足够额度
3. 检查是否正确设置了环境变量

### 错误：网络连接问题

```
Error: failed to send request: connection refused
```

解决：
1. 检查网络连接
2. 检查是否能访问 api.openai.com 或 api.anthropic.com
3. 如果在中国，可能需要配置代理

### 错误：没有暂存的变更

```
No staged changes found.
```

解决：
```bash
git add <files>  # 暂存文件
./aicomiter generate
```

## 环境变量

- `API_KEY` - API 密钥
- `PROVIDER` - AI 提供商（openai/anthropic）
- `MODEL` - 模型名称

## 配置文件位置

- `$HOME/.aicomiter.yaml` - 默认位置
- 或通过 `--config` 指定自定义位置

## 许可证

MIT

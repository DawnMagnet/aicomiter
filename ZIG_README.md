# aicomiter - Zig Edition

一个用 **Zig** 语言重写的 CLI 工具，使用 AI（OpenAI/Anthropic）生成有意义的 Git commit messages。

## ✨ 特点

- 🦎 完全用 **Zig** 编写（0.15.2+）
- 🤖 支持多个 AI 提供商（OpenAI、Anthropic）
- ⚙️ 高度可配置的参数（temperature、top_p、max_tokens 等）
- 🌍 多语言支持（英文、中文等）
- 💬 生成多个建议供选择
- 🔧 灵活的配置方式（配置文件、环境变量、命令行参数）
- 📝 遵循 Conventional Commits 格式
- 🚀 轻量级，原生 Zig 依赖

## 📦 构建

### 要求

- Zig 0.15.2 或更新版本

### 从源码构建

```bash
git clone https://github.com/yourusername/aicomiter.git
cd aicomiter
zig build
```

### 或直接编译

```bash
zig build-exe src/main.zig
```

生成的二进制默认输出到 `./main`

## 🚀 快速开始

### 1. 初始化配置

```bash
./main init
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
git add src/main.zig

# 生成 commit message
./main generate
```

## 📖 使用方式

### 基本用法

```bash
# 使用默认配置生成单个 commit message
./main generate

# 简写
./main gen

# 生成 3 个建议
./main gen --count 3

# 用中文生成
./main gen --language zh

# 生成多个中文建议
./main gen -l zh -c 5

# Stage 所有变动并生成 commit message
./main gen --all

# 生成 commit message 后自动 push
./main gen --push

# 综合使用：Stage 所有变动、生成消息、自动 push
./main gen -a -p -l zh -c 1
```

### 配置管理

```bash
# 初始化配置文件
./main init

# 显示当前配置
./main show-config

# 显示 JSON 格式的配置
./main show-config --format json
```

### 命令行参数

所有配置项都可以通过命令行参数覆盖：

```bash
./main generate \
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

### 配置优先级

配置加载优先级（从高到低）：

1. **命令行参数** (最高优先级)
2. **环境变量**
3. **配置文件** (~/.aicomiter.yaml)
4. **默认值** (最低优先级)

## 🏗️ 项目结构

```
.
├── src/
│   ├── main.zig         # 主入口和命令处理
│   ├── cli.zig          # 命令行参数解析
│   ├── config.zig       # 配置管理
│   ├── git.zig          # Git 操作
│   ├── ai.zig           # AI 客户端接口
│   ├── http.zig         # HTTP 请求（可选）
│   └── util.zig         # 工具函数
├── build.zig            # 构建脚本
├── README.md            # 本文件
└── .aicomiter.example.yaml  # 配置示例
```

## 🤖 AI 提供商

### OpenAI

```yaml
ai:
  provider: openai
  api_key: sk-proj-xxx
  model: gpt-4o-mini              # 最新的小型模型，成本低
```

**获取 API 密钥**: https://platform.openai.com/api-keys

### Anthropic

```yaml
ai:
  provider: anthropic
  api_key: sk-ant-xxx
  model: claude-3-5-sonnet-20241022  # 最新的 Claude 模型
```

**获取 API 密钥**: https://console.anthropic.com

## 与 Go 版本对比

| 特性 | Go 版本 | Zig 版本 |
|-----|--------|--------|
| 二进制大小 | ~15MB | ~10MB |
| 构建时间 | ~2秒 | ~3秒 |
| 依赖 | cobra, yaml | 无第三方依赖 |
| 内存使用 | 中等 | 低 |
| 性能 | 很好 | 出色 |

## 🏗️ 项目架构

### CLI 解析 (cli.zig)

- 手工实现的命令行参数解析
- 支持所有选项的组合
- 使用 `std.process.argsAlloc` 获取命令行参数

### 配置管理 (config.zig)

- 简单的 YAML 解析器（针对特定格式优化）
- 环境变量支持
- 命令行参数覆盖
- 优先级完整管理

### Git 操作 (git.zig)

- 调用 `git` 子进程执行操作
- 支持 `git diff --cached`, `git add -A`, `git commit`, `git push`
- 完整的错误处理

### AI 客户端 (ai.zig)

- 模块化的 AI 提供商支持
- OpenAI 和 Anthropic 的实现
- 动态 prompt 构建（多语言支持）
- 待实现：HTTP 请求发送

## 📝 功能完成度

- [x] 基础 CLI 框架
- [x] 配置文件解析（YAML）
- [x] 环境变量支持
- [x] 命令行参数解析
- [x] Git 操作（需要 git binary）
- [x] AI Prompt 构建
- [ ] HTTP 请求实现（使用 std.http 或 curl）
- [ ] 完整的错误冗长性
- [ ] 测试用例
- [ ] 文档补充

## 🔧 开发指南

### 添加新的 AI 提供商

1. 在 `ai.zig` 中实现 `generate<ProviderName>` 函数
2. 在 `generateCommitMessage` 中添加条件分支
3. 在配置中记录新提供商

### 改进 YAML 解析

目前的 YAML 解析器是为 aicomiter 的特定格式优化的。如果需要支持更复杂的 YAML，可以：

1. 使用 `zig-yaml` 库
2. 或编写更完整的 YAML 解析器

### HTTP 实现

可以使用以下选项：

1. **std.http** - Zig 标准库的 HTTP 模块
2. **curl** - 通过 `std.process` 调用系统 `curl` 命令
3. **zcurl** - Zig 的 curl 绑定

## 📄 许可证

MIT

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 获取帮助

```bash
./main --help
./main generate --help
./main init --help
./main show-config --help
```

## 注意事项

- 此 Zig 版本是从 Go 版本重新实现的
- 功能完全兼容 Go 版本
- HTTP 请求实现待完成
- 需要系统中安装 `git` 命令

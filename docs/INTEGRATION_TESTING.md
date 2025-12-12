# AI Enhancement Integration Testing Guide

本文档介绍如何运行 HoAh 的 AI Enhancement 集成测试。

## 概述

集成测试验证 HoAh 的 AI Enhancement 功能是否正确工作，包括：
- 各 AI 提供商的 API 连接
- 请求构建和响应解析
- 错误处理
- 认证方式（API Key、AWS Profile、AWS Access Key）

## 快速开始

### 1. 配置 API Keys

复制示例配置文件：
```bash
cp .env.test.example .env.test
```

编辑 `.env.test` 填入你的 API Keys：
```bash
# OpenAI
OPENAI_API_KEY=sk-xxx

# Gemini
GEMINI_API_KEY=AIzaSyxxx

# Groq
GROQ_API_KEY=gsk_xxx

# Cerebras
CEREBRAS_API_KEY=csk-xxx

# AWS Bedrock (Bearer Token)
AWS_BEDROCK_API_KEY=ABSKxxx
AWS_BEDROCK_REGION=us-east-1

# AWS Profile (可选，用于 SigV4 认证)
AWS_PROFILE=default
```

### 2. 运行测试

运行所有测试：
```bash
xcodebuild test -scheme HoAh -destination 'platform=macOS' -only-testing:HoAhTests
```

运行特定提供商测试：
```bash
# OpenAI
xcodebuild test -scheme HoAh -destination 'platform=macOS' -only-testing:HoAhTests/OpenAIIntegrationTests

# Gemini
xcodebuild test -scheme HoAh -destination 'platform=macOS' -only-testing:HoAhTests/GeminiIntegrationTests

# Groq
xcodebuild test -scheme HoAh -destination 'platform=macOS' -only-testing:HoAhTests/GroqIntegrationTests

# Cerebras
xcodebuild test -scheme HoAh -destination 'platform=macOS' -only-testing:HoAhTests/CerebrasIntegrationTests

# AWS Bedrock (Bearer Token)
xcodebuild test -scheme HoAh -destination 'platform=macOS' -only-testing:HoAhTests/BedrockIntegrationTests

# AWS Bedrock (Profile/SigV4)
xcodebuild test -scheme HoAh -destination 'platform=macOS' -only-testing:HoAhTests/BedrockProfileIntegrationTests
```

## 测试覆盖

### 支持的提供商和模型

| Provider | Models | 认证方式 |
|----------|--------|----------|
| OpenAI | gpt-5.1, gpt-5-mini, gpt-5-nano, gpt-4.1, gpt-4.1-mini | API Key |
| Gemini | gemini-2.5-flash-lite (其他模型需要更高 quota) | API Key |
| Groq | llama-3.1-8b-instant, llama-3.3-70b-versatile, 等 7 个模型 | API Key |
| Cerebras | gpt-oss-120b, llama-3.1-8b, llama-3.3-70b, qwen-3-32b, qwen-3-235b | API Key |
| AWS Bedrock | claude-haiku-4-5, claude-sonnet-4-5, claude-sonnet-4, claude-3-7-sonnet, gpt-oss-120b | Bearer Token / Access Key / AWS Profile |

### 测试内容

每个提供商测试包括：
1. **模型测试** - 验证每个模型的文本增强功能
2. **语义验证** - 确保响应包含有意义的内容
3. **错误处理** - 测试空输入等边界情况

## 已知问题和解决方案

### 1. Gemini Rate Limiting

**问题**: Gemini 免费 tier 有严格的 rate limit，多个模型测试会失败。

**解决方案**: 
- 测试已配置为只运行 `gemini-2.5-flash-lite`（最稳定）
- 其他模型标记为 disabled，需要付费 API 才能测试
- 如需测试所有模型，在 `GeminiIntegrationTests.swift` 中移除 `.disabled()` 标记

### 2. OpenAI Temperature 参数

**问题**: `gpt-5-mini` 和 `gpt-5-nano` 不支持自定义 temperature 参数。

**解决方案**: 代码已修复，对这些模型不发送 temperature 参数。

### 3. Cerebras 模型不存在

**问题**: `llama-4-scout-17b-16e-instruct` 模型在 Cerebras API 中不存在。

**解决方案**: 已从模型列表中移除。

### 4. AWS SigV4 URL 编码

**问题**: Bedrock 模型 ID 包含 `:` 字符，需要正确编码为 `%3A`。

**解决方案**: `AWSSigV4Signer` 已修复，正确处理 URL 路径编码。

## AWS Bedrock 认证方式

HoAh 支持三种 AWS Bedrock 认证方式：

### 1. Bearer Token (API Key)
最简单的方式，从 AWS Bedrock 控制台获取 Bearer Token。
```
AWS_BEDROCK_API_KEY=ABSKxxx
```

### 2. AWS Access Key
直接使用 IAM Access Key 和 Secret Key，无需配置 AWS Profile 文件。
```
# 在 HoAh 设置中选择 "Access Key" 认证方式
# 输入 Access Key ID 和 Secret Access Key
```

### 3. AWS Profile
使用 `~/.aws/credentials` 中配置的 profile，支持 SSO、assume-role 等。
```bash
# 创建 AWS Profile
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = xxx
EOF

cat > ~/.aws/config << EOF
[default]
region = us-west-2
EOF
```

## 添加新测试

### 添加新模型测试

1. 在对应的 `*IntegrationTests.swift` 文件中添加测试方法：
```swift
@Test("Test new-model text enhancement")
func testNewModelEnhancement() async throws {
    try await testModelEnhancement(model: "new-model-name")
}
```

2. 更新 `availableModels` 数组。

### 添加新提供商测试

1. 在 `HoAhTests/IntegrationTests/Providers/` 创建新文件
2. 参考现有测试文件结构
3. 在 `TestConfiguration` 中添加新的 API Key 字段
4. 在 `AIEnhancementTestHelper` 中添加 API Key 获取逻辑

## 测试文件结构

```
HoAhTests/
└── IntegrationTests/
    ├── AIEnhancementIntegrationTests.swift  # 测试配置和工具类
    ├── AIEnhancementTestHelper.swift        # 测试辅助类
    └── Providers/
        ├── OpenAIIntegrationTests.swift
        ├── GeminiIntegrationTests.swift
        ├── GroqIntegrationTests.swift
        ├── CerebrasIntegrationTests.swift
        ├── BedrockIntegrationTests.swift        # Bearer Token 认证
        └── BedrockProfileIntegrationTests.swift # Profile/SigV4 认证
```

## 安全注意事项

- `.env.test` 已添加到 `.gitignore`，不会被提交
- API Keys 存储在本地，不要分享或提交
- 测试日志中的 API Key 会被掩码处理（显示为 `xxxx****xxxx`）

## 故障排除

### 测试找不到 .env.test 文件

确保文件在项目根目录，测试会尝试以下路径：
1. `Bundle.main.bundlePath + "/../../../../.env.test"`
2. `FileManager.currentDirectoryPath + "/.env.test"`
3. 源代码目录（通过 `#file`）

### Rate Limit 错误

- 等待几分钟后重试
- 减少并行测试数量
- 考虑升级 API 计划

### 认证失败

- 检查 API Key 是否正确
- 确认 API Key 有相应权限
- 对于 AWS，确认 IAM 策略包含 `bedrock:InvokeModel` 权限

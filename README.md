<div align="center">
  <img src="HoAh/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>HoAh (吼蛙)</h1>
  <p>macOS 语音转文字工具。本地捕捉音频，AI Agent 整理成文。</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

**简体中文** | [English](README_EN.md)

---

**HoAh** 是一款为 macOS 精心打造的语音转文字工具。它的工作流简单而强大：
1.  **语音**：录制你的声音。
2.  **文本**：通过本地 Whisper 模型快速转录。
3.  **结构化**：**AI Agents** (LLM) 瞬间将原始文本处理为格式规范的邮件、会议纪要、代码片段或润色后的文章。

它支持多种语言、自定义 Agent 提示词（Prompts），并且默认完全本地运行。无需订阅，只需你的声音和（可选的）API Key。

## 功能特性

- **自适应 Agents**：锁定一个 **主角色**，或使用 **App 触发器** 根据你当前活动的窗口自动切换模式。
- **本地与云端智能**：既可以运行本地 Whisper 模型，也可以连接云端 AI 提供商。
- **轻量专注**：剔除冗余，专注于核心流程：语音 → 转录 (+ 可选 AI)。
- **永久免费**：完全开源。无订阅费，无付费墙。

## 系统要求

- macOS 14.0 或更高版本

## 贡献

欢迎提交 PR。在开启 PR 或 Issue 之前，请先浏览 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

本项目采用 GNU General Public License v3.0 许可证 – 详见 [LICENSE](LICENSE)。

## 支持

如有问题，请提交 Issue，并提供清晰的复现步骤、macOS 版本以及您使用的模型/提供商设置。

## 致谢

- 原应用来自 Pax (VoiceInk) – 感谢其开源以及 HoAh 基于的 GPL 许可证。
- 核心技术：[whisper.cpp](https://github.com/ggerganov/whisper.cpp), [FluidAudio](https://github.com/FluidInference/FluidAudio)
- 我们依赖的库：[Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin), [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit), [Swift Atomics](https://github.com/apple/swift-atomics)

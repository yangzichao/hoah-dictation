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

## 场景演示

HoAh 的核心理念是：**转录忠实还原，Agent 负责加工。** 你可以随心所欲地说话，后续交给 AI 整理。

### 场景：推迟会议 (中英混杂 + 口语)

**1. 你的语音 (Raw Input)**
> “那个……我觉得就是，嗯，今天下午的那个 **meeting** 吧，可能得推迟一下，因为那个…… PPT 还没做完，**data** 还有点问题。”

**2. 基础转录 (Whisper)**
> *（忠实还原口语和单词）*
> “那个……我觉得就是，嗯，今天下午的那个 meeting 吧，可能得推迟一下，因为那个…… PPT 还没做完，data 还有点问题。”

**3. Agent 增强 (Magic Happens Here)**

*   **如果用 [润色 Agent] (Default)：**
    > “我觉得今天下午的 meeting 可能得推迟一下，因为 PPT 还没做完，data 还有点问题。”
    > *(去除口癖，保留原意，句子变流畅)*

*   **如果用 [邮件 Agent]：**
    > **主题：** 关于推迟今日 Meeting 的通知
    > **正文：** 大家好，由于 PPT 尚未定稿且 data 需进一步核实，建议推迟原定于今天下午的 Meeting。确认时间后将另行通知。
    > *(结构化重写)*

### 场景：技术故障 (Dev / DevOps)

**1. 你的语音**
> “刚看了一下 **Sentry**，那个支付的 **API** 又挂了，全是 500 错误，我觉得可能是 **Database** 连接池爆了，得赶紧 **Hotfix** 一下，不然 **Traffic** 上来就崩了。”

**2. Agent 增强**
> **紧急故障:** 支付 API 返回 500 (Sentry 报警)。
> **原因推测:** Database 连接池耗尽。
> **行动:** 需立即 Hotfix 以应对流量高峰。

### 场景：产品脑暴 (Product / Design)

**1. 你的语音**
> “我们也应该加个 **Dark Mode**，最好是那种 **Neon** 风格的配色，现在的 **User Interface** 太素了，用户想要那种 **Cyberpunk** 的感觉，酷一点。”

**2. Agent 增强**
> **需求建议:** 增加对应 Neon/Cyberpunk 风格的 Dark Mode。
> **理由:** 当前 UI 过于平淡，需提升视觉酷炫感以满足用户偏好。

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

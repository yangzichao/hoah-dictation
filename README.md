<div align="center">
  <img src="HoAh/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>HoAh (吼蛙)</h1>
  <p>Speech-to-text for macOS. Capture audio locally, then let AI Agents structure it.</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

**English** | [简体中文](README_CN.md)

---

**HoAh** is a refined speech-to-text tool for macOS. The workflow is simple but powerful:
1.  **Speech**: Record your voice.
2.  **Text**: Fast, local transcription via Whisper.
3.  **Structure**: **AI Agents** (LLMs) instantly process that raw text into formatted emails, meeting notes, code snippets, or polished prose.

It supports multiple languages, custom agent prompts, and runs fully local by default. No subscriptions, just your voice and your key.


## Features

- **Adaptive Agents**: Lock in a **Primary Role**, or use **App Triggers** to auto-switch based on your active window.
- **Local & Cloud Intelligence**: Run local Whisper models or connect to cloud providers.
- **Lightweight Focus**: Trimmed extras; core flow is voice → transcript (+ optional AI).
- **Forever Free**: Fully open-source. No subscriptions, no paywalls.

## Requirements

- macOS 14.0 or later

## Contributing

PRs are welcome. Please skim [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR or issue.

## License

This project is licensed under the GNU General Public License v3.0 – see [LICENSE](LICENSE).

## Support

Open an issue with clear steps to reproduce, macOS version, and model/provider settings you used.

## Acknowledgments

- Original app by Pax (VoiceInk) – thanks for open sourcing and the GPL license that HoAh builds upon.
- Core tech: [whisper.cpp](https://github.com/ggerganov/whisper.cpp), [FluidAudio](https://github.com/FluidInference/FluidAudio)
- Dependencies we rely on: [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin), [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit), [Swift Atomics](https://github.com/apple/swift-atomics)

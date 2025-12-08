<div align="center">
  <img src="HoAh/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>HoAh (吼蛙)</h1>
  <p>Faithful, multi-language transcription locally. AI Agents transform it for your needs.</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

[简体中文](README.md) | **English** | [Website](https://yangzichao.github.io/hoah-dictation/)

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

## Examples

HoAh's core philosophy: **Transcription captures reality; Agents polish it to perfection.** You can speak naturally, stutter and all, and let AI handle the formatting.

### Scenario: Coding (Natural Speech to Code)

**1. Your Voice (Raw Input)**
> "So, um, basically I want to write a Python function that, uh, takes a list of users, you know, and filters out the ones that are, like, inactive. Yeah, just keep the active ones."

**2. Basic Transcript (Whisper)**
> *(Faithful metadata)*
> "So, um, basically I want to write a Python function that, uh, takes a list of users, you know, and filters out the ones that are, like, inactive. Yeah, just keep the active ones."

**3. Agent Enhancement**

*   **Using [Polishing Agent] (Default):**
    > "I want to write a Python function that takes a list of users and filters out the inactive ones, keeping only the active users."
    > *(Fluent, concise text)*

*   **Using [Coding Agent]:**
    ```python
    def filter_active_users(users):
        """
        Filters a list of users to return only those who are active.
        """
        return [user for user in users if user.is_active]
    ```
    *(Directly executable code)*

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

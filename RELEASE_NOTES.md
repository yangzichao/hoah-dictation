# What's New in# Release Notes

## [3.1.7]
### Fixes
- **Build**: Fixed critical build issue introduced in v3.1.6.

## [3.1.6]
### Fixes
- **Localization**: Added missing Chinese/English localization for the "Selected Text Context" setting.
- **UI Refresh**: Fixed an issue where the AI Provider status indicator wouldn't update immediately after adding or removing an API key.

## [3.1.5]

### ✨ New Features
- **Selected Text Context Toggle**: Added a new toggle in AI Enhancement settings to give you explicit control over whether currently selected text is used as context. Defaults to OFF.

### 🚀 Improvements
- **Auto-Detect Language Enforcement**: Enforced "Auto Detect" language for Gemini and other AI models to strictly prevent unwanted translation to English. The AI will now transcribe in the original language of the audio.

### 🐛 Bug Fixes
- **Language Logic**: Decoupled the App Interface Language from the Transcription Language. Selecting a UI language (e.g., Chinese) no longer forces the transcription model to that language; it remains on "Auto Detect" by default.

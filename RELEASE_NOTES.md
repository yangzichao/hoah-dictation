# What's New in# Release Notes

## [3.2.5]

### 🚀 Improvements
- **Stability**: Minor bug fixes and stability improvements.

## [3.2.4]

### 🚀 Improvements
- **Stability**: Minor bug fixes and stability improvements.

## [3.2.3]

### 🚀 Improvements
- **Concurrency**: Modernized async operations by replacing legacy `Thread.sleep` with `Task.sleep` for better performance and battery life.
- **Code Quality**: Refactored variable naming for better clarity and maintainability.

## [3.2.2]

### ✨ New Features
- **Robust AWS Authentication**: Implemented complete SigV4 signing for Bedrock requests, with automatic fallback to API Key if no profile is active.
- **Smart Validation**: Added asynchronous validation for AWS profiles and regions to ensure configuration is correct before use.

### 🚀 Improvements
- **Credential Parsing**: Enhanced parsing to support JSON output formats and cleaner region extraction.

## [3.2.1]

### ✨ New Features
- **AWS Profile Support**: Comprehensive AWS profile management for Bedrock. You can now use your local AWS CLI credentials directly with SigV4 signing.
- **Onboarding UX**: Added app restart functionality and clearer hints for Accessibility Permission setup.
- **Model Info**: Displayed speed and accuracy indicators for models in the onboarding screen.

### 🚀 Improvements
- **Cleanup**: Removed custom cloud model management and Amazon Nova models to streamline the experience.

## [3.2.0]

### ✨ New Features
- **Secure AI Configuration**: Refactored AI configuration management to use the system Keychain for secure storage of API keys and credentials.
- **Smart State Management**: AI enhancement now automatically disables if all configurations are deleted, ensuring a smoother user experience.
- **Localization**: Added specific localized strings for the new AI configuration screens.

### 🐛 Bug Fixes
- **Settings Reset**: Fixed an issue where AI enhancement and prompt triggers were unintentionally preserved when creating a new settings state.

## [3.1.8]

### ✨ New Features
- **Reset System Settings**: Implemented a "Reset System Settings" feature that allows restoring default preferences (appearance, audio, etc.) while carefully preserving your AI assets (API keys, models, prompts, user profile) and custom shortcuts.

### 🚀 Improvements
- **Onboarding UX**: Improved the "Accessibility Permission" flow to offer a restart option if granted, and fixed app focus issues after permission prompts.

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

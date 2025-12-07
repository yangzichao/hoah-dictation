import SwiftUI

// Define a display mode for flexible usage
enum LanguageDisplayMode {
    case full // For settings page with descriptions
    case menuItem // For menu bar with compact layout
}

struct LanguageSelectionView: View {
    @ObservedObject var whisperState: WhisperState
    @AppStorage("SelectedLanguage") private var selectedLanguage: String = "auto"
    @AppStorage("HasManuallySelectedLanguage") private var hasManuallySelectedLanguage = false
    // Add display mode parameter with full as the default
    var displayMode: LanguageDisplayMode = .full
    @ObservedObject var whisperPrompt: WhisperPrompt

    private func updateLanguage(_ language: String, isUserSelection: Bool = false) {
        // Update UI state - the UserDefaults updating is now automatic with @AppStorage
        selectedLanguage = language
        if isUserSelection {
            hasManuallySelectedLanguage = true
        }

        // Force the prompt to update for the new language
        whisperPrompt.updateTranscriptionPrompt()

        // Post notification for language change
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
    
    // Function to check if current model is multilingual
    private func isMultilingualModel() -> Bool {
        guard let currentModel = whisperState.currentTranscriptionModel else {
            return false
        }
        return currentModel.isMultilingualModel
    }

    private func languageSelectionDisabled() -> Bool {
        guard let provider = whisperState.currentTranscriptionModel?.provider else {
            return false
        }
        return provider == .parakeet || provider == .gemini
    }

    // Function to get current model's supported languages
    private func getCurrentModelLanguages() -> [String: String] {
        guard let currentModel = whisperState.currentTranscriptionModel else {
            return ["en": "English"] // Default to English if no model found
        }
        return currentModel.supportedLanguages
    }

    // Get the display name of the current language
    private func currentLanguageDisplayName() -> String {
        return getCurrentModelLanguages()[selectedLanguage] ?? "Unknown"
    }

    private func preferredFallbackLanguage(from languages: [String: String], prefersAuto: Bool) -> String {
        if prefersAuto, languages.keys.contains("auto") {
            return "auto"
        }
        // Prefer English variants when auto is unavailable
        if let english = languages.keys.first(where: { $0 == "en" || $0.hasPrefix("en-") }) {
            return english
        }
        return languages.keys.sorted().first ?? "auto"
    }

    private func applyDefaultLanguageIfNeeded(for model: (any TranscriptionModel)?) {
        guard let model else { return }
        let languages = model.supportedLanguages
        let supportsAuto = languages.keys.contains("auto")
        let isEnglishOnly = !model.isMultilingualModel
        let currentSelectionIsValid = languages[selectedLanguage] != nil
        let defaultLanguage = preferredFallbackLanguage(from: languages, prefersAuto: supportsAuto)
        let isEnglishSelection = selectedLanguage == "en" || selectedLanguage.hasPrefix("en-")

        if isEnglishOnly {
            hasManuallySelectedLanguage = false
            updateLanguage(defaultLanguage)
            return
        }

        if !currentSelectionIsValid {
            hasManuallySelectedLanguage = false
            updateLanguage(defaultLanguage)
            return
        }

        if !hasManuallySelectedLanguage && selectedLanguage != "auto" && currentSelectionIsValid && !isEnglishSelection {
            // Preserve explicit non-English selections that may have come from other flows (e.g., Power Mode)
            hasManuallySelectedLanguage = true
        }

        if supportsAuto && !hasManuallySelectedLanguage && selectedLanguage != "auto" && isEnglishSelection {
            updateLanguage("auto")
        }
    }

    var body: some View {
        switch displayMode {
        case .full:
            fullView
        case .menuItem:
            menuItemView
        }
    }

    // The original full view layout for settings page
    private var fullView: some View {
        VStack(alignment: .leading, spacing: 16) {
            languageSelectionSection
        }
    }
    
    private var languageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription Language")
                .font(.headline)

            if let currentModel = whisperState.currentTranscriptionModel
            {
                if languageSelectionDisabled() {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Language: Autodetected")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Text("Current model: \(currentModel.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("The transcription language is automatically detected by the model.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .disabled(true)
                } else if isMultilingualModel() {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(
                            "Select Language",
                            selection: Binding(
                                get: { selectedLanguage },
                                set: { newValue in
                                    updateLanguage(newValue, isUserSelection: true)
                                }
                            )
                        ) {
                            ForEach(
                                currentModel.supportedLanguages.sorted(by: {
                                    if $0.key == "auto" { return true }
                                    if $1.key == "auto" { return false }
                                    return $0.value < $1.value
                                }), id: \.key
                            ) { key, value in
                                Text(value).tag(key)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        Text("Current model: \(currentModel.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(
                            "This model supports multiple languages. Select a specific language or auto-detect(if available)"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .onAppear {
                        let languages = currentModel.supportedLanguages
                        if selectedLanguage.isEmpty || languages[selectedLanguage] == nil {
                            hasManuallySelectedLanguage = false
                            updateLanguage(languages.keys.contains("auto") ? "auto" : (languages.keys.sorted().first ?? "auto"))
                        }
                        applyDefaultLanguageIfNeeded(for: currentModel)
                    }
                } else {
                    // For English-only models, force set language to English
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Language: English")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Text("Current model: \(currentModel.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(
                            "This is an English-optimized model and only supports English transcription."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .onAppear {
                        // Ensure English is set when viewing English-only model
                        hasManuallySelectedLanguage = false
                        updateLanguage("en")
                    }
                }
            } else {
                Text("No model selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    // New compact view for menu bar
    private var menuItemView: some View {
        Group {
            if languageSelectionDisabled() {
                Button {
                    // Do nothing, just showing info
                } label: {
                    Text("Language: Autodetected")
                        .foregroundColor(.secondary)
                }
                .disabled(true)
            } else if isMultilingualModel() {
                Menu {
                    ForEach(
                        getCurrentModelLanguages().sorted(by: {
                            if $0.key == "auto" { return true }
                            if $1.key == "auto" { return false }
                            return $0.value < $1.value
                        }), id: \.key
                    ) { key, value in
                        Button {
                            updateLanguage(key, isUserSelection: true)
                        } label: {
                            HStack {
                                Text(value)
                                if selectedLanguage == key {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Language: \(currentLanguageDisplayName())")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                }
            } else {
                // For English-only models
                Button {
                    // Do nothing, just showing info
                } label: {
                    Text("Language: English (only)")
                        .foregroundColor(.secondary)
                }
                .disabled(true)
                .onAppear {
                    // Ensure English is set for English-only models
                    hasManuallySelectedLanguage = false
                    updateLanguage("en")
                }
            }
        }
        .onAppear {
            applyDefaultLanguageIfNeeded(for: whisperState.currentTranscriptionModel)
        }
        .onChange(of: whisperState.currentTranscriptionModel?.name) { _, _ in
            applyDefaultLanguageIfNeeded(for: whisperState.currentTranscriptionModel)
        }
    }
}

import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var whisperState: WhisperState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var appSettings: AppSettingsStore
    @EnvironmentObject var validationService: ConfigurationValidationService
    @ObservedObject var audioDeviceManager = AudioDeviceManager.shared
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            Button(LocalizedStringKey("open_hoah_dashboard")) {
                menuBarManager.openMainWindowAndNavigate(to: "HoAh")
            }
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            
            Divider()
            
            Menu {
                ForEach(whisperState.usableModels, id: \.id) { model in
                    Button {
                        Task {
                            await whisperState.setDefaultTranscriptionModel(model)
                        }
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if whisperState.currentTranscriptionModel?.id == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(NSLocalizedString("Manage Models", comment: "")) {
                    menuBarManager.openMainWindowAndNavigate(to: "AI Models")
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("Transcription Model: %@", comment: ""), whisperState.currentTranscriptionModel?.displayName ?? NSLocalizedString("None", comment: "")))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }

            Menu {
                ForEach(HotkeyManager.HotkeyOption.allCases, id: \.self) { option in
                    Button {
                        hotkeyManager.selectedHotkey1 = option
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if hotkeyManager.selectedHotkey1 == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(NSLocalizedString("Configure Shortcuts", comment: "")) {
                    menuBarManager.openMainWindowAndNavigate(to: "Settings")
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("Hotkey: %@", comment: ""), hotkeyManager.selectedHotkey1.displayName))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            Divider()
            
            Toggle(NSLocalizedString("AI Enhancement", comment: ""), isOn: $appSettings.isAIEnhancementEnabled)
            
            Menu {
                ForEach(enhancementService.activePrompts) { prompt in
                    Button {
                        enhancementService.setActivePrompt(prompt)
                    } label: {
                        HStack {
                            Image(systemName: prompt.icon)
                                .foregroundColor(.accentColor)
                            Text(prompt.title)
                            if enhancementService.selectedPromptId == prompt.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("Prompt: %@", comment: ""), enhancementService.activePrompt?.title ?? NSLocalizedString("None", comment: "")))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            // AI Configuration Quick Switch (with validation)
            Menu {
                ForEach(appSettings.validAIConfigurations) { config in
                    Button {
                        validationService.switchToConfiguration(id: config.id)
                    } label: {
                        HStack {
                            Image(systemName: config.providerIcon)
                            Text(config.name)
                            if validationService.validatingConfigId == config.id {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else if appSettings.activeAIConfigurationId == config.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(validationService.validatingConfigId != nil)
                }
                
                if appSettings.validAIConfigurations.isEmpty {
                    Text(NSLocalizedString("No configurations available", comment: ""))
                        .foregroundColor(.secondary)
                }
                
                // Show validation error if any
                if let error = validationService.validationError {
                    Divider()
                    Text(error.errorDescription ?? NSLocalizedString("Validation failed", comment: ""))
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Divider()
                
                Button(NSLocalizedString("Manage Configurations...", comment: "")) {
                    menuBarManager.openMainWindowAndNavigate(to: "Enhancement")
                }
            } label: {
                HStack {
                    if validationService.validatingConfigId != nil {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text(String(format: NSLocalizedString("AI Config: %@", comment: ""), appSettings.activeAIConfiguration?.name ?? NSLocalizedString("None", comment: "")))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            LanguageSelectionView(whisperState: whisperState, displayMode: .menuItem, whisperPrompt: whisperState.whisperPrompt)

            Menu {
                ForEach(audioDeviceManager.availableDevices, id: \.id) { device in
                    Button {
                        audioDeviceManager.selectDeviceAndSwitchToCustomMode(id: device.id)
                    } label: {
                        HStack {
                            Text(device.name)
                            if audioDeviceManager.getCurrentDevice() == device.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if audioDeviceManager.availableDevices.isEmpty {
                    Text(NSLocalizedString("No devices available", comment: ""))
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Text(LocalizedStringKey("Audio Input"))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }

            Menu(NSLocalizedString("Additional", comment: "")) {
                Toggle(
                    NSLocalizedString("Clipboard Context", comment: ""),
                    isOn: $appSettings.useClipboardContext
                )
            }
            
            Divider()
            
            Button(NSLocalizedString("Retry Last Transcription", comment: "")) {
                LastTranscriptionService.retryLastTranscription(from: whisperState.modelContext, whisperState: whisperState)
            }
            
            Button(NSLocalizedString("Copy Last Transcription", comment: "")) {
                LastTranscriptionService.copyLastTranscription(from: whisperState.modelContext)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button(NSLocalizedString("History", comment: "")) {
                menuBarManager.openMainWindowAndNavigate(to: "History")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            
            Button(appSettings.isMenuBarOnly ? NSLocalizedString("Show Dock Icon", comment: "") : NSLocalizedString("Hide Dock Icon", comment: "")) {
                appSettings.isMenuBarOnly.toggle()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            
            Toggle(LocalizedStringKey("Launch at Login"), isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { oldValue, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            
            Button(NSLocalizedString("Settings", comment: "")) {
                menuBarManager.openMainWindowAndNavigate(to: "Settings")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button(NSLocalizedString("Quit HoAh", comment: "")) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

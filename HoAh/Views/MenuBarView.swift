import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var whisperState: WhisperState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var aiService: AIService
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
                
                Button("Manage Models") {
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
                
                Button("Configure Shortcuts") {
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
            
            Toggle("AI Enhancement", isOn: $enhancementService.isEnhancementEnabled)
            
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
            
            Menu {
                ForEach(aiService.connectedProviders, id: \.self) { provider in
                    Button {
                        aiService.selectedProvider = provider
                    } label: {
                        HStack {
                            Text(provider.rawValue)
                            if aiService.selectedProvider == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if aiService.connectedProviders.isEmpty {
                    Text("No providers connected")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("AI Provider: %@", comment: ""), aiService.selectedProvider.rawValue))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            Menu {
                ForEach(aiService.availableModels, id: \.self) { model in
                    Button {
                        aiService.selectModel(model)
                    } label: {
                        HStack {
                            Text(model)
                            if aiService.currentModel == model {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if aiService.availableModels.isEmpty {
                    Text("No models available")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("AI Model: %@", comment: ""), aiService.currentModel))
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
                    Text("No devices available")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Text(LocalizedStringKey("Audio Input"))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }

            Menu("Additional") {
                Toggle(
                    "Clipboard Context",
                    isOn: Binding(
                        get: { enhancementService.useClipboardContext },
                        set: { enhancementService.useClipboardContext = $0 }
                    )
                )
            }
            
            Divider()
            
            Button("Retry Last Transcription") {
                LastTranscriptionService.retryLastTranscription(from: whisperState.modelContext, whisperState: whisperState)
            }
            
            Button("Copy Last Transcription") {
                LastTranscriptionService.copyLastTranscription(from: whisperState.modelContext)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button("History") {
                menuBarManager.openMainWindowAndNavigate(to: "History")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            
            Button(menuBarManager.isMenuBarOnly ? "Show Dock Icon" : "Hide Dock Icon") {
                menuBarManager.toggleMenuBarOnly()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            
            Toggle(LocalizedStringKey("Launch at Login"), isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { oldValue, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            
            Button("Settings") {
                menuBarManager.openMainWindowAndNavigate(to: "Settings")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button("Quit HoAh") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

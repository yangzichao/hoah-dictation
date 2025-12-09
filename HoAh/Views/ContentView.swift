import SwiftUI
import SwiftData
import KeyboardShortcuts

// ViewType enum with all cases
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "HoAh"
    case agentMode = "AI Agents"
    case smartScenes = "Smart Scenes"
    case models = "AI Models"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case transcribeAudio = "Transcribe Audio"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .metrics: return "gauge.medium"
        case .transcribeAudio: return "waveform.circle.fill"
        case .models: return "brain.head.profile"
        case .agentMode: return "wand.and.stars"
        case .smartScenes: return "sparkles.square.fill.on.square"
        case .permissions: return "shield.fill"
        case .audioInput: return "mic.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var appSettings: AppSettingsStore
    @State private var selectedView: ViewType? = .metrics
    // DEPRECATED: Use AppSettingsStore instead of @AppStorage
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private var visibleViewTypes: [ViewType] {
        ViewType.allCases.filter { view in
            if view == .smartScenes {
                return enhancementService.isEnhancementEnabled
            }
            if view == .transcribeAudio {
                return appSettings.isTranscribeAudioEnabled
            }
            return true
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section {
                    NavigationLink(value: ViewType.metrics) {
                        HStack(spacing: 8) {
                            if let appIcon = NSImage(named: "AppIcon") {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(8)
                            }

                            Text("HoAh")
                                .font(.system(size: 14, weight: .semibold))

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                }

                ForEach(visibleViewTypes.filter { $0 != .metrics }) { viewType in
                    Section {
                        NavigationLink(value: viewType) {
                            HStack(spacing: 12) {
                                Image(systemName: viewType.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 24, height: 24)

                                Text(LocalizedStringKey(viewType.rawValue))
                                    .font(.system(size: 14, weight: .medium))

                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("HoAh")
            .navigationSplitViewColumnWidth(210)
        } detail: {
            if let selectedView = selectedView {
                detailView(for: selectedView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(LocalizedStringKey(selectedView.rawValue))
            } else {
                Text("Select a view")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 940, minHeight: 730)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            if let destination = notification.userInfo?["destination"] as? String {
                switch destination {
                case "Settings":
                    selectedView = .settings
                case "AI Models":
                    selectedView = .models
                case "History":
                    selectedView = .metrics
                case "Permissions":
                    selectedView = .permissions
                case "AI Agents":
                    selectedView = .agentMode
                case "Transcribe Audio":
                    appSettings.isTranscribeAudioEnabled = true
                    selectedView = .transcribeAudio
                case "Smart Scenes":
                    if enhancementService.isEnhancementEnabled {
                        selectedView = .smartScenes
                    } else {
                        selectedView = .metrics
                    }
                case "HoAh", "Dashboard":
                    selectedView = .metrics
                default:
                    break
                }
            }
        }
        .onChange(of: enhancementService.isEnhancementEnabled) { _, isEnabled in
            if !isEnabled, selectedView == .smartScenes {
                selectedView = .metrics
            }
        }
        .onChange(of: appSettings.isTranscribeAudioEnabled) { _, isEnabled in
            if !isEnabled, selectedView == .transcribeAudio {
                selectedView = .metrics
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .metrics:
            MetricsView()
        case .models:
            ModelManagementView(whisperState: whisperState)
        case .agentMode:
            EnhancementSettingsView()
        case .transcribeAudio:
            AudioTranscribeView()
        case .audioInput:
            AudioInputSettingsView()
        case .smartScenes:
            SmartScenesView()
        case .settings:
            SettingsView()
                .environmentObject(whisperState)
        case .permissions:
            PermissionsView()
        }
    }
}

 

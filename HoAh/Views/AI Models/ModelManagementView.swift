import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum ModelFilter: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case local = "Local"
    case cloud = "Cloud"
    var id: String { self.rawValue }
}

/// ModelManagementView manages transcription models (speech-to-text).
/// For AI enhancement providers (text post-processing), see EnhancementSettingsView.
struct ModelManagementView: View {
    @ObservedObject var whisperState: WhisperState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var whisperPrompt = WhisperPrompt()
    @ObservedObject private var warmupCoordinator = WhisperModelWarmupCoordinator.shared

    @State private var selectedFilter: ModelFilter = .recommended
    @State private var isShowingSettings = false
    
    // State for the unified alert
    @State private var isShowingDeleteAlert = false
    @State private var alertTitle: LocalizedStringKey = ""
    @State private var alertMessage = ""
    @State private var deleteActionClosure: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                defaultModelSection
                languageSelectionSection
                availableModelsSection
            }
            .padding(40)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .destructive(Text("Delete"), action: deleteActionClosure),
                secondaryButton: .cancel()
            )
        }
    }
    
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Transcription Model")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(whisperState.currentTranscriptionModel?.displayName ?? String(localized: "No model selected"))
                .font(.title2)
                .fontWeight(.bold)
            
            // Show recommendation when no model is selected
            if whisperState.currentTranscriptionModel == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 4)
                    Text("Our Recommendations")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                (Text("For local processing")
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                + Text(": ")
                                    .foregroundColor(.secondary)
                                + Text("Large v3 Turbo")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor))
                                
                                Text("Local Model Description")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption)
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                (Text("For cloud processing")
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                + Text(": ")
                                    .foregroundColor(.secondary)
                                + Text("Scribe v2 (ElevenLabs)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor))
                                
                                Text("Cloud Model Description")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(10)
    }
    
    private var languageSelectionSection: some View {
        LanguageSelectionView(whisperState: whisperState, displayMode: .full, whisperPrompt: whisperPrompt)
    }
    
    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Modern compact pill switcher
                HStack(spacing: 12) {
                    ForEach(ModelFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedFilter = filter
                                isShowingSettings = false
                            }
                        }) {
                            Text(LocalizedStringKey(filter.rawValue))
                                .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .medium))
                                .foregroundColor(selectedFilter == filter ? .primary : .primary.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    CardBackground(isSelected: selectedFilter == filter, cornerRadius: 22)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingSettings.toggle()
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isShowingSettings ? .accentColor : .primary.opacity(0.7))
                        .padding(12)
                        .background(
                            CardBackground(isSelected: isShowingSettings, cornerRadius: 22)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 12)
            
            if isShowingSettings {
                ModelSettingsView(whisperPrompt: whisperPrompt)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredModels, id: \.id) { model in
                        let isWarming = (model as? LocalModel).map { localModel in
                            warmupCoordinator.isWarming(modelNamed: localModel.name)
                        } ?? false

                        ModelCardRowView(
                            model: model,
                            whisperState: whisperState, 
                            isDownloaded: whisperState.availableModels.contains { $0.name == model.name },
                            isCurrent: whisperState.currentTranscriptionModel?.name == model.name,
                            downloadProgress: whisperState.downloadProgress,
                            modelURL: whisperState.availableModels.first { $0.name == model.name }?.url,
                            isWarming: isWarming,
                            deleteAction: {
                                if let downloadedModel = whisperState.availableModels.first(where: { $0.name == model.name }) {
                                    alertTitle = "Delete Model"
                                    alertMessage = String(
                                        format: String(localized: "Are you sure you want to delete the model '%@'?"),
                                        downloadedModel.name
                                    )
                                    deleteActionClosure = {
                                        Task {
                                            await whisperState.deleteModel(downloadedModel)
                                        }
                                    }
                                    isShowingDeleteAlert = true
                                }
                            },
                            setDefaultAction: {
                                Task {
                                    await whisperState.setDefaultTranscriptionModel(model)
                                }
                            },
                            downloadAction: {
                                if let localModel = model as? LocalModel {
                                    Task { await whisperState.downloadModel(localModel) }
                                }
                            },
                            editAction: nil
                        )
                    }
                    
                    // Import button as a card at the end of the Local list
                    if selectedFilter == .local {
                        HStack(spacing: 8) {
                            Button(action: { presentImportPanel() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import Local Model…")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(CardBackground(isSelected: false))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            InfoTip(
                                title: "Import local Whisper models",
                                message: "Add a custom fine-tuned whisper model to use with HoAh. Select the downloaded .bin file.",
                                learnMoreURL: "https://tryvoiceink.com/docs/custom-local-whisper-models"
                            )
                            .help("Read more about custom local models")
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var filteredModels: [any TranscriptionModel] {
        switch selectedFilter {
        case .recommended:
            return whisperState.allAvailableModels.filter {
                let recommendedNames = ["ggml-large-v3-turbo", "scribe_v2", "whisper-large-v3-turbo"]
                return recommendedNames.contains($0.name)
            }.sorted { model1, model2 in
                let recommendedOrder = ["ggml-large-v3-turbo", "scribe_v2", "whisper-large-v3-turbo"]
                let index1 = recommendedOrder.firstIndex(of: model1.name) ?? Int.max
                let index2 = recommendedOrder.firstIndex(of: model2.name) ?? Int.max
                return index1 < index2
            }
        case .local:
            return whisperState.allAvailableModels.filter { $0.provider == .local || $0.provider == .nativeApple }
        case .cloud:
            let cloudProviders: [ModelProvider] = [.groq, .elevenLabs, .gemini]
            return whisperState.allAvailableModels.filter { cloudProviders.contains($0.provider) }
        }
    }

    // MARK: - Import Panel
    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "bin")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.title = "Select a Whisper ggml .bin model"
        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await whisperState.importLocalModel(from: url)
            }
        }
    }
}

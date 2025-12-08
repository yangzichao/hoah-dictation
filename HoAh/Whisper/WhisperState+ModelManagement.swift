import Foundation
import SwiftUI

@MainActor
extension WhisperState {
    // Loads the default transcription model from UserDefaults
    func loadCurrentTranscriptionModel() {
        if let savedModelName = UserDefaults.standard.string(forKey: "CurrentTranscriptionModel"),
           let savedModel = allAvailableModels.first(where: { $0.name == savedModelName }) {
            currentTranscriptionModel = savedModel
            return
        }
        
        // No saved model found – select a sensible default so the app
        // is usable on first launch without extra configuration.
        selectDefaultTranscriptionModelIfNeeded()
    }

    // Function to set any transcription model as default
    func setDefaultTranscriptionModel(_ model: any TranscriptionModel) {
        self.currentTranscriptionModel = model
        UserDefaults.standard.set(model.name, forKey: "CurrentTranscriptionModel")
        
        // For cloud models, clear the old loadedLocalModel
        if model.provider != .local {
            self.loadedLocalModel = nil
        }
        
        // Enable transcription for cloud models immediately since they don't need loading
        if model.provider != .local {
            self.isModelLoaded = true
        }
        // Post notification about the model change
        NotificationCenter.default.post(name: .didChangeModel, object: nil, userInfo: ["modelName": model.name])
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
    
    func refreshAllAvailableModels() {
        let currentModelName = currentTranscriptionModel?.name
        var models = PredefinedModels.models

        // Append dynamically discovered local models (imported .bin files) with minimal metadata
        for whisperModel in availableModels {
            if !models.contains(where: { $0.name == whisperModel.name }) {
                let importedModel = ImportedLocalModel(fileBaseName: whisperModel.name)
                models.append(importedModel)
            }
        }

        allAvailableModels = models

        // Preserve current selection by name (IDs may change for dynamic models)
        if let currentName = currentModelName,
           let updatedModel = allAvailableModels.first(where: { $0.name == currentName }) {
            setDefaultTranscriptionModel(updatedModel)
        }
    }
    
    // MARK: - Default Model Selection
    
    /// Ensures there is a default transcription model selected when none
    /// has been persisted yet. Preference order:
    /// 1. Native Apple model (when available in this build/OS)
    /// 2. Preferred local Whisper model (quantized Large v3 Turbo)
    /// 3. Any other local model
    /// 4. First model in the list as a last resort
    private func selectDefaultTranscriptionModelIfNeeded() {
        guard currentTranscriptionModel == nil else { return }
        
        let models = allAvailableModels
        
        // 1. Prefer Native Apple model when the feature is actually usable
        if isNativeAppleTranscriptionAvailable(),
           let appleModel = models.first(where: { $0.provider == .nativeApple }) {
            setDefaultTranscriptionModel(appleModel)
            return
        }
        
        // 2. Prefer a good default local Whisper model
        if let localModel = preferredLocalDefaultModel(from: models) {
            setDefaultTranscriptionModel(localModel)
            return
        }
        
        // 3. Fall back to the first available model, if any
        if let firstModel = models.first {
            setDefaultTranscriptionModel(firstModel)
        }
    }
    
    /// Chooses a preferred local Whisper model to use as default when
    /// Native Apple transcription is unavailable in this build/OS.
    private func preferredLocalDefaultModel(from models: [any TranscriptionModel]) -> (any TranscriptionModel)? {
        let localModels = models.filter { $0.provider == .local }
        
        // Prefer quantized Large v3 Turbo for a good balance of
        // accuracy and download size once the user installs it.
        if let quantizedTurbo = localModels.first(where: { $0.name == "ggml-large-v3-turbo-q5_0" }) {
            return quantizedTurbo
        }
        
        // Fallback to base model if available.
        if let baseModel = localModels.first(where: { $0.name == "ggml-base" }) {
            return baseModel
        }
        
        // Otherwise, any local model we have metadata for.
        return localModels.first
    }
    
    /// Determines whether Native Apple transcription is available in this
    /// build and on the current OS. This mirrors the feature gating used
    /// in `NativeAppleTranscriptionService` so we don't select a model
    /// that can never successfully run.
    private func isNativeAppleTranscriptionAvailable() -> Bool {
        #if canImport(Speech) && ENABLE_NATIVE_SPEECH_ANALYZER
        if #available(macOS 26, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }
} 

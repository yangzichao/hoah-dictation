import Foundation
import SwiftUI
import Combine
import AppKit
import OSLog

/// Coordinates side effects when settings change
/// This class observes AppSettingsStore and triggers appropriate actions
/// such as updating system APIs, configuring services, and sending notifications
///
/// Coordinator Responsibility: Handle all side effects of settings changes.
/// Do not modify settings here - only react to changes from AppSettingsStore.
@MainActor
class SettingsCoordinator: ObservableObject {
    private let store: AppSettingsStore
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "SettingsCoordinator")
    private var cancellables = Set<AnyCancellable>()
    
    // Service references (injected via configure method)
    private weak var menuBarManager: MenuBarManager?
    private weak var hotkeyManager: HotkeyManager?
    private weak var whisperState: WhisperState?
    private weak var soundManager: SoundManager?
    private weak var mediaController: MediaController?
    private weak var playbackController: PlaybackController?
    private weak var aiEnhancementService: AIEnhancementService?
    private weak var aiService: AIService?
    private weak var localizationManager: LocalizationManager?
    
    // MARK: - Initialization
    
    /// Initializes the coordinator with the settings store
    /// - Parameter store: The AppSettingsStore to observe
    init(store: AppSettingsStore) {
        self.store = store
        setupObservers()
        logger.info("SettingsCoordinator initialized")
    }
    
    // MARK: - Configuration
    
    /// Configures the coordinator with service references
    /// Call this after all services are initialized
    /// - Parameters:
    ///   - menuBarManager: Menu bar manager instance
    ///   - hotkeyManager: Hotkey manager instance
    ///   - whisperState: Whisper state instance
    ///   - soundManager: Sound manager instance
    ///   - mediaController: Media controller instance
    ///   - playbackController: Playback controller instance
    ///   - aiEnhancementService: AI enhancement service instance
    ///   - aiService: AI service instance
    ///   - localizationManager: Localization manager instance
    func configure(
        menuBarManager: MenuBarManager,
        hotkeyManager: HotkeyManager,
        whisperState: WhisperState,
        soundManager: SoundManager,
        mediaController: MediaController,
        playbackController: PlaybackController,
        aiEnhancementService: AIEnhancementService,
        aiService: AIService,
        localizationManager: LocalizationManager
    ) {
        self.menuBarManager = menuBarManager
        self.hotkeyManager = hotkeyManager
        self.whisperState = whisperState
        self.soundManager = soundManager
        self.mediaController = mediaController
        self.playbackController = playbackController
        self.aiEnhancementService = aiEnhancementService
        self.aiService = aiService
        self.localizationManager = localizationManager
        
        logger.info("SettingsCoordinator configured with service references")
    }
    
    // MARK: - Observer Setup
    
    /// Sets up Combine observers for all settings that require side effects
    private func setupObservers() {
        // Menu Bar Only - affects app activation policy
        store.$isMenuBarOnly
            .sink { [weak self] isMenuBarOnly in
                self?.handleMenuBarOnlyChange(isMenuBarOnly)
            }
            .store(in: &cancellables)
        
        // Language - affects localization
        store.$appInterfaceLanguage
            .sink { [weak self] language in
                self?.handleLanguageChange(language)
            }
            .store(in: &cancellables)
        
        // Recorder Type - affects window switching
        store.$recorderType
            .sink { [weak self] type in
                self?.handleRecorderTypeChange(type)
            }
            .store(in: &cancellables)
        
        // Hotkeys - affects hotkey monitoring setup
        store.$selectedHotkey1
            .combineLatest(store.$selectedHotkey2, store.$isMiddleClickToggleEnabled)
            .sink { [weak self] _, _, _ in
                self?.handleHotkeyChange()
            }
            .store(in: &cancellables)
        
        // Sound feedback - no side effects needed (services read directly)
        // System mute - no side effects needed (services read directly)
        // Pause media - no side effects needed (services read directly)
        
        // AI Enhancement - affects notifications
        store.$isAIEnhancementEnabled
            .sink { [weak self] enabled in
                self?.handleAIEnhancementChange(enabled)
            }
            .store(in: &cancellables)
        
        // Selected Prompt - affects notifications
        store.$selectedPromptId
            .sink { [weak self] promptId in
                self?.handlePromptChange(promptId)
            }
            .store(in: &cancellables)
        
        // AI Provider - affects notifications
        store.$selectedAIProvider
            .sink { [weak self] provider in
                self?.handleAIProviderChange(provider)
            }
            .store(in: &cancellables)
        
        logger.debug("Observers set up for settings changes")
    }
    
    // MARK: - Side Effect Handlers
    
    /// Handles menu bar only mode change
    /// Updates NSApplication activation policy and window visibility
    /// - Parameter isMenuBarOnly: Whether menu bar only mode is enabled
    private func handleMenuBarOnlyChange(_ isMenuBarOnly: Bool) {
        logger.info("Menu bar only changed to: \(isMenuBarOnly)")
        
        let application = NSApplication.shared
        if isMenuBarOnly {
            // Hide dock icon and main window
            application.setActivationPolicy(.accessory)
            WindowManager.shared.hideMainWindow()
        } else {
            // Show dock icon and main window
            application.setActivationPolicy(.regular)
            WindowManager.shared.showMainWindow()
        }
    }
    
    /// Handles language change
    /// Applies new language and posts notification
    /// - Parameter language: New language code
    private func handleLanguageChange(_ language: String) {
        logger.info("Language changed to: \(language)")
        
        localizationManager?.apply(languageCode: language)
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    /// Handles recorder type change
    /// Switches recorder window if currently visible
    /// - Parameter type: New recorder type ("mini" or "notch")
    private func handleRecorderTypeChange(_ type: String) {
        logger.info("Recorder type changed to: \(type)")
        
        guard let whisperState = whisperState else { return }
        
        // If recorder is currently visible, need to switch windows
        if whisperState.isMiniRecorderVisible {
            // Hide current recorder
            if type == "notch" {
                whisperState.miniWindowManager?.hide()
            } else {
                whisperState.notchWindowManager?.hide()
            }
            
            // Show new recorder after brief delay
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                whisperState.showRecorderPanel()
            }
        }
    }
    
    /// Handles hotkey configuration change
    /// Triggers hotkey monitoring reconfiguration
    private func handleHotkeyChange() {
        logger.info("Hotkey configuration changed")
        
        // HotkeyManager will read from store and reconfigure
        // This is just a trigger to notify it to refresh
        // The actual reconfiguration happens in HotkeyManager
    }
    
    /// Handles AI enhancement toggle
    /// Posts notifications for UI updates
    /// - Parameter enabled: Whether AI enhancement is enabled
    private func handleAIEnhancementChange(_ enabled: Bool) {
        logger.info("AI enhancement changed to: \(enabled)")
        
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        NotificationCenter.default.post(name: .enhancementToggleChanged, object: nil)
    }
    
    /// Handles prompt selection change
    /// Posts notifications for UI updates
    /// - Parameter promptId: New prompt ID
    private func handlePromptChange(_ promptId: String?) {
        logger.info("Selected prompt changed to: \(promptId ?? "nil")")
        
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        NotificationCenter.default.post(name: .promptSelectionChanged, object: nil)
    }
    
    /// Handles AI provider change
    /// Posts notification for UI updates
    /// - Parameter provider: New provider name
    private func handleAIProviderChange(_ provider: String) {
        logger.info("AI provider changed to: \(provider)")
        
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
}

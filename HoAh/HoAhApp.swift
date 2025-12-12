import SwiftUI
import SwiftData
import AppKit
import OSLog
import AppIntents
import FluidAudio
import KeyboardShortcuts
import LaunchAtLogin

// State Management: All user settings are managed by AppSettingsStore.
// To modify settings, update AppSettingsStore properties.
// Do not use @AppStorage or direct UserDefaults access elsewhere in the app.

@main
struct HoAhApp: App {
    private static let appSupportIdentifier = "com.yangzichao.hoah"
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer
    let containerInitializationFailed: Bool
    
    // Centralized State Management
    @StateObject private var appSettings: AppSettingsStore
    @StateObject private var settingsCoordinator: SettingsCoordinator
    
    @StateObject private var whisperState: WhisperState
    @StateObject private var hotkeyManager: HotkeyManager
    @StateObject private var menuBarManager: MenuBarManager
    @StateObject private var aiService = AIService()
    @StateObject private var enhancementService: AIEnhancementService
    @StateObject private var configValidationService = ConfigurationValidationService()
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var activeWindowService = ActiveWindowService.shared
    @State private var showMenuBarIcon = true
    
    // Audio cleanup manager for automatic deletion of old audio files
    private let audioCleanupManager = AudioCleanupManager.shared
    
    // Transcription auto-cleanup service for zero data retention
    private let transcriptionAutoCleanupService = TranscriptionAutoCleanupService.shared
    
    init() {
        // Configure FluidAudio logging subsystem
        AppLogger.defaultSubsystem = "com.yangzichao.hoah.parakeet"

        // Configure KeyboardShortcuts localization
        // Note: KeyboardShortcuts.Localization may not be available in all versions
        // KeyboardShortcuts.Localization.recordShortcut = NSLocalizedString("Record Shortcut", comment: "")
        // KeyboardShortcuts.Localization.pressShortcut = NSLocalizedString("Press Shortcut", comment: "")

        if UserDefaults.standard.object(forKey: "smartScenesUIFlag") == nil {
            let hasEnabledPowerModes = SmartScenesManager.shared.configurations.contains { $0.isEnabled }
            UserDefaults.standard.set(hasEnabledPowerModes, forKey: "smartScenesUIFlag")
        }

        let logger = Logger(subsystem: "com.yangzichao.hoah", category: "Initialization")
        
        // Initialize centralized state management
        let appSettings = AppSettingsStore()
        _appSettings = StateObject(wrappedValue: appSettings)
        
        let settingsCoordinator = SettingsCoordinator(store: appSettings)
        _settingsCoordinator = StateObject(wrappedValue: settingsCoordinator)
        
        let schema = Schema([Transcription.self])
        var initializationFailed = false
        
        // Attempt 1: Try persistent storage
        if let persistentContainer = Self.createPersistentContainer(schema: schema, logger: logger) {
            container = persistentContainer
            
            #if DEBUG
            // Print SwiftData storage location in debug builds only
            if let url = persistentContainer.mainContext.container.configurations.first?.url {
                print("💾 SwiftData storage location: \(url.path)")
            }
            #endif
        }
        // Attempt 2: Try in-memory storage
        else if let memoryContainer = Self.createInMemoryContainer(schema: schema, logger: logger) {
            container = memoryContainer
            
            logger.warning("Using in-memory storage as fallback. Data will not persist between sessions.")
            
            // Show alert to user about storage issue
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Storage Warning"
                alert.informativeText = "HoAh couldn't access its storage location. Your transcriptions will not be saved between sessions."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        // Attempt 3: Try ultra-minimal default container
        else if let minimalContainer = Self.createMinimalContainer(schema: schema, logger: logger) {
            container = minimalContainer
            logger.warning("Using minimal emergency container")
        }
        // All attempts failed: Create disabled container and mark for termination
        else {
            logger.critical("All ModelContainer initialization attempts failed")
            initializationFailed = true
            
            // Create a dummy container to satisfy Swift's initialization requirements
            // App will show error and terminate in onAppear
            container = Self.createDummyContainer(schema: schema)
        }
        
        containerInitializationFailed = initializationFailed
        
        // Initialize services with proper sharing of instances
        let aiService = AIService()
        _aiService = StateObject(wrappedValue: aiService)
        
        let enhancementService = AIEnhancementService(aiService: aiService, modelContext: container.mainContext)
        _enhancementService = StateObject(wrappedValue: enhancementService)
        
        let whisperState = WhisperState(modelContext: container.mainContext, enhancementService: enhancementService)
        whisperState.appSettings = appSettings
        // Reconfigure SmartSceneSessionManager with appSettings now that it's available
        SmartSceneSessionManager.shared.configure(whisperState: whisperState, enhancementService: enhancementService, appSettings: appSettings)
        _whisperState = StateObject(wrappedValue: whisperState)
        
        let hotkeyManager = HotkeyManager(whisperState: whisperState, appSettings: appSettings)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)
        
        let menuBarManager = MenuBarManager()
        _menuBarManager = StateObject(wrappedValue: menuBarManager)
        appDelegate.menuBarManager = menuBarManager
        appDelegate.appSettings = appSettings
        
        let activeWindowService = ActiveWindowService.shared
        activeWindowService.configure(with: enhancementService)
        activeWindowService.configureWhisperState(whisperState)
        _activeWindowService = StateObject(wrappedValue: activeWindowService)
        
        // Ensure no lingering recording state from previous runs
        Task {
            await whisperState.resetOnLaunch()
        }
        
        
        AppShortcuts.updateAppShortcutParameters()

        // Enable Launch at Login by default on first install
        if !UserDefaults.standard.bool(forKey: "HasConfiguredLaunchAtLogin") {
            LaunchAtLogin.isEnabled = true
            UserDefaults.standard.set(true, forKey: "HasConfiguredLaunchAtLogin")
        }
    }
    
    // MARK: - Container Creation Helpers
    
    private static func createPersistentContainer(schema: Schema, logger: Logger) -> ModelContainer? {
        do {
            // Create app-specific Application Support directory URL
            let baseSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let appSupportURL = Self.prepareAppSupportDirectory(baseDirectory: baseSupportDirectory, logger: logger)
            
            // Configure SwiftData to use the conventional location
            let storeURL = appSupportURL.appendingPathComponent("default.store")
            let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
            
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            logger.error("Failed to create persistent ModelContainer: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func createInMemoryContainer(schema: Schema, logger: Logger) -> ModelContainer? {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("Failed to create in-memory ModelContainer: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func createMinimalContainer(schema: Schema, logger: Logger) -> ModelContainer? {
        do {
            // Try default initializer without custom configuration
            return try ModelContainer(for: schema)
        } catch {
            logger.error("Failed to create minimal ModelContainer: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func prepareAppSupportDirectory(baseDirectory: URL, logger: Logger) -> URL {
        let fileManager = FileManager.default
        let appSupportURL = baseDirectory.appendingPathComponent(appSupportIdentifier, isDirectory: true)
        
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            do {
                try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
                logger.notice("Created HoAh app support directory: \(appSupportURL.path)")
            } catch {
                logger.error("Failed to create HoAh app support directory: \(error.localizedDescription)")
            }
        }
        
        return appSupportURL
    }
    
    private static func createDummyContainer(schema: Schema) -> ModelContainer {
        // Create an absolute minimal container for initialization
        // This uses in-memory storage and will never actually be used
        // as the app will show an error and terminate in onAppear
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        // Note: In-memory containers should always succeed unless SwiftData itself is unavailable
        // (which would indicate a serious system-level issue). We use preconditionFailure here
        // rather than fatalError because:
        // 1. This code is only reached after 3 prior initialization attempts have failed
        // 2. An in-memory container failing indicates SwiftData is completely unavailable
        // 3. Swift requires non-optional container property to be initialized
        // 4. The app will immediately terminate in onAppear when containerInitializationFailed is checked
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // This indicates a system-level SwiftData failure - app cannot function
            preconditionFailure("Unable to create even a dummy ModelContainer. SwiftData is unavailable: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                
                if !appSettings.hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $appSettings.hasCompletedOnboarding)
                        .transition(.opacity)
                }
            }
            .environmentObject(appSettings)
            .environmentObject(settingsCoordinator)
            .environmentObject(whisperState)
            .environmentObject(hotkeyManager)
            .environmentObject(menuBarManager)
            .environmentObject(aiService)
            .environmentObject(enhancementService)
            .environmentObject(configValidationService)
            .environmentObject(localizationManager)
            .environment(\.locale, localizationManager.locale)
            .modelContainer(container)
            .onAppear {
                // Configure audio services with centralized settings
                SoundManager.shared.configure(with: appSettings)
                MediaController.shared.configure(with: appSettings)
                PlaybackController.shared.configure(with: appSettings)
                
                // Configure AI services with centralized settings
                aiService.configure(with: appSettings)
                enhancementService.configure(with: appSettings)
                configValidationService.configure(with: appSettings, aiService: aiService)
                
                // Configure coordinator with service references
                settingsCoordinator.configure(
                    menuBarManager: menuBarManager,
                    hotkeyManager: hotkeyManager,
                    whisperState: whisperState,
                    soundManager: SoundManager.shared,
                    mediaController: MediaController.shared,
                    playbackController: PlaybackController.shared,
                    aiEnhancementService: enhancementService,
                    aiService: aiService,
                    localizationManager: localizationManager
                )
                
                localizationManager.apply(languageCode: appSettings.appInterfaceLanguage)

                // Check if container initialization failed
                if containerInitializationFailed {
                    let alert = NSAlert()
                    alert.messageText = "Critical Storage Error"
                    alert.informativeText = "HoAh cannot initialize its storage system. The app cannot continue.\n\nPlease try reinstalling the app or contact support if the issue persists."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "Quit")
                    alert.runModal()
                    
                    NSApplication.shared.terminate(nil)
                    return
                }
                // Start the transcription auto-cleanup service (handles immediate and scheduled transcript deletion)
                transcriptionAutoCleanupService.startMonitoring(modelContext: container.mainContext)
                
                // Start the automatic audio cleanup process only if transcript cleanup is not enabled
                if !UserDefaults.standard.bool(forKey: "IsTranscriptionCleanupEnabled") {
                    audioCleanupManager.startAutomaticCleanup(modelContext: container.mainContext)
                }
                
                // Process any pending open-file request now that the main ContentView is ready.
                if let pendingURL = appDelegate.pendingOpenFileURL {
                    NotificationCenter.default.post(name: .navigateToDestination, object: nil, userInfo: ["destination": "Transcribe Audio"])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .openFileForTranscription, object: nil, userInfo: ["url": pendingURL])
                    }
                    appDelegate.pendingOpenFileURL = nil
                }
            }
            .background(WindowAccessor { window in
                WindowManager.shared.configureWindow(window)
            })
            .onDisappear {
                whisperState.unloadModel()
                
                // Stop the transcription auto-cleanup service
                transcriptionAutoCleanupService.stopMonitoring()
                
                // Stop the automatic audio cleanup process
                audioCleanupManager.stopAutomaticCleanup()
            }
            .onChange(of: appSettings.appInterfaceLanguage) { _, newValue in
                localizationManager.apply(languageCode: newValue)
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandGroup(after: .appInfo) {
                Button {
                    appDelegate.checkForUpdates(nil)
                } label: {
                    Text(LocalizedStringKey("menu_check_for_updates"))
                }
            }
        }
        
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environmentObject(appSettings)
                .environmentObject(whisperState)
                .environmentObject(hotkeyManager)
                .environmentObject(menuBarManager)
                .environmentObject(aiService)
                .environmentObject(enhancementService)
                .environmentObject(configValidationService)
                .environment(\.locale, localizationManager.locale)
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 22
                $0.size.width = 22 / ratio
                return $0
            }(NSImage(named: "menuBarIcon")!)

            Image(nsImage: image)
        }
        .menuBarExtraStyle(.menu)
        
        #if DEBUG
        WindowGroup("Debug") {
            Button("Toggle Menu Bar Only") {
                appSettings.isMenuBarOnly.toggle()
            }
        }
        #endif
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

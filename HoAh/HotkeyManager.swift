import Foundation
import KeyboardShortcuts
import Carbon
import AppKit
import Combine

extension KeyboardShortcuts.Name {
    static let toggleMiniRecorder = Self("toggleMiniRecorder")
    static let toggleMiniRecorder2 = Self("toggleMiniRecorder2")
    static let pasteLastTranscription = Self("pasteLastTranscription")
    static let pasteLastEnhancement = Self("pasteLastEnhancement")
    static let retryLastTranscription = Self("retryLastTranscription")
}

// Hotkey configuration is managed by AppSettingsStore. Read settings from appSettings parameter.
@MainActor
class HotkeyManager: ObservableObject {
    // MARK: - Computed Properties (read from AppSettingsStore)
    
    /// Primary hotkey option - reads from AppSettingsStore
    var selectedHotkey1: HotkeyOption {
        get { HotkeyOption(rawValue: appSettings.selectedHotkey1) ?? .rightOption }
        set { appSettings.selectedHotkey1 = newValue.rawValue }
    }
    
    /// Secondary hotkey option - reads from AppSettingsStore
    var selectedHotkey2: HotkeyOption {
        get { HotkeyOption(rawValue: appSettings.selectedHotkey2) ?? .none }
        set { 
            if newValue == .none {
                KeyboardShortcuts.setShortcut(nil, for: .toggleMiniRecorder2)
            }
            appSettings.selectedHotkey2 = newValue.rawValue 
        }
    }
    
    /// Whether middle-click toggle is enabled - reads from AppSettingsStore
    var isMiddleClickToggleEnabled: Bool {
        get { appSettings.isMiddleClickToggleEnabled }
        set { appSettings.isMiddleClickToggleEnabled = newValue }
    }
    
    /// Middle-click activation delay - reads from AppSettingsStore
    var middleClickActivationDelay: Int {
        get { appSettings.middleClickActivationDelay }
        set { appSettings.middleClickActivationDelay = newValue }
    }
    
    // MARK: - Dependencies
    private var whisperState: WhisperState
    private var appSettings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var miniRecorderShortcutManager: MiniRecorderShortcutManager
    
    // MARK: - Helper Properties
    private var canProcessHotkeyAction: Bool {
        whisperState.recordingState != .transcribing && whisperState.recordingState != .enhancing && whisperState.recordingState != .busy
    }
    
    // NSEvent monitoring for modifier keys
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    // Middle-click event monitoring
    private var middleClickMonitors: [Any?] = []
    private var middleClickTask: Task<Void, Never>?
    
    // Key state tracking
    private var currentKeyState = false
    private var keyPressStartTime: Date?
    private let briefPressThreshold = 1.7
    private var isHandsFreeMode = false
    
    // Debounce for Fn key
    private var fnDebounceTask: Task<Void, Never>?
    private var pendingFnKeyState: Bool? = nil
    
    // Keyboard shortcut state tracking
    private var shortcutKeyPressStartTime: Date?
    private var isShortcutHandsFreeMode = false
    private var shortcutCurrentKeyState = false
    private var lastShortcutTriggerTime: Date?
    private let shortcutCooldownInterval: TimeInterval = 0.5
    
    enum HotkeyOption: String, CaseIterable {
        case none = "none"
        case rightOption = "rightOption"
        case leftOption = "leftOption"
        case leftControl = "leftControl" 
        case rightControl = "rightControl"
        case fn = "fn"
        case rightCommand = "rightCommand"
        case rightShift = "rightShift"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .none: return NSLocalizedString("None", comment: "")
            case .rightOption: return NSLocalizedString("Right Option (⌥)", comment: "")
            case .leftOption: return NSLocalizedString("Left Option (⌥)", comment: "")
            case .leftControl: return NSLocalizedString("Left Control (⌃)", comment: "")
            case .rightControl: return NSLocalizedString("Right Control (⌃)", comment: "")
            case .fn: return NSLocalizedString("Fn", comment: "")
            case .rightCommand: return NSLocalizedString("Right Command (⌘)", comment: "")
            case .rightShift: return NSLocalizedString("Right Shift (⇧)", comment: "")
            case .custom: return NSLocalizedString("Custom", comment: "")
            }
        }
        
        var keyCode: CGKeyCode? {
            switch self {
            case .rightOption: return 0x3D
            case .leftOption: return 0x3A
            case .leftControl: return 0x3B
            case .rightControl: return 0x3E
            case .fn: return 0x3F
            case .rightCommand: return 0x36
            case .rightShift: return 0x3C
            case .custom, .none: return nil
            }
        }
        
        var isModifierKey: Bool {
            return self != .custom && self != .none
        }
    }
    
    init(whisperState: WhisperState, appSettings: AppSettingsStore) {
        self.whisperState = whisperState
        self.appSettings = appSettings
        self.miniRecorderShortcutManager = MiniRecorderShortcutManager(whisperState: whisperState)

        KeyboardShortcuts.onKeyUp(for: .pasteLastTranscription) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                LastTranscriptionService.pasteLastTranscription(from: self.whisperState.modelContext)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .pasteLastEnhancement) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                LastTranscriptionService.pasteLastEnhancement(from: self.whisperState.modelContext)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .retryLastTranscription) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                LastTranscriptionService.retryLastTranscription(from: self.whisperState.modelContext, whisperState: self.whisperState)
            }
        }
        
        // Subscribe to hotkey settings changes from AppSettingsStore
        setupSettingsObservers()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            self.setupHotkeyMonitoring()
        }
    }
    
    // MARK: - Settings Observers
    
    private func setupSettingsObservers() {
        // Observe hotkey1 changes
        appSettings.$selectedHotkey1
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.setupHotkeyMonitoring()
            }
            .store(in: &cancellables)
        
        // Observe hotkey2 changes
        appSettings.$selectedHotkey2
            .dropFirst()
            .sink { [weak self] newValue in
                self?.objectWillChange.send()
                if newValue == "none" {
                    KeyboardShortcuts.setShortcut(nil, for: .toggleMiniRecorder2)
                }
                self?.setupHotkeyMonitoring()
            }
            .store(in: &cancellables)
        
        // Observe middle-click toggle changes
        appSettings.$isMiddleClickToggleEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.setupHotkeyMonitoring()
            }
            .store(in: &cancellables)
        
        // Observe middle-click delay changes
        appSettings.$middleClickActivationDelay
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupHotkeyMonitoring() {
        removeAllMonitoring()
        
        setupModifierKeyMonitoring()
        setupCustomShortcutMonitoring()
        setupMiddleClickMonitoring()
    }
    
    private func setupModifierKeyMonitoring() {
        // Only set up if at least one hotkey is a modifier key
        guard (selectedHotkey1.isModifierKey && selectedHotkey1 != .none) || (selectedHotkey2.isModifierKey && selectedHotkey2 != .none) else { return }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handleModifierKeyEvent(event)
            }
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            Task { @MainActor in
                await self.handleModifierKeyEvent(event)
            }
            return event
        }
    }
    
    private func setupMiddleClickMonitoring() {
        guard isMiddleClickToggleEnabled else { return }

        // Mouse Down
        let downMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self = self, event.buttonNumber == 2 else { return }

            self.middleClickTask?.cancel()
            self.middleClickTask = Task {
                do {
                    let delay = UInt64(self.middleClickActivationDelay) * 1_000_000 // ms to ns
                    try await Task.sleep(nanoseconds: delay)
                    
                    guard self.isMiddleClickToggleEnabled, !Task.isCancelled else { return }
                    
                    Task { @MainActor in
                        guard self.canProcessHotkeyAction else { return }
                        await self.whisperState.handleToggleMiniRecorder()
                    }
                } catch {
                    // Cancelled
                }
            }
        }

        // Mouse Up
        let upMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseUp) { [weak self] event in
            guard let self = self, event.buttonNumber == 2 else { return }
            self.middleClickTask?.cancel()
        }

        middleClickMonitors = [downMonitor, upMonitor]
    }
    
    private func setupCustomShortcutMonitoring() {
        // Hotkey 1
        if selectedHotkey1 == .custom {
            KeyboardShortcuts.onKeyDown(for: .toggleMiniRecorder) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyDown() }
            }
            KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorder) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyUp() }
            }
        }
        // Hotkey 2
        if selectedHotkey2 == .custom {
            KeyboardShortcuts.onKeyDown(for: .toggleMiniRecorder2) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyDown() }
            }
            KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorder2) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyUp() }
            }
        }
    }
    
    private func removeAllMonitoring() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        for monitor in middleClickMonitors {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        middleClickMonitors = []
        middleClickTask?.cancel()
        
        resetKeyStates()
    }
    
    private func resetKeyStates() {
        currentKeyState = false
        keyPressStartTime = nil
        isHandsFreeMode = false
        shortcutCurrentKeyState = false
        shortcutKeyPressStartTime = nil
        isShortcutHandsFreeMode = false
    }
    
    private func handleModifierKeyEvent(_ event: NSEvent) async {
        let keycode = event.keyCode
        let flags = event.modifierFlags
        
        // Determine which hotkey (if any) is being triggered
        let activeHotkey: HotkeyOption?
        if selectedHotkey1.isModifierKey && selectedHotkey1.keyCode == keycode {
            activeHotkey = selectedHotkey1
        } else if selectedHotkey2.isModifierKey && selectedHotkey2.keyCode == keycode {
            activeHotkey = selectedHotkey2
        } else {
            activeHotkey = nil
        }
        
        guard let hotkey = activeHotkey else { return }
        
        var isKeyPressed = false
        
        switch hotkey {
        case .rightOption, .leftOption:
            isKeyPressed = flags.contains(.option)
        case .leftControl, .rightControl:
            isKeyPressed = flags.contains(.control)
        case .fn:
            isKeyPressed = flags.contains(.function)
            // Debounce Fn key
            pendingFnKeyState = isKeyPressed
            fnDebounceTask?.cancel()
            fnDebounceTask = Task { [pendingState = isKeyPressed] in
                try? await Task.sleep(nanoseconds: 75_000_000) // 75ms
                if pendingFnKeyState == pendingState {
                    await self.processKeyPress(isKeyPressed: pendingState)
                }
            }
            return
        case .rightCommand:
            isKeyPressed = flags.contains(.command)
        case .rightShift:
            isKeyPressed = flags.contains(.shift)
        case .custom, .none:
            return // Should not reach here
        }

        await processKeyPress(isKeyPressed: isKeyPressed)
    }
    
    private func processKeyPress(isKeyPressed: Bool) async {
        guard isKeyPressed != currentKeyState else { return }
        currentKeyState = isKeyPressed

        if isKeyPressed {
            keyPressStartTime = Date()

            if isHandsFreeMode {
                isHandsFreeMode = false
                guard canProcessHotkeyAction else { return }
                await whisperState.handleToggleMiniRecorder()
                return
            }

            if !whisperState.isMiniRecorderVisible {
                guard canProcessHotkeyAction else { return }
                await whisperState.handleToggleMiniRecorder()
            }
        } else {
            let now = Date()

            if let startTime = keyPressStartTime {
                let pressDuration = now.timeIntervalSince(startTime)

                if pressDuration < briefPressThreshold {
                    isHandsFreeMode = true
                } else {
                    guard canProcessHotkeyAction else { return }
                    await whisperState.handleToggleMiniRecorder()
                }
            }

            keyPressStartTime = nil
        }
    }
    
    private func handleCustomShortcutKeyDown() async {
        if let lastTrigger = lastShortcutTriggerTime,
           Date().timeIntervalSince(lastTrigger) < shortcutCooldownInterval {
            return
        }
        
        guard !shortcutCurrentKeyState else { return }
        shortcutCurrentKeyState = true
        lastShortcutTriggerTime = Date()
        shortcutKeyPressStartTime = Date()
        
        if isShortcutHandsFreeMode {
            isShortcutHandsFreeMode = false
            guard canProcessHotkeyAction else { return }
            await whisperState.handleToggleMiniRecorder()
            return
        }
        
        if !whisperState.isMiniRecorderVisible {
            guard canProcessHotkeyAction else { return }
            await whisperState.handleToggleMiniRecorder()
        }
    }
    
    private func handleCustomShortcutKeyUp() async {
        guard shortcutCurrentKeyState else { return }
        shortcutCurrentKeyState = false
        
        let now = Date()
        
        if let startTime = shortcutKeyPressStartTime {
            let pressDuration = now.timeIntervalSince(startTime)
            
            if pressDuration < briefPressThreshold {
                isShortcutHandsFreeMode = true
            } else {
                guard canProcessHotkeyAction else { return }
                await whisperState.handleToggleMiniRecorder()
            }
        }
        
        shortcutKeyPressStartTime = nil
    }
    
    // Computed property for backward compatibility with UI
    var isShortcutConfigured: Bool {
        let isHotkey1Configured = (selectedHotkey1 == .custom) ? (KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil) : true
        let isHotkey2Configured = (selectedHotkey2 == .custom) ? (KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder2) != nil) : true
        return isHotkey1Configured && isHotkey2Configured
    }
    
    func updateShortcutStatus() {
        // Called when a custom shortcut changes
        if selectedHotkey1 == .custom || selectedHotkey2 == .custom {
            setupHotkeyMonitoring()
        }
    }
    
    deinit {
        Task { @MainActor in
            removeAllMonitoring()
        }
    }
}

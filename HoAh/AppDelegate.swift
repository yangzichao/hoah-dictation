import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    weak var menuBarManager: MenuBarManager?
    weak var appSettings: AppSettingsStore?
    
    private lazy var updaterControllerString: SPUStandardUpdaterController = {
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()
    
    private var updaterController: SPUStandardUpdaterController {
        return updaterControllerString
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activation policy is now handled by SettingsCoordinator
        performAutomaticUpdateCheck()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let appSettings = appSettings, !appSettings.isMenuBarOnly {
            if WindowManager.shared.showMainWindow() != nil {
                return false
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }
    
    private func performAutomaticUpdateCheck() {
        // One-time check on launch; do not enable periodic background checks.
        let updater = updaterController.updater
        updater.automaticallyChecksForUpdates = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.updaterController.updater.checkForUpdatesInBackground()
        }
    }

    // Stash URL when app cold-starts to avoid spawning a new window/tab
    var pendingOpenFileURL: URL?
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { SupportedMedia.isSupported(url: $0) }) else {
            return
        }
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        if WindowManager.shared.currentMainWindow() == nil {
            // Cold start: do NOT create a window here to avoid extra window/tab.
            // Defer to SwiftUI’s WindowGroup-created ContentView and let it process this later.
            pendingOpenFileURL = url
        } else {
            // Running: focus current window and route in-place to Transcribe Audio
            menuBarManager?.focusMainWindow()
            NotificationCenter.default.post(name: .navigateToDestination, object: nil, userInfo: ["destination": "Transcribe Audio"])
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openFileForTranscription, object: nil, userInfo: ["url": url])
            }
        }
    }
    
    // MARK: - SPUUpdaterDelegate
    
    // Delegate methods removed to avoid duplicate alerts.
    // SPUStandardUpdaterController handles UI including "No Update Found" and errors automatically.
}

import SwiftUI
import AppKit

// Menu bar mode is managed by AppSettingsStore
class MenuBarManager: ObservableObject {
    // isMenuBarOnly has been moved to AppSettingsStore
    // This class now only handles the side effects of menu bar mode changes
    
    init() {
        // Initialization logic moved to SettingsCoordinator
    }
    
    func applyActivationPolicy(isMenuBarOnly: Bool) {
        updateAppActivationPolicy(isMenuBarOnly: isMenuBarOnly)
    }
    
    func focusMainWindow() {
        DispatchQueue.main.async {
            if WindowManager.shared.showMainWindow() == nil {
                print("MenuBarManager: Unable to locate main window to focus")
            }
        }
    }
    
    func updateAppActivationPolicy(isMenuBarOnly: Bool) {
        let applyPolicy = {
            let application = NSApplication.shared
            if isMenuBarOnly {
                application.setActivationPolicy(.accessory)
                WindowManager.shared.hideMainWindow()
            } else {
                application.setActivationPolicy(.regular)
                _ = WindowManager.shared.showMainWindow()
            }
        }

        if Thread.isMainThread {
            applyPolicy()
        } else {
            DispatchQueue.main.async(execute: applyPolicy)
        }
    }
    
    func openMainWindowAndNavigate(to destination: String) {
        print("MenuBarManager: Navigating to \(destination)")
        
        DispatchQueue.main.async {
            guard WindowManager.shared.showMainWindow() != nil else {
                print("MenuBarManager: Unable to show main window for navigation")
                return
            }
            
            // Post a notification to navigate to the desired destination
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: .navigateToDestination,
                    object: nil,
                    userInfo: ["destination": destination]
                )
                print("MenuBarManager: Posted navigation notification for \(destination)")
            }
        }
    }
}

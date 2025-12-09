# State Management Architecture

This document describes the centralized state management system for HoAh.

## Overview

All user-configurable settings are managed through a centralized `AppSettingsStore`. This provides:
- Single source of truth for all settings
- Automatic persistence to UserDefaults
- Type-safe access to settings
- Combine-based change notifications
- Smart Scene session support

## Core Components

### AppSettingsStore

The central store for all application settings. Located at `StateManagement/AppSettingsStore.swift`.

**Usage:**
```swift
// Reading settings
let isEnabled = appSettings.isAIEnhancementEnabled

// Writing settings
appSettings.isAIEnhancementEnabled = true

// Batch updates
appSettings.updateAISettings(enabled: true, promptId: "...")
```

### SettingsCoordinator

Handles side effects when settings change. Located at `StateManagement/SettingsCoordinator.swift`.

The coordinator:
- Observes all settings changes via Combine
- Triggers appropriate side effects (e.g., updating hotkey bindings)
- Does NOT modify settings - only reacts to changes

### SettingsStorage

Protocol for settings persistence. Located at `StateManagement/SettingsStorage.swift`.

Default implementation: `UserDefaultsStorage` with legacy migration support.

## Adding New Settings

1. Add the property to `AppSettingsState` struct
2. Add the `@Published` property to `AppSettingsStore`
3. Update `currentState()` and `applyState()` methods
4. Add validation if needed
5. If side effects are required, add observer in `SettingsCoordinator`

## Service Integration

Services should:
1. Accept `AppSettingsStore` via a `configure(with:)` method
2. Use computed properties to read from `appSettings`
3. Subscribe to changes via Combine for UI updates

**Example:**
```swift
class MyService: ObservableObject {
    private weak var appSettings: AppSettingsStore?
    private var cancellables = Set<AnyCancellable>()
    
    var mySetting: Bool {
        appSettings?.mySetting ?? false
    }
    
    func configure(with appSettings: AppSettingsStore) {
        self.appSettings = appSettings
        appSettings.$mySetting
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
```

## Smart Scene Support

Smart Scenes can temporarily override settings without modifying user preferences:

```swift
// Begin session
appSettings.beginSmartSceneSession(sceneId: "scene-id")

// End session (restores user settings)
appSettings.endSmartSceneSession()

// Check if override is active
if appSettings.isSmartSceneOverrideActive {
    // Use effectiveAIEnhancementEnabled instead of isAIEnhancementEnabled
}
```

## Best Practices

1. **Never use `@AppStorage` or direct `UserDefaults` access** for migrated settings
2. **Always inject `AppSettingsStore`** via environment or configure method
3. **Use computed properties** in services to read from `appSettings`
4. **Subscribe to changes** via Combine for reactive UI updates
5. **Add `@MainActor`** to services that interact with `AppSettingsStore`

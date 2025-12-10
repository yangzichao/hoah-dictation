import Foundation

struct CloudAPIKeyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var value: String
    var lastUsedAt: Date?
    
    init(id: UUID = UUID(), value: String, lastUsedAt: Date? = nil) {
        self.id = id
        self.value = value
        self.lastUsedAt = lastUsedAt
    }
}

final class CloudAPIKeyManager {
    static let shared = CloudAPIKeyManager()
    
    private let userDefaults = UserDefaults.standard
    private let keysStorageKey = "CloudAPIKeysByProvider"
    private let activeIdsStorageKey = "CloudActiveAPIKeyIdsByProvider"
    
    private var keysByProvider: [String: [CloudAPIKeyEntry]]
    private var activeIdByProvider: [String: UUID]
    
    private init() {
        if let data = userDefaults.data(forKey: keysStorageKey),
           let decoded = try? JSONDecoder().decode([String: [CloudAPIKeyEntry]].self, from: data) {
            keysByProvider = decoded
        } else {
            keysByProvider = [:]
        }
        
        if let stored = userDefaults.dictionary(forKey: activeIdsStorageKey) as? [String: String] {
            var result: [String: UUID] = [:]
            for (providerKey, idString) in stored {
                if let uuid = UUID(uuidString: idString) {
                    result[providerKey] = uuid
                }
            }
            activeIdByProvider = result
        } else {
            activeIdByProvider = [:]
        }
        
        migrateLegacySingleKeysIfNeeded()
    }
    
    // MARK: - Public API
    
    func keys(for providerKey: String) -> [CloudAPIKeyEntry] {
        keysByProvider[providerKey] ?? []
    }
    
    func hasKeys(for providerKey: String) -> Bool {
        !(keysByProvider[providerKey] ?? []).isEmpty
    }
    
    func activeKey(for providerKey: String) -> CloudAPIKeyEntry? {
        let keys = keysByProvider[providerKey] ?? []
        guard !keys.isEmpty else { return nil }
        
        if let activeId = activeIdByProvider[providerKey],
           let entry = keys.first(where: { $0.id == activeId }) {
            return entry
        }
        return keys.first
    }
    
    func activeKeyId(for providerKey: String) -> UUID? {
        activeKey(for: providerKey)?.id
    }
    
    @discardableResult
    func addKey(_ value: String, for providerKey: String) -> CloudAPIKeyEntry {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var keys = keysByProvider[providerKey] ?? []
        
        if let existing = keys.first(where: { $0.value == trimmed }) {
            activeIdByProvider[providerKey] = existing.id
            persist(for: providerKey)
            return existing
        }
        
        let entry = CloudAPIKeyEntry(value: trimmed)
        keys.append(entry)
        keysByProvider[providerKey] = keys
        activeIdByProvider[providerKey] = entry.id
        
        persist(for: providerKey)
        return entry
    }
    
    func selectKey(id: UUID, for providerKey: String) {
        guard let keys = keysByProvider[providerKey],
              keys.contains(where: { $0.id == id }) else { return }
        activeIdByProvider[providerKey] = id
        persist(for: providerKey)
    }
    
    @discardableResult
    func rotateKey(for providerKey: String) -> Bool {
        guard let keys = keysByProvider[providerKey], !keys.isEmpty else { return false }
        
        if keys.count == 1 {
            // Only one key, nothing to rotate but treat as success so caller does not fail prematurely
            if let current = activeKey(for: providerKey) {
                activeIdByProvider[providerKey] = current.id
                persist(for: providerKey)
                return true
            }
            return false
        }
        
        let currentId = activeIdByProvider[providerKey]
        let currentIndex = keys.firstIndex(where: { $0.id == currentId }) ?? 0
        let nextIndex = (currentIndex + 1) % keys.count
        let next = keys[nextIndex]
        activeIdByProvider[providerKey] = next.id
        persist(for: providerKey)
        return true
    }
    
    func markCurrentKeyUsed(for providerKey: String) {
        guard var keys = keysByProvider[providerKey],
              !keys.isEmpty else { return }
        
        let now = Date()
        if let activeId = activeIdByProvider[providerKey],
           let index = keys.firstIndex(where: { $0.id == activeId }) {
            keys[index].lastUsedAt = now
            keysByProvider[providerKey] = keys
        } else {
            keys[0].lastUsedAt = now
            keysByProvider[providerKey] = keys
            activeIdByProvider[providerKey] = keys[0].id
        }
        persist(for: providerKey)
    }
    
    func removeKey(id: UUID, for providerKey: String) {
        guard var keys = keysByProvider[providerKey] else { return }
        keys.removeAll { $0.id == id }
        keysByProvider[providerKey] = keys
        
        if keys.isEmpty {
            activeIdByProvider[providerKey] = nil
        } else if activeIdByProvider[providerKey] == id {
            activeIdByProvider[providerKey] = keys[0].id
        }
        
        persist(for: providerKey)
    }
    
    func removeAllKeys(for providerKey: String) {
        keysByProvider[providerKey] = []
        activeIdByProvider[providerKey] = nil
        persist(for: providerKey)
    }
    
    // MARK: - Persistence and migration
    
    private func persist(for providerKey: String) {
        // Keep legacy single-key entry in sync for compatibility
        if let active = activeKey(for: providerKey) {
            userDefaults.set(active.value, forKey: "\(providerKey)APIKey")
        } else {
            userDefaults.removeObject(forKey: "\(providerKey)APIKey")
        }
        
        if let data = try? JSONEncoder().encode(keysByProvider) {
            userDefaults.set(data, forKey: keysStorageKey)
        }
        
        var storedIds: [String: String] = [:]
        for (provider, id) in activeIdByProvider {
            storedIds[provider] = id.uuidString
        }
        userDefaults.set(storedIds, forKey: activeIdsStorageKey)
    }
    
    private func migrateLegacySingleKeysIfNeeded() {
        let legacyProviders = [
            "GROQ",
            "ElevenLabs",
            "Gemini",
            "Anthropic",
            "OpenAI",
            "OpenRouter",
            "Cerebras",
            "AWS Bedrock"
        ]
        var didMigrate = false
        
        for providerKey in legacyProviders {
            guard (keysByProvider[providerKey] ?? []).isEmpty else { continue }
            
            if let legacy = userDefaults.string(forKey: "\(providerKey)APIKey"),
               !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let entry = CloudAPIKeyEntry(value: legacy)
                keysByProvider[providerKey] = [entry]
                activeIdByProvider[providerKey] = entry.id
                didMigrate = true
            }
        }
        
        if didMigrate {
            if let data = try? JSONEncoder().encode(keysByProvider) {
                userDefaults.set(data, forKey: keysStorageKey)
            }
            
            var storedIds: [String: String] = [:]
            for (provider, id) in activeIdByProvider {
                storedIds[provider] = id.uuidString
            }
            userDefaults.set(storedIds, forKey: activeIdsStorageKey)
        }
    }
}

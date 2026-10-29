import Foundation
import Security

public enum KeychainHelper {
    private static let service = "io.github.habar.menubar"
    private static let tokenAccount = "ha_long_lived_token"
    private static let serverURLKey = "habar_ha_server_url"
    private static let tokenDefaultsKey = "habar_ha_token_backup"
    private static let useDemoModeKey = "habar_ha_demo_mode"

    private static var configFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/habar/config.json")
    }

    public static var serverURLString: String {
        get {
            if let fileCfg = readConfigFile(),
               let url = fileCfg["server_url"] as? String,
               !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return url.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let saved = UserDefaults.standard.string(forKey: serverURLKey) ?? ""
            return saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "http://homeassistant.local:8123"
                : saved
        }
        set {
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(clean, forKey: serverURLKey)
            writeConfigFile(serverURL: clean, token: loadToken())
        }
    }

    public static var fallbackURLString: String? {
        guard let fileCfg = readConfigFile(),
              let fallback = fileCfg["fallback_url"] as? String,
              !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static var ignoredEntitySuffixes: [String] {
        if let fileCfg = readConfigFile(),
           let suffixes = fileCfg["ignored_entity_suffixes"] as? [String],
           !suffixes.isEmpty {
            return suffixes
        }
        return ["_nao_perturbe", "_dnd"]
    }

    public static var stripScenePrefixes: [String] {
        if let fileCfg = readConfigFile(),
           let prefixes = fileCfg["strip_scene_prefixes"] as? [String] {
            return prefixes
        }
        return []
    }

    public static var isDemoModePreferred: Bool {
        get {
            if UserDefaults.standard.object(forKey: useDemoModeKey) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: useDemoModeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useDemoModeKey)
        }
    }

    public static func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: tokenDefaultsKey)
        writeConfigFile(serverURL: serverURLString, token: trimmed)

        guard let data = trimmed.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)

        guard !trimmed.isEmpty else { return }
        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insertQuery as CFDictionary, nil)
    }

    public static func loadToken() -> String {
        if let fileCfg = readConfigFile(),
           let fileToken = fileCfg["token"] as? String,
           !fileToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fileToken.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let defaultsToken = UserDefaults.standard.string(forKey: tokenDefaultsKey),
           !defaultsToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return defaultsToken.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return ""
        }
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readConfigFile() -> [String: Any]? {
        guard let data = try? Data(contentsOf: configFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func writeConfigFile(serverURL: String, token: String) {
        let dir = configFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var payload = readConfigFile() ?? [:]
        payload["server_url"] = serverURL
        payload["token"] = token
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? data.write(to: configFileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFileURL.path)
        }
    }
}

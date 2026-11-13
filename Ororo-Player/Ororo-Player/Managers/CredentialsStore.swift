//
//  CredentialsStore.swift
//  Ororo-Player
//

import Foundation
import Security
import OroroKit

/// Persists the ororo.tv login in the Keychain as a single generic-password item
/// (account = username, data = password).
///
/// Builds before the Keychain move kept both values in `UserDefaults`; `load()`
/// migrates such a login on first launch and removes the plain-text copy.
final class CredentialsStore {

    private let service: String

    init(service: String = (Bundle.main.bundleIdentifier ?? "Ororo-Player") + ".credentials") {
        self.service = service
    }

    func save(_ credentials: Credentials) {
        deleteKeychainItem()

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentials.username,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(credentials.password.utf8)
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            logDebug("[CredentialsStore] SecItemAdd failed: \(status)")
        }
        LegacyDefaults.clear()
    }

    func load() -> Credentials? {
        if let credentials = loadFromKeychain() {
            return credentials
        }
        guard let legacy = LegacyDefaults.load() else { return nil }
        save(legacy)
        return legacy
    }

    func clear() {
        deleteKeychainItem()
        LegacyDefaults.clear()
    }

    // MARK: - Keychain

    private func loadFromKeychain() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let item = result as? [String: Any],
              let username = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            if status != errSecItemNotFound {
                logDebug("[CredentialsStore] SecItemCopyMatching failed: \(status)")
            }
            return nil
        }
        return Credentials(username: username, password: password)
    }

    private func deleteKeychainItem() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Legacy UserDefaults storage

    private enum LegacyDefaults {
        static let usernameKey = "credentials.username"
        static let passwordKey = "credentials.password"

        static func load() -> Credentials? {
            guard
                let username = UserDefaults.standard.string(forKey: usernameKey),
                let password = UserDefaults.standard.string(forKey: passwordKey)
            else { return nil }
            return Credentials(username: username, password: password)
        }

        static func clear() {
            UserDefaults.standard.removeObject(forKey: usernameKey)
            UserDefaults.standard.removeObject(forKey: passwordKey)
        }
    }
}

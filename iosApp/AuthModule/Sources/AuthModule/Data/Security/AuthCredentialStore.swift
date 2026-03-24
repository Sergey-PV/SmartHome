import Foundation
import Security

protocol AuthCredentialStoring: Sendable {
    func loadTokens() throws -> AuthTokens?
    func saveTokens(_ tokens: AuthTokens) throws
    func removeTokens() throws

    func loadBiometricCredential() throws -> BiometricCredential?
    func saveBiometricCredential(_ credential: BiometricCredential) throws
    func removeBiometricCredential() throws
    func removeAll() throws
}

enum KeychainStoreError: Error, Sendable {
    case unhandled(OSStatus)
}

final class KeychainAuthCredentialStore: AuthCredentialStoring, @unchecked Sendable {
    private let service: String

    init(service: String = "com.sergey.parfenchyk.smarthome.auth") {
        self.service = service
    }

    func loadTokens() throws -> AuthTokens? {
        try load(AuthTokens.self, account: "tokens")
    }

    func saveTokens(_ tokens: AuthTokens) throws {
        try save(tokens, account: "tokens")
    }

    func removeTokens() throws {
        try remove(account: "tokens")
    }

    func loadBiometricCredential() throws -> BiometricCredential? {
        try load(BiometricCredential.self, account: "biometric")
    }

    func saveBiometricCredential(_ credential: BiometricCredential) throws {
        try save(credential, account: "biometric")
    }

    func removeBiometricCredential() throws {
        try remove(account: "biometric")
    }

    func removeAll() throws {
        try removeTokens()
        try removeBiometricCredential()
    }

    private func load<T: Decodable>(_ type: T.Type, account: String) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecItemNotFound:
            return nil
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return try JSONDecoder().decode(type, from: data)
        default:
            throw KeychainStoreError.unhandled(status)
        }
    }

    private func save<T: Encodable>(_ value: T, account: String) throws {
        try remove(account: account)

        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandled(status)
        }
    }

    private func remove(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandled(status)
        }
    }
}

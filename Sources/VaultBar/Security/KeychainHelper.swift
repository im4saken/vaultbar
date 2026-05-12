import Foundation
import LocalAuthentication
import Security

enum KeychainError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case randomGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Unable to encode the value for Keychain storage."
        case .decodingFailed:
            "Unable to decode the value from Keychain storage."
        case .itemNotFound:
            "The requested Keychain item was not found."
        case .unexpectedStatus(let status):
            "Keychain returned OSStatus \(status)."
        case .randomGenerationFailed(let status):
            "Secure random generation failed with OSStatus \(status)."
        }
    }
}

final class KeychainHelper: @unchecked Sendable {
    static let shared = KeychainHelper()

    private let apiKeyService = "com.vaultbar.api-keys"
    private let metadataService = "com.vaultbar.metadata"
    private let metadataKeyAccount = "metadata-encryption-key"
    private let vaultAccount = "vault-secrets"

    private init() {}

    func saveAPIKey(_ secret: String, id: UUID) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        try upsert(data: data, service: apiKeyService, account: id.uuidString)
    }

    func readAPIKey(id: UUID, context: LAContext? = nil) throws -> String {
        let data = try read(service: apiKeyService, account: id.uuidString, context: context)
        guard let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return secret
    }

    func readAllAPIKeys() throws -> [UUID: String] {
        let data = try read(service: apiKeyService, account: vaultAccount)
        let raw = try JSONDecoder().decode([String: String].self, from: data)
        return raw.reduce(into: [UUID: String]()) { result, pair in
            guard let id = UUID(uuidString: pair.key) else { return }
            result[id] = pair.value
        }
    }

    func saveAllAPIKeys(_ secrets: [UUID: String]) throws {
        let raw = secrets.reduce(into: [String: String]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        let data = try JSONEncoder().encode(raw)
        try upsert(data: data, service: apiKeyService, account: vaultAccount)
    }

    func deleteAPIKey(id: UUID) throws {
        try delete(service: apiKeyService, account: id.uuidString)
    }

    func metadataEncryptionKey() throws -> Data {
        if let existing = try? read(service: metadataService, account: metadataKeyAccount) {
            return existing
        }

        var key = Data(count: 32)
        let status = key.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }

        guard status == errSecSuccess else {
            throw KeychainError.randomGenerationFailed(status)
        }

        try upsert(data: key, service: metadataService, account: metadataKeyAccount)
        return key
    }

    private func upsert(data: Data, service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private func read(service: String, account: String, context: LAContext? = nil) throws -> Data {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.decodingFailed
        }

        return data
    }

    private func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    func saveLabels(_ labels: [UUID: String]) throws {
        let raw = labels.reduce(into: [String: String]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        let data = try JSONEncoder().encode(raw)
        try upsert(data: data, service: "com.vaultbar.labels", account: "labels")
    }

    func loadLabels() throws -> [UUID: String] {
        let data = try read(service: "com.vaultbar.labels", account: "labels")
        let raw = try JSONDecoder().decode([String: String].self, from: data)
        return raw.reduce(into: [UUID: String]()) { result, pair in
            guard let id = UUID(uuidString: pair.key) else { return }
            result[id] = pair.value
        }
    }



    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

import CryptoKit
import Foundation

enum MetadataStoreError: LocalizedError {
    case invalidEncryptionKey
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidEncryptionKey:
            "The metadata encryption key is invalid."
        case .applicationSupportUnavailable:
            "Application Support is unavailable."
        }
    }
}

actor MetadataStore {
    private let keychain: KeychainHelper
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(keychain: KeychainHelper = .shared) {
        self.keychain = keychain
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [KeyMetadata] {
        let url = try metadataURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: Data(contentsOf: url))
            let data = try AES.GCM.open(sealedBox, using: try symmetricKey())
            return try decoder.decode([KeyMetadata].self, from: data)
        } catch {
            // Decryption failed — fall back to reading metadata from keychain vault-secrets + labels
            let raw = try keychain.readAllAPIKeys()
            var labels: [UUID: String] = [:]
            do {
                labels = try keychain.loadLabels()
            } catch {}
            return raw.map { id, _ in
                let label = labels[id] ?? ""
                return KeyMetadata(id: id, label: label, createdAt: Date(), updatedAt: Date())
            }
        }
    }

    func save(_ metadata: [KeyMetadata]) throws {
        let data = try encoder.encode(metadata)
        let sealedBox = try AES.GCM.seal(data, using: try symmetricKey())
        guard let encryptedData = sealedBox.combined else {
            throw MetadataStoreError.invalidEncryptionKey
        }

        let url = try metadataURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encryptedData.write(to: url, options: [.atomic, .completeFileProtection])

        // Also persist labels to keychain for recovery if metadata file is lost
        let labels = Dictionary(uniqueKeysWithValues: metadata.map { ($0.id, $0.label) })
        try keychain.saveLabels(labels)
    }

    private func symmetricKey() throws -> SymmetricKey {
        let data = try keychain.metadataEncryptionKey()
        guard data.count == 32 else {
            throw MetadataStoreError.invalidEncryptionKey
        }
        return SymmetricKey(data: data)
    }

    private func metadataURL() throws -> URL {
        guard let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw MetadataStoreError.applicationSupportUnavailable
        }

        return baseURL
            .appendingPathComponent("VaultBar", isDirectory: true)
            .appendingPathComponent("metadata.json.enc")
    }
}

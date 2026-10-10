import CryptoKit
import Foundation

enum MetadataStoreError: LocalizedError {
    case invalidEncryptionKey
    case applicationSupportUnavailable
    case restoredKeychainItemsMissing

    var errorDescription: String? {
        switch self {
        case .invalidEncryptionKey:
            "The metadata encryption key is invalid."
        case .applicationSupportUnavailable:
            "Application Support is unavailable."
        case .restoredKeychainItemsMissing:
            "VaultBar found restored metadata, but the required Keychain items are missing on this Mac. API keys saved with ThisDeviceOnly protection cannot be migrated by Time Machine. Export from the old Mac if available, then import here."
        }
    }
}

actor MetadataStore {
    private let keychain: KeychainHelper
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURLOverride: URL?

    init(keychain: KeychainHelper = .shared, fileURL: URL? = nil) {
        self.keychain = keychain
        self.fileURLOverride = fileURL
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
            let data = try AES.GCM.open(sealedBox, using: try symmetricKey(createIfMissing: false))
            return try decoder.decode([KeyMetadata].self, from: data)
        } catch {
            // Keep a copy of the unreadable file: the recovery below loses website/notes
            // and the caller may overwrite the original with the recovered data.
            try backUpUnreadableFile(at: url)

            // Decryption failed — fall back to reading metadata from keychain vault-secrets + labels
            let raw: [UUID: String]
            do {
                raw = try keychain.readAllAPIKeys()
            } catch KeychainError.itemNotFound {
                throw MetadataStoreError.restoredKeychainItemsMissing
            }

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
        let labels = Dictionary(metadata.map { ($0.id, $0.label) }, uniquingKeysWith: { _, latest in latest })
        try keychain.saveLabels(labels)
    }

    private func backUpUnreadableFile(at url: URL) throws {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).bak-\(timestamp)")
        try FileManager.default.copyItem(at: url, to: backupURL)
    }

    private func symmetricKey(createIfMissing: Bool = true) throws -> SymmetricKey {
        let data = try keychain.metadataEncryptionKey(createIfMissing: createIfMissing)
        guard data.count == 32 else {
            throw MetadataStoreError.invalidEncryptionKey
        }
        return SymmetricKey(data: data)
    }

    private func metadataURL() throws -> URL {
        if let fileURLOverride {
            return fileURLOverride
        }

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

import AppKit
import Foundation
import LocalAuthentication

@MainActor
final class KeyRepository: ObservableObject {
    @Published private(set) var items: [KeyMetadata] = []
    @Published var searchText = ""
    @Published var selectedID: UUID?
    @Published var errorMessage: String?
    @Published var clipboardClearSeconds: Int {
        didSet {
            UserDefaults.standard.set(clipboardClearSeconds, forKey: clipboardTimeoutKey)
        }
    }

    private let keychain: KeychainHelper
    private let metadataStore: MetadataStore
    private var clipboardClearTask: Task<Void, Never>?
    private let clipboardTimeoutKey = "clipboardClearSeconds"

    init(
        keychain: KeychainHelper = .shared,
        metadataStore: MetadataStore = MetadataStore()
    ) {
        self.keychain = keychain
        self.metadataStore = metadataStore
        let savedTimeout = UserDefaults.standard.object(forKey: clipboardTimeoutKey) as? Int
        self.clipboardClearSeconds = savedTimeout ?? 60
    }

    var searchResults: [KeyMetadata] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return FuzzySearch.ranked(items, query: searchText)
    }

    var selectedOrTopResult: KeyMetadata? {
        if let selectedID, let selected = searchResults.first(where: { $0.id == selectedID }) {
            return selected
        }
        return searchResults.first
    }

    func load() {
        Task {
            do {
                items = try await metadataStore.load()
                // If labels were empty (recovered from keychain), save them to persist
                if items.contains(where: { $0.label.isEmpty }) && !items.isEmpty {
                    try await metadataStore.save(items)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func add(_ newKey: NewAPIKey) async -> Bool {
        let label = newKey.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            errorMessage = "Label is required."
            return false
        }

        do {
            let now = Date()
            let metadata = KeyMetadata(id: UUID(), label: label, createdAt: now, updatedAt: now)
            try upsertVaultSecret(newKey.secret, id: metadata.id)
            var updatedItems = items
            updatedItems.append(metadata)
            try await metadataStore.save(updatedItems)
            items = updatedItems
            searchText = label
            selectedID = metadata.id
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }


    func batchImport(textContent: String) async -> (successCount: Int, errorMessages: [String]) {
        let lines = textContent.split(separator: "\n", omittingEmptySubsequences: false)
        var successCount = 0
        var errorMessages: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Skip comment lines (for .md files)
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("//") { continue }

            // Parse "label,api_key" format - split on first comma only
            guard let firstComma = trimmed.firstIndex(of: ",") else {
                errorMessages.append("Line \(index + 1): Invalid format. Expected label,api_key.")
                continue
            }

            let label = String(trimmed[..<firstComma]).trimmingCharacters(in: .whitespacesAndNewlines)
            let secret = String(trimmed[firstComma...]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !label.isEmpty else {
                errorMessages.append("Line \(index + 1): Label is empty.")
                continue
            }

            guard !secret.isEmpty else {
                errorMessages.append("Line \(index + 1): API key is empty.")
                continue
            }

            do {
                let now = Date()
                let metadata = KeyMetadata(id: UUID(), label: label, createdAt: now, updatedAt: now)
                try upsertVaultSecret(secret, id: metadata.id)
                var updatedItems = items
                updatedItems.append(metadata)
                try await metadataStore.save(updatedItems)
                items = updatedItems
                successCount += 1
            } catch {
                errorMessages.append("Line \(index + 1): \(error.localizedDescription)")
            }
        }

        return (successCount, errorMessages)
    }


    func secret(for metadata: KeyMetadata) -> String {
        do {
            return try keychain.readAPIKey(id: metadata.id)
        } catch {
            errorMessage = error.localizedDescription
            return ""
        }
    }

    func unlockSecretsForSettings() async -> [UUID: String] {
        let context = LAContext()
        context.localizedReason = "Unlock VaultBar API keys"
        context.localizedFallbackTitle = "Use Password"
        context.touchIDAuthenticationAllowableReuseDuration = 300

        do {
            try await authenticateForSettingsUnlock(context: context)
        } catch {
            errorMessage = error.localizedDescription
            return [:]
        }

        do {
            let allSecrets = try unlockedVaultSecrets()
            return items.reduce(into: [UUID: String]()) { result, item in
                result[item.id] = allSecrets[item.id]
            }
        } catch {
            errorMessage = error.localizedDescription
            return [:]
        }
    }

    private func authenticateForSettingsUnlock(context: LAContext) async throws {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error {
                throw error
            }
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock all VaultBar API keys") { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? LAError(.authenticationFailed))
                }
            }
        }
    }

    func update(id: UUID, label: String, secret: String) async -> Bool {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            errorMessage = "Label is required."
            return false
        }

        do {
            guard let index = items.firstIndex(where: { $0.id == id }) else {
                errorMessage = "Key not found."
                return false
            }

            try upsertVaultSecret(secret, id: id)
            var updatedItems = items
            updatedItems[index].label = label
            updatedItems[index].updatedAt = Date()
            try await metadataStore.save(updatedItems)
            items = updatedItems
            searchText = label
            selectedID = id
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(id: UUID) async -> Bool {
        do {
            try keychain.deleteAPIKey(id: id)
            var vaultSecrets = try unlockedVaultSecrets()
            vaultSecrets[id] = nil
            try keychain.saveAllAPIKeys(vaultSecrets)
            let updatedItems = items.filter { $0.id != id }
            try await metadataStore.save(updatedItems)
            items = updatedItems
            if selectedID == id {
                selectedID = searchResults.first?.id
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func copySelectedOrTopResult() -> Bool {
        guard let metadata = selectedOrTopResult else {
            NSSound.beep()
            return false
        }

        do {
            let secret = try readSecret(id: metadata.id)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(secret, forType: .string)
            scheduleClipboardClear(changeCount: NSPasteboard.general.changeCount)
            return true
        } catch {
            errorMessage = error.localizedDescription
            NSSound.beep()
            return false
        }
    }

    func moveSelection(delta: Int) {
        let results = searchResults
        guard !results.isEmpty else {
            selectedID = nil
            return
        }

        let currentIndex = selectedID.flatMap { id in results.firstIndex { $0.id == id } } ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), results.count - 1)
        selectedID = results[nextIndex].id
    }

    func resetSelectionToTop() {
        selectedID = searchResults.first?.id
    }

    func scheduleClipboardClear(changeCount: Int) {
        clipboardClearTask?.cancel()
        guard clipboardClearSeconds > 0 else { return }

        clipboardClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(clipboardClearSeconds))
            guard !Task.isCancelled else { return }
            guard NSPasteboard.general.changeCount == changeCount else { return }
            NSPasteboard.general.clearContents()
        }
    }

    func readSecret(id: UUID) throws -> String {
        if let secret = try? keychain.readAllAPIKeys()[id] {
            return secret
        }
        return try keychain.readAPIKey(id: id)
    }

    private func unlockedVaultSecrets() throws -> [UUID: String] {
        do {
            return try keychain.readAllAPIKeys()
        } catch KeychainError.itemNotFound {
            return try migrateLegacySecretsToVault()
        }
    }

    private func upsertVaultSecret(_ secret: String, id: UUID) throws {
        var secrets = (try? unlockedVaultSecrets()) ?? [:]
        secrets[id] = secret
        try keychain.saveAllAPIKeys(secrets)
        try keychain.saveAPIKey(secret, id: id)
    }

    private func migrateLegacySecretsToVault() throws -> [UUID: String] {
        var secrets: [UUID: String] = [:]
        for item in items {
            if let secret = try? keychain.readAPIKey(id: item.id) {
                secrets[item.id] = secret
            }
        }
        try keychain.saveAllAPIKeys(secrets)
        return secrets
    }
}

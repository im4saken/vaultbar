import XCTest
@testable import VaultBar

final class MetadataStoreErrorTests: XCTestCase {
    func testRestoredKeychainItemsMissingExplainsTimeMachineMigration() {
        let message = MetadataStoreError.restoredKeychainItemsMissing.localizedDescription

        XCTAssertTrue(message.contains("Keychain items are missing"))
        XCTAssertTrue(message.contains("Time Machine"))
        XCTAssertTrue(message.contains("Export from the old Mac"))
    }

    func testLoadBacksUpUndecryptableFileBeforeFallingBack() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaultBarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("metadata.json.enc")
        let original = Data("not a valid sealed box".utf8)
        try original.write(to: fileURL)

        // The fallback may recover items or throw depending on the local Keychain;
        // either way the original bytes must survive in a backup.
        _ = try? await MetadataStore(fileURL: fileURL).load()

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("metadata.json.enc.bak-") }
        XCTAssertEqual(backups.count, 1)
        let backupData = try Data(contentsOf: directory.appendingPathComponent(try XCTUnwrap(backups.first)))
        XCTAssertEqual(backupData, original)
        XCTAssertEqual(try Data(contentsOf: fileURL), original, "original file must be left in place")
    }

    func testLoadDoesNotCreateBackupWhenFileIsMissing() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaultBarTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("metadata.json.enc")

        let items = try await MetadataStore(fileURL: fileURL).load()

        XCTAssertTrue(items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path))
    }
}

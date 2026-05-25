import XCTest
@testable import VaultBar

final class MetadataStoreErrorTests: XCTestCase {
    func testRestoredKeychainItemsMissingExplainsTimeMachineMigration() {
        let message = MetadataStoreError.restoredKeychainItemsMissing.localizedDescription

        XCTAssertTrue(message.contains("Keychain items are missing"))
        XCTAssertTrue(message.contains("Time Machine"))
        XCTAssertTrue(message.contains("Export from the old Mac"))
    }
}

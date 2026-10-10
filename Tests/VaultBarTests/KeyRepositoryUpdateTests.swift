import XCTest
@testable import VaultBar

@MainActor
final class KeyRepositoryUpdateTests: XCTestCase {
    func testUpdateRejectsEmptySecretWithoutTouchingStorage() async {
        let repository = KeyRepository()

        let ok = await repository.update(id: UUID(), label: "Label", secret: "   ", website: "", notes: "")

        XCTAssertFalse(ok)
        XCTAssertEqual(repository.errorMessage, "API key is required.")
    }

    func testUpdateRejectsEmptyLabel() async {
        let repository = KeyRepository()

        let ok = await repository.update(id: UUID(), label: " ", secret: "secret", website: "", notes: "")

        XCTAssertFalse(ok)
        XCTAssertEqual(repository.errorMessage, "Label is required.")
    }

    func testUpdateUnknownKeyFailsWithoutChangingItems() async {
        let repository = KeyRepository()

        let ok = await repository.update(id: UUID(), label: "Label", secret: "secret", website: "", notes: "")

        XCTAssertFalse(ok)
        XCTAssertEqual(repository.errorMessage, "Key not found.")
        XCTAssertTrue(repository.items.isEmpty)
    }
}

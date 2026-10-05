import AppKit
import XCTest
@testable import VaultBar

@MainActor
final class ClipboardAndSortTests: XCTestCase {
    func testWriteSecretMarksPasteboardConcealedAndTransient() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("VaultBarTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        KeyRepository.writeSecret("sk-test", to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "sk-test")
        let types = pasteboard.types ?? []
        XCTAssertTrue(types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
        XCTAssertTrue(types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")))
    }

    func testSortedByLabelIsAlphabeticalCaseInsensitiveAndNumeric() {
        let labels = ["openai", "Anthropic", "Key10", "groq", "Key2", "DeepSeek"]
        let items = labels.map { KeyMetadata(id: UUID(), label: $0, createdAt: Date(), updatedAt: Date()) }

        let sorted = KeyRepository.sortedByLabel(items).map(\.label)

        XCTAssertEqual(sorted, ["Anthropic", "DeepSeek", "groq", "Key2", "Key10", "openai"])
    }

    func testSortedByLabelIgnoresUpdatedAtAndKeepsDuplicatesStable() {
        let older = Date(timeIntervalSince1970: 0)
        let newer = Date(timeIntervalSince1970: 100)
        let first = KeyMetadata(id: UUID(), label: "OpenAI", createdAt: older, updatedAt: older)
        let second = KeyMetadata(id: UUID(), label: "OpenAI", createdAt: newer, updatedAt: newer)
        let zeta = KeyMetadata(id: UUID(), label: "Zeta", createdAt: older, updatedAt: newer)

        let sorted = KeyRepository.sortedByLabel([zeta, second, first])

        XCTAssertEqual(sorted.map(\.id), [first.id, second.id, zeta.id])
    }
}

import XCTest
@testable import VaultBar

final class ExportImportRoundTripTests: XCTestCase {
    func testExportProducesHeaderAndFourColumns() {
        let id = UUID()
        let item = KeyMetadata(
            id: id,
            label: "OpenAI",
            website: "openai.com",
            notes: "主账户",
            createdAt: Date(),
            updatedAt: Date()
        )
        let csv = KeyRepository.buildExportCSV(items: [item], secrets: [id: "sk-test"])

        let rows = CSVCodec.parse(csv)
        XCTAssertEqual(rows.first, ["label", "api_key", "website", "notes"])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["OpenAI", "sk-test", "openai.com", "主账户"])
    }

    func testExportEscapesSpecialCharacters() {
        let id = UUID()
        let item = KeyMetadata(
            id: id,
            label: "Has,Comma",
            website: "ex.com",
            notes: "包含\"引号\"和\n换行",
            createdAt: Date(),
            updatedAt: Date()
        )
        let csv = KeyRepository.buildExportCSV(items: [item], secrets: [id: "secret"])

        let rows = CSVCodec.parse(csv)
        XCTAssertEqual(rows[1], ["Has,Comma", "secret", "ex.com", "包含\"引号\"和\n换行"])
    }

    func testExportMissingSecretBecomesEmpty() {
        let id = UUID()
        let item = KeyMetadata(
            id: id,
            label: "Locked",
            website: "",
            notes: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        let csv = KeyRepository.buildExportCSV(items: [item], secrets: [:])

        let rows = CSVCodec.parse(csv)
        XCTAssertEqual(rows[1], ["Locked", "", "", ""])
    }

    func testRoundTripThroughCSVPreservesAllFields() {
        let items: [KeyMetadata] = (0..<3).map { i in
            KeyMetadata(
                id: UUID(),
                label: "k\(i)",
                website: "site\(i).com",
                notes: "note,\(i)",
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        let secrets = Dictionary(uniqueKeysWithValues: items.map { ($0.id, "secret-\($0.label)") })
        let csv = KeyRepository.buildExportCSV(items: items, secrets: secrets)

        let rows = CSVCodec.parse(csv)
        XCTAssertEqual(rows.count, items.count + 1)
        for (i, item) in items.enumerated() {
            XCTAssertEqual(rows[i + 1][0], item.label)
            XCTAssertEqual(rows[i + 1][1], "secret-\(item.label)")
            XCTAssertEqual(rows[i + 1][2], item.website)
            XCTAssertEqual(rows[i + 1][3], item.notes)
        }
    }
}

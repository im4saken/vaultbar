import XCTest
@testable import VaultBar

final class CSVCodecTests: XCTestCase {
    func testParseSimpleRow() {
        XCTAssertEqual(CSVCodec.parse("a,b,c"), [["a", "b", "c"]])
    }

    func testParseMultipleRows() {
        XCTAssertEqual(
            CSVCodec.parse("a,b\nc,d\n"),
            [["a", "b"], ["c", "d"]]
        )
    }

    func testParseCRLF() {
        XCTAssertEqual(
            CSVCodec.parse("a,b\r\nc,d\r\n"),
            [["a", "b"], ["c", "d"]]
        )
    }

    func testParseQuotedFieldWithComma() {
        XCTAssertEqual(
            CSVCodec.parse("\"a,b\",c"),
            [["a,b", "c"]]
        )
    }

    func testParseQuotedFieldWithEscapedQuote() {
        XCTAssertEqual(
            CSVCodec.parse("\"a\"\"b\",c"),
            [["a\"b", "c"]]
        )
    }

    func testParseQuotedFieldWithNewline() {
        XCTAssertEqual(
            CSVCodec.parse("\"line1\nline2\",x"),
            [["line1\nline2", "x"]]
        )
    }

    func testParseEmptyFields() {
        XCTAssertEqual(
            CSVCodec.parse("a,,c"),
            [["a", "", "c"]]
        )
    }

    func testSerializeSimple() {
        XCTAssertEqual(
            CSVCodec.serialize([["a", "b"], ["c", "d"]]),
            "a,b\nc,d"
        )
    }

    func testSerializeFieldWithCommaIsQuoted() {
        XCTAssertEqual(CSVCodec.escapeField("a,b"), "\"a,b\"")
    }

    func testSerializeFieldWithQuoteIsEscaped() {
        XCTAssertEqual(CSVCodec.escapeField("a\"b"), "\"a\"\"b\"")
    }

    func testSerializeFieldWithNewlineIsQuoted() {
        XCTAssertEqual(CSVCodec.escapeField("a\nb"), "\"a\nb\"")
    }

    func testRoundTripSpecialCharacters() {
        let rows: [[String]] = [
            ["label", "api_key", "website", "notes"],
            ["A", "sk-1", "a.com", "含,逗号"],
            ["B", "sk-2", "b.com", "含\"引号\""],
            ["C", "sk-3", "c.com", "多行\n备注"]
        ]
        let serialized = CSVCodec.serialize(rows)
        let parsed = CSVCodec.parse(serialized)
        XCTAssertEqual(parsed, rows)
    }
}

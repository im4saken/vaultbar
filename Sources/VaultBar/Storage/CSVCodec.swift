import Foundation

enum CSVCodec {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var fieldWasQuoted = false
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]

            if inQuotes {
                if c == "\"" {
                    let next = text.index(after: i)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        i = text.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                    fieldWasQuoted = true
                case ",":
                    row.append(field)
                    field = ""
                    fieldWasQuoted = false
                case "\n", "\r", "\r\n":
                    // "\r\n" is a single Character in Swift.
                    row.append(field)
                    rows.append(row)
                    field = ""
                    row = []
                    fieldWasQuoted = false
                default:
                    field.append(c)
                }
            }

            i = text.index(after: i)
        }

        if !field.isEmpty || !row.isEmpty || fieldWasQuoted {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    static func serialize(_ rows: [[String]]) -> String {
        rows.map { row in row.map(escapeField).joined(separator: ",") }
            .joined(separator: "\n")
    }

    static func escapeField(_ field: String) -> String {
        let needsQuoting = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

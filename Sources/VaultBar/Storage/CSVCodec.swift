import Foundation

enum CSVCodec {
    static func parse(_ text: String) -> [[String]] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var i = normalized.startIndex

        while i < normalized.endIndex {
            let c = normalized[i]

            if inQuotes {
                if c == "\"" {
                    let next = normalized.index(after: i)
                    if next < normalized.endIndex, normalized[next] == "\"" {
                        field.append("\"")
                        i = normalized.index(after: next)
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
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    field = ""
                    row = []
                default:
                    field.append(c)
                }
            }

            i = normalized.index(after: i)
        }

        if !field.isEmpty || !row.isEmpty {
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

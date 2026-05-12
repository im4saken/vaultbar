import Foundation

enum FuzzySearch {
    static func ranked(_ items: [KeyMetadata], query: String) -> [KeyMetadata] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return items.sorted { $0.updatedAt > $1.updatedAt }
        }

        return items
            .compactMap { item -> (KeyMetadata, Int)? in
                let score = score(label: item.label, query: trimmedQuery)
                return score > 0 ? (item, score) : nil
            }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.updatedAt > $1.0.updatedAt
                }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private static func score(label: String, query: String) -> Int {
        let label = label.lowercased()
        let query = query.lowercased()

        if label == query { return 10_000 }
        if label.hasPrefix(query) { return 8_000 - label.count }
        if label.contains(query) { return 6_000 - label.count }

        var score = 0
        var searchStart = label.startIndex
        var previousMatch: String.Index?

        for character in query {
            guard let match = label[searchStart...].firstIndex(of: character) else {
                return 0
            }

            score += 200
            if let previousMatch, label.index(after: previousMatch) == match {
                score += 120
            }
            if match == label.startIndex || label[label.index(before: match)] == " " || label[label.index(before: match)] == "-" {
                score += 80
            }

            previousMatch = match
            searchStart = label.index(after: match)
        }

        return score - label.count
    }
}

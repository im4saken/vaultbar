import Foundation

struct KeyMetadata: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    let createdAt: Date
    var updatedAt: Date
}

struct NewAPIKey: Equatable {
    var label: String
    var secret: String

    var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !secret.isEmpty
    }
}

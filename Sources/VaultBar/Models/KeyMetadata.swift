import Foundation

struct KeyMetadata: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    var website: String
    var notes: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        label: String,
        website: String = "",
        notes: String = "",
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.label = label
        self.website = website
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        website = try container.decodeIfPresent(String.self, forKey: .website) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct NewAPIKey: Equatable {
    var label: String
    var secret: String
    var website: String
    var notes: String

    init(
        label: String,
        secret: String,
        website: String = "",
        notes: String = ""
    ) {
        self.label = label
        self.secret = secret
        self.website = website
        self.notes = notes
    }

    var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !secret.isEmpty
    }
}

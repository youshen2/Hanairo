import Foundation

struct LocalBlockedUser: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let createdAt: Date
}

struct LocalBlockedArtwork: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let createdAt: Date
}

struct LocalBlockedTag: Codable, Identifiable, Hashable, Sendable {
    let name: String
    let translatedName: String?
    let createdAt: Date

    var id: String { LocalBlockArchive.normalizedTag(name) }
    var displayName: String { translatedName ?? name }
}

struct LocalBlockedComment: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let authorID: Int
    let authorName: String
    let preview: String
    let createdAt: Date
}

struct LocalBlockArchive: Codable, Hashable, Sendable {
    var users: [LocalBlockedUser]
    var artworks: [LocalBlockedArtwork]
    var tags: [LocalBlockedTag]
    var comments: [LocalBlockedComment]

    init(
        users: [LocalBlockedUser] = [],
        artworks: [LocalBlockedArtwork] = [],
        tags: [LocalBlockedTag] = [],
        comments: [LocalBlockedComment] = []
    ) {
        self.users = users
        self.artworks = artworks
        self.tags = tags
        self.comments = comments
    }

    enum CodingKeys: String, CodingKey {
        case users
        case artworks
        case tags
        case comments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decodeIfPresent([LocalBlockedUser].self, forKey: .users) ?? []
        artworks = try container.decodeIfPresent([LocalBlockedArtwork].self, forKey: .artworks) ?? []
        tags = try container.decodeIfPresent([LocalBlockedTag].self, forKey: .tags) ?? []
        comments = try container.decodeIfPresent([LocalBlockedComment].self, forKey: .comments) ?? []
    }

    static func normalizedTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

import Foundation

struct IllustrationFeedResponse: Decodable, Sendable {
    let illustrations: [PixivIllustration]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case illustrations = "illusts"
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        illustrations = try container.decodeIfPresent([PixivIllustration].self, forKey: .illustrations) ?? []
        nextURL = try container.decodeOptionalURL(forKey: .nextURL)
    }

    var page: PixivPage<PixivIllustration> {
        PixivPage(items: illustrations, nextURL: nextURL)
    }
}

struct IllustrationDetailResponse: Decodable, Sendable {
    let illustration: PixivIllustration

    enum CodingKeys: String, CodingKey {
        case illustration = "illust"
    }
}

struct UserPreviewResponse: Decodable, Sendable {
    let users: [PixivUserPreview]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case users = "user_previews"
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decodeIfPresent([PixivUserPreview].self, forKey: .users) ?? []
        nextURL = try container.decodeOptionalURL(forKey: .nextURL)
    }

    var page: PixivPage<PixivUserPreview> {
        PixivPage(items: users, nextURL: nextURL)
    }
}

struct TrendingTagsResponse: Decodable, Sendable {
    let tags: [PixivTrendingTag]

    enum CodingKeys: String, CodingKey {
        case tags = "trend_tags"
    }
}

struct PixivTrendingTag: Decodable, Identifiable, Hashable, Sendable {
    let tag: String
    let translatedName: String?
    let illustration: TrendingTagIllustration

    var id: String { tag }
    var displayName: String { translatedName ?? tag }

    enum CodingKeys: String, CodingKey {
        case tag
        case translatedName = "translated_name"
        case illustration = "illust"
    }
}

struct TrendingTagIllustration: Decodable, Hashable, Sendable {
    let id: Int
    let imageURLs: PixivImageURLs

    enum CodingKeys: String, CodingKey {
        case id
        case imageURLs = "image_urls"
    }
}

private extension KeyedDecodingContainer {
    func decodeOptionalURL(forKey key: Key) throws -> URL? {
        guard
            let value = try decodeIfPresent(String.self, forKey: key),
            !value.isEmpty
        else {
            return nil
        }
        return URL(string: value)
    }
}

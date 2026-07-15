import Foundation

nonisolated struct PixivIllustrationSeriesResponse: Decodable, Sendable {
    var detail: PixivIllustrationSeriesDetail?
    let firstIllustration: PixivIllustration?
    let illustrations: [PixivIllustration]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case detail = "illust_series_detail"
        case firstIllustration = "illust_series_first_illust"
        case illustrations = "illusts"
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        detail = try container.decodeIfPresent(PixivIllustrationSeriesDetail.self, forKey: .detail)
        firstIllustration = try container.decodeIfPresent(PixivIllustration.self, forKey: .firstIllustration)
        illustrations = try container.decodeIfPresent([PixivIllustration].self, forKey: .illustrations) ?? []
        let value = try container.decodeIfPresent(String.self, forKey: .nextURL)
        nextURL = value.flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    var page: PixivPage<PixivIllustration> {
        var values = illustrations
        if let firstIllustration, !values.contains(where: { $0.id == firstIllustration.id }) {
            values.append(firstIllustration)
        }
        return PixivPage(items: values, nextURL: nextURL)
    }
}

nonisolated struct PixivIllustrationSeriesResult: Sendable {
    let detail: PixivIllustrationSeriesDetail
    let page: PixivPage<PixivIllustration>
}

nonisolated struct PixivIllustrationSeriesDetail: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let caption: String
    let coverImageURLs: PixivSeriesCoverImageURLs
    let seriesWorkCount: Int
    let createDate: String
    let width: Int
    let height: Int
    let user: PixivUser?
    var watchlistAdded: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case coverImageURLs = "cover_image_urls"
        case seriesWorkCount = "series_work_count"
        case createDate = "create_date"
        case width
        case height
        case user
        case watchlistAdded = "watchlist_added"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名系列"
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        coverImageURLs = try container.decodeIfPresent(
            PixivSeriesCoverImageURLs.self,
            forKey: .coverImageURLs
        ) ?? .init(medium: nil)
        seriesWorkCount = try container.decodeIfPresent(Int.self, forKey: .seriesWorkCount) ?? 0
        createDate = try container.decodeIfPresent(String.self, forKey: .createDate) ?? ""
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
        user = try container.decodeIfPresent(PixivUser.self, forKey: .user)
        watchlistAdded = try container.decodeIfPresent(Bool.self, forKey: .watchlistAdded) ?? false
    }
}

nonisolated struct PixivSeriesCoverImageURLs: Decodable, Hashable, Sendable {
    let medium: URL?
}

nonisolated struct PixivMangaWatchlistResponse: Decodable, Sendable {
    let series: [PixivMangaSeriesSummary]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case series
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        series = try container.decodeIfPresent([PixivMangaSeriesSummary].self, forKey: .series) ?? []
        let value = try container.decodeIfPresent(String.self, forKey: .nextURL)
        nextURL = value.flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    var page: PixivPage<PixivMangaSeriesSummary> {
        PixivPage(items: series, nextURL: nextURL)
    }
}

nonisolated struct PixivMangaSeriesSummary: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let latestContentID: Int
    let lastPublishedContentDate: String?
    let publishedContentCount: Int
    let coverURL: URL?
    let maskText: String?
    let user: PixivMangaSeriesUser?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case latestContentID = "latest_content_id"
        case lastPublishedContentDate = "last_published_content_datetime"
        case publishedContentCount = "published_content_count"
        case coverURL = "url"
        case maskText = "mask_text"
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名系列"
        latestContentID = try container.decodeIfPresent(Int.self, forKey: .latestContentID) ?? 0
        lastPublishedContentDate = try container.decodeIfPresent(String.self, forKey: .lastPublishedContentDate)
        publishedContentCount = try container.decodeIfPresent(Int.self, forKey: .publishedContentCount) ?? 0
        coverURL = try container.decodeIfPresent(URL.self, forKey: .coverURL)
        maskText = try container.decodeIfPresent(String.self, forKey: .maskText)
        user = try container.decodeIfPresent(PixivMangaSeriesUser.self, forKey: .user)
    }
}

nonisolated struct PixivMangaSeriesUser: Decodable, Hashable, Sendable {
    let id: Int
    let account: String?
    let name: String?
    let profileImageURLs: PixivProfileImageURLs?

    enum CodingKeys: String, CodingKey {
        case id
        case account
        case name
        case profileImageURLs = "profile_image_urls"
    }
}

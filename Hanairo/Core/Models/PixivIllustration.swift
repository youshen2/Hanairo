import Foundation

struct PixivIllustration: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let type: String
    let imageURLs: PixivImageURLs
    let caption: String
    var user: PixivUser
    let tags: [PixivTag]
    let createDate: String
    let pageCount: Int
    let width: Int
    let height: Int
    let xRestrict: Int
    let series: PixivIllustrationSeries?
    let metaSinglePage: PixivMetaSinglePage?
    let metaPages: [PixivMetaPage]
    let totalViews: Int
    let totalBookmarks: Int
    var isBookmarked: Bool
    let isMuted: Bool
    let aiType: Int
    let totalComments: Int
    let commentAccessControl: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case imageURLs = "image_urls"
        case caption
        case user
        case tags
        case createDate = "create_date"
        case pageCount = "page_count"
        case width
        case height
        case xRestrict = "x_restrict"
        case series
        case metaSinglePage = "meta_single_page"
        case metaPages = "meta_pages"
        case totalViews = "total_view"
        case totalBookmarks = "total_bookmarks"
        case isBookmarked = "is_bookmarked"
        case isMuted = "is_muted"
        case aiType = "illust_ai_type"
        case totalComments = "total_comments"
        case commentAccessControl = "comment_access_control"
    }

    init(
        id: Int,
        title: String,
        type: String = "illust",
        imageURLs: PixivImageURLs = .empty,
        caption: String = "",
        user: PixivUser,
        tags: [PixivTag] = [],
        createDate: String = "",
        pageCount: Int = 1,
        width: Int = 1200,
        height: Int = 1600,
        xRestrict: Int = 0,
        series: PixivIllustrationSeries? = nil,
        metaSinglePage: PixivMetaSinglePage? = nil,
        metaPages: [PixivMetaPage] = [],
        totalViews: Int = 0,
        totalBookmarks: Int = 0,
        isBookmarked: Bool = false,
        isMuted: Bool = false,
        aiType: Int = 1,
        totalComments: Int = 0,
        commentAccessControl: Int = 0
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.imageURLs = imageURLs
        self.caption = caption
        self.user = user
        self.tags = tags
        self.createDate = createDate
        self.pageCount = pageCount
        self.width = width
        self.height = height
        self.xRestrict = xRestrict
        self.series = series
        self.metaSinglePage = metaSinglePage
        self.metaPages = metaPages
        self.totalViews = totalViews
        self.totalBookmarks = totalBookmarks
        self.isBookmarked = isBookmarked
        self.isMuted = isMuted
        self.aiType = aiType
        self.totalComments = totalComments
        self.commentAccessControl = commentAccessControl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名作品"
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "illust"
        imageURLs = try container.decodeIfPresent(PixivImageURLs.self, forKey: .imageURLs) ?? .empty
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        user = try container.decode(PixivUser.self, forKey: .user)
        tags = try container.decodeIfPresent([PixivTag].self, forKey: .tags) ?? []
        createDate = try container.decodeIfPresent(String.self, forKey: .createDate) ?? ""
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 1
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 1
        xRestrict = try container.decodeIfPresent(Int.self, forKey: .xRestrict) ?? 0
        series = try container.decodeIfPresent(PixivIllustrationSeries.self, forKey: .series)
        metaSinglePage = try container.decodeIfPresent(PixivMetaSinglePage.self, forKey: .metaSinglePage)
        metaPages = try container.decodeIfPresent([PixivMetaPage].self, forKey: .metaPages) ?? []
        totalViews = try container.decodeIfPresent(Int.self, forKey: .totalViews) ?? 0
        totalBookmarks = try container.decodeIfPresent(Int.self, forKey: .totalBookmarks) ?? 0
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        aiType = try container.decodeIfPresent(Int.self, forKey: .aiType) ?? 0
        totalComments = try container.decodeIfPresent(Int.self, forKey: .totalComments) ?? 0
        commentAccessControl = try container.decodeIfPresent(Int.self, forKey: .commentAccessControl) ?? 0
    }

    var previewURL: URL? {
        imageURLs.large ?? imageURLs.medium ?? imageURLs.squareMedium
    }

    var isUgoira: Bool {
        type == "ugoira"
    }

    var pages: [PixivImageURLs] {
        if !metaPages.isEmpty {
            return metaPages.map(\.imageURLs)
        }
        return [imageURLs.addingOriginal(metaSinglePage?.originalImageURL)]
    }

    func pageURLs(for quality: ArtworkImageQuality) -> [URL?] {
        pages.map { $0.url(for: quality) }
    }

    var originalPageURLs: [URL?] {
        pages.map(\.fullSizeURL)
    }

    var aspectRatio: CGFloat {
        guard height > 0 else { return 0.75 }
        return CGFloat(width) / CGFloat(height)
    }
}

struct PixivIllustrationSeries: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String?
}

struct PixivImageURLs: Codable, Hashable, Sendable {
    let squareMedium: URL?
    let medium: URL?
    let large: URL?
    let original: URL?

    static let empty = PixivImageURLs()

    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
        case original
    }

    init(squareMedium: URL? = nil, medium: URL? = nil, large: URL? = nil, original: URL? = nil) {
        self.squareMedium = squareMedium
        self.medium = medium
        self.large = large
        self.original = original
    }

    func addingOriginal(_ url: URL?) -> PixivImageURLs {
        PixivImageURLs(
            squareMedium: squareMedium,
            medium: medium,
            large: large,
            original: original ?? url
        )
    }

    func url(for quality: ArtworkImageQuality) -> URL? {
        switch quality {
        case .medium:
            medium ?? large ?? original ?? squareMedium
        case .large:
            large ?? original ?? medium ?? squareMedium
        case .original:
            fullSizeURL
        }
    }

    var fullSizeURL: URL? {
        original ?? large ?? medium ?? squareMedium
    }
}

struct PixivMetaPage: Codable, Hashable, Sendable {
    let imageURLs: PixivImageURLs

    enum CodingKeys: String, CodingKey {
        case imageURLs = "image_urls"
    }
}

struct PixivMetaSinglePage: Codable, Hashable, Sendable {
    let originalImageURL: URL?

    enum CodingKeys: String, CodingKey {
        case originalImageURL = "original_image_url"
    }
}

struct PixivTag: Codable, Identifiable, Hashable, Sendable {
    let name: String
    let translatedName: String?

    var id: String { name }
    var displayName: String { translatedName ?? name }

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }

    init(name: String, translatedName: String? = nil) {
        self.name = name
        self.translatedName = translatedName
    }
}

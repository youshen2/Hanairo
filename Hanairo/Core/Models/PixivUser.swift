import Foundation

enum PixivArtworkType: String, CaseIterable, Identifiable, Codable, Sendable {
    case illustration = "illust"
    case manga

    var id: String { rawValue }
    var title: String { self == .illustration ? "插画" : "漫画" }
}

struct PixivUser: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let account: String
    let profileImageURLs: PixivProfileImageURLs
    let comment: String?
    var isFollowed: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case profileImageURLs = "profile_image_urls"
        case comment
        case isFollowed = "is_followed"
    }

    init(
        id: Int,
        name: String,
        account: String,
        profileImageURLs: PixivProfileImageURLs = .init(medium: nil),
        comment: String? = nil,
        isFollowed: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.account = account
        self.profileImageURLs = profileImageURLs
        self.comment = comment
        self.isFollowed = isFollowed
    }
}

struct PixivProfileImageURLs: Codable, Hashable, Sendable {
    let medium: URL?
}

struct PixivUserProfile: Codable, Hashable, Sendable {
    let webpage: URL?
    let gender: String?
    let birth: String?
    let region: String?
    let job: String?
    let totalFollowUsers: Int
    let totalMyPixivUsers: Int
    let totalIllusts: Int
    let totalManga: Int
    let totalNovels: Int
    let totalPublicBookmarks: Int
    let totalIllustSeries: Int
    let backgroundImageURL: URL?
    let twitterAccount: String?
    let twitterURL: URL?
    let pawooURL: URL?
    let isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case webpage
        case gender
        case birth
        case region
        case job
        case totalFollowUsers = "total_follow_users"
        case totalMyPixivUsers = "total_mypixiv_users"
        case totalIllusts = "total_illusts"
        case totalManga = "total_manga"
        case totalNovels = "total_novels"
        case totalPublicBookmarks = "total_illust_bookmarks_public"
        case totalIllustSeries = "total_illust_series"
        case backgroundImageURL = "background_image_url"
        case twitterAccount = "twitter_account"
        case twitterURL = "twitter_url"
        case pawooURL = "pawoo_url"
        case isPremium = "is_premium"
    }

    init(
        webpage: URL? = nil,
        gender: String? = nil,
        birth: String? = nil,
        region: String? = nil,
        job: String? = nil,
        totalFollowUsers: Int = 0,
        totalMyPixivUsers: Int = 0,
        totalIllusts: Int = 0,
        totalManga: Int = 0,
        totalNovels: Int = 0,
        totalPublicBookmarks: Int = 0,
        totalIllustSeries: Int = 0,
        backgroundImageURL: URL? = nil,
        twitterAccount: String? = nil,
        twitterURL: URL? = nil,
        pawooURL: URL? = nil,
        isPremium: Bool = false
    ) {
        self.webpage = webpage
        self.gender = gender
        self.birth = birth
        self.region = region
        self.job = job
        self.totalFollowUsers = totalFollowUsers
        self.totalMyPixivUsers = totalMyPixivUsers
        self.totalIllusts = totalIllusts
        self.totalManga = totalManga
        self.totalNovels = totalNovels
        self.totalPublicBookmarks = totalPublicBookmarks
        self.totalIllustSeries = totalIllustSeries
        self.backgroundImageURL = backgroundImageURL
        self.twitterAccount = twitterAccount
        self.twitterURL = twitterURL
        self.pawooURL = pawooURL
        self.isPremium = isPremium
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        webpage = container.decodeURLIfPresent(forKey: .webpage)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        birth = try container.decodeIfPresent(String.self, forKey: .birth)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        job = try container.decodeIfPresent(String.self, forKey: .job)
        totalFollowUsers = try container.decodeIfPresent(Int.self, forKey: .totalFollowUsers) ?? 0
        totalMyPixivUsers = try container.decodeIfPresent(Int.self, forKey: .totalMyPixivUsers) ?? 0
        totalIllusts = try container.decodeIfPresent(Int.self, forKey: .totalIllusts) ?? 0
        totalManga = try container.decodeIfPresent(Int.self, forKey: .totalManga) ?? 0
        totalNovels = try container.decodeIfPresent(Int.self, forKey: .totalNovels) ?? 0
        totalPublicBookmarks = try container.decodeIfPresent(Int.self, forKey: .totalPublicBookmarks) ?? 0
        totalIllustSeries = try container.decodeIfPresent(Int.self, forKey: .totalIllustSeries) ?? 0
        backgroundImageURL = container.decodeURLIfPresent(forKey: .backgroundImageURL)
        twitterAccount = try container.decodeIfPresent(String.self, forKey: .twitterAccount)
        twitterURL = container.decodeURLIfPresent(forKey: .twitterURL)
        pawooURL = container.decodeURLIfPresent(forKey: .pawooURL)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
    }
}

private extension KeyedDecodingContainer {
    func decodeURLIfPresent(forKey key: Key) -> URL? {
        guard
            let value = try? decode(String.self, forKey: key),
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return URL(string: value)
    }
}

struct PixivUserDetail: Codable, Hashable, Sendable {
    var user: PixivUser
    let profile: PixivUserProfile
    let workspace: PixivUserWorkspace?
}

struct PixivUserWorkspace: Codable, Hashable, Sendable {
    let computer: String?
    let monitor: String?
    let tool: String?
    let tablet: String?
    let music: String?
    let desk: String?
    let chair: String?
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case computer = "pc"
        case monitor
        case tool
        case tablet
        case music
        case desk
        case chair
        case comment
    }
}

struct PixivUserPreview: Codable, Identifiable, Hashable, Sendable {
    var user: PixivUser
    let illustrations: [PixivIllustration]
    let isMuted: Bool

    var id: Int { user.id }

    enum CodingKeys: String, CodingKey {
        case user
        case illustrations = "illusts"
        case isMuted = "is_muted"
    }

    init(user: PixivUser, illustrations: [PixivIllustration], isMuted: Bool = false) {
        self.user = user
        self.illustrations = illustrations
        self.isMuted = isMuted
    }
}

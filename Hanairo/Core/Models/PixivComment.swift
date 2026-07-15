import Foundation

struct PixivCommentPage: Decodable, Sendable {
    let totalComments: Int
    let comments: [PixivComment]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case totalComments = "total_comments"
        case comments
        case nextURL = "next_url"
    }

    init(totalComments: Int, comments: [PixivComment], nextURL: URL?) {
        self.totalComments = totalComments
        self.comments = comments
        self.nextURL = nextURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalComments = try container.decodeIfPresent(Int.self, forKey: .totalComments) ?? 0
        comments = try container.decodeIfPresent([PixivComment].self, forKey: .comments) ?? []
        let nextURLString = try container.decodeIfPresent(String.self, forKey: .nextURL)
        nextURL = nextURLString.flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    var page: PixivPage<PixivComment> {
        PixivPage(items: comments, nextURL: nextURL)
    }
}

struct PixivComment: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let comment: String
    let date: String
    let user: PixivCommentUser
    let parentComment: PixivParentComment?
    let hasReplies: Bool
    let stamp: PixivCommentStamp?

    enum CodingKeys: String, CodingKey {
        case id
        case comment
        case date
        case user
        case parentComment = "parent_comment"
        case hasReplies = "has_replies"
        case stamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        user = try container.decode(PixivCommentUser.self, forKey: .user)
        parentComment = try container.decodeIfPresent(PixivParentComment.self, forKey: .parentComment)
        hasReplies = try container.decodeIfPresent(Bool.self, forKey: .hasReplies) ?? false
        stamp = try container.decodeIfPresent(PixivCommentStamp.self, forKey: .stamp)
    }

    var displayDate: String {
        String(date.prefix(16)).replacingOccurrences(of: "T", with: " ")
    }
}

struct PixivCommentUser: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let account: String
    let profileImageURLs: PixivProfileImageURLs

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case profileImageURLs = "profile_image_urls"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知用户"
        account = try container.decodeIfPresent(String.self, forKey: .account) ?? ""
        profileImageURLs = try container.decodeIfPresent(
            PixivProfileImageURLs.self,
            forKey: .profileImageURLs
        ) ?? PixivProfileImageURLs(medium: nil)
    }
}

struct PixivParentComment: Decodable, Hashable, Sendable {
    let comment: String
    let user: PixivCommentUser?

    enum CodingKeys: String, CodingKey {
        case comment
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        user = try container.decodeIfPresent(PixivCommentUser.self, forKey: .user)
    }
}

struct PixivCommentStamp: Decodable, Hashable, Sendable {
    let id: Int?
    let url: URL?

    enum CodingKeys: String, CodingKey {
        case id = "stamp_id"
        case url = "stamp_url"
    }
}

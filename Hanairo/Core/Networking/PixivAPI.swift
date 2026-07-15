import Foundation

final class PixivAPI {
    enum RecommendationKind: String, CaseIterable, Identifiable {
        case illustration
        case manga

        var id: String { rawValue }
        var title: String { self == .illustration ? "插画" : "漫画" }
    }

    private let client: NetworkClient
    private let networkSettings: NetworkSettings
    private let decoder = JSONDecoder()

    init(client: NetworkClient, networkSettings: NetworkSettings) {
        self.client = client
        self.networkSettings = networkSettings
    }

    func recommendations(
        kind: RecommendationKind,
        accessToken: String
    ) async throws -> PixivPage<PixivIllustration> {
        let path = kind == .illustration ? "/v1/illust/recommended" : "/v1/manga/recommended"
        let response: IllustrationFeedResponse = try await get(
            path,
            query: ["filter": "for_ios", "include_ranking_label": "true"],
            accessToken: accessToken
        )
        return response.page
    }

    func recommendedUsers(accessToken: String) async throws -> PixivPage<PixivUserPreview> {
        let response: UserPreviewResponse = try await get(
            "/v1/user/recommended",
            query: ["filter": "for_ios"],
            accessToken: accessToken
        )
        return response.page
    }

    func ranking(
        mode: String,
        date: Date?,
        accessToken: String
    ) async throws -> PixivPage<PixivIllustration> {
        var query = ["filter": "for_ios", "mode": mode]
        if let date {
            query["date"] = date.formatted(.iso8601.year().month().day())
        }
        let response: IllustrationFeedResponse = try await get(
            "/v1/illust/ranking",
            query: query,
            accessToken: accessToken
        )
        return response.page
    }

    func following(
        scope: FollowingFeedScope,
        accessToken: String
    ) async throws -> PixivPage<PixivIllustration> {
        let response: IllustrationFeedResponse = try await get(
            "/v2/illust/follow",
            query: ["restrict": scope.rawValue],
            accessToken: accessToken
        )
        return response.page
    }

    func bookmarks(
        userID: Int,
        visibility: PixivVisibility,
        tag: String?,
        accessToken: String
    ) async throws -> PixivPage<PixivIllustration> {
        var query = [
            "user_id": String(userID),
            "restrict": visibility.rawValue
        ]
        if let tag, !tag.isEmpty {
            query["tag"] = tag
        }
        let response: IllustrationFeedResponse = try await get(
            "/v1/user/bookmarks/illust",
            query: query,
            accessToken: accessToken
        )
        return response.page
    }

    func searchIllustrations(
        query: String,
        options: PixivSearchOptions,
        accessToken: String
    ) async throws -> PixivPage<PixivIllustration> {
        var parameters = [
            "filter": "for_ios",
            "merge_plain_keyword_results": "true",
            "search_target": options.target.rawValue,
            "sort": options.sort.rawValue,
            "search_ai_type": String(options.aiFilter.rawValue),
            "word": options.effectiveWord(query)
        ]
        if options.usesDateRange {
            parameters["start_date"] = Self.requestDate(options.startDate)
            parameters["end_date"] = Self.requestDate(options.endDate)
        }
        let response: IllustrationFeedResponse = try await get(
            "/v1/search/illust",
            query: parameters,
            accessToken: accessToken
        )
        return response.page
    }

    func popularPreview(
        query: String,
        options: PixivSearchOptions,
        accessToken: String
    ) async throws -> PixivPage<PixivIllustration> {
        let response: IllustrationFeedResponse = try await get(
            "/v1/search/popular-preview/illust",
            query: [
                "filter": "for_ios",
                "include_translated_tag_results": "true",
                "merge_plain_keyword_results": "true",
                "search_target": options.target.rawValue,
                "word": options.effectiveWord(query)
            ],
            accessToken: accessToken
        )
        return response.page
    }

    func searchAutocomplete(query: String, accessToken: String) async throws -> [PixivTag] {
        let response: SearchAutocompleteResponse = try await get(
            "/v2/search/autocomplete",
            query: [
                "merge_plain_keyword_results": "true",
                "word": query
            ],
            accessToken: accessToken
        )
        return response.tags
    }

    func searchUsers(
        query: String,
        accessToken: String
    ) async throws -> PixivPage<PixivUserPreview> {
        let response: UserPreviewResponse = try await get(
            "/v1/search/user",
            query: ["filter": "for_ios", "word": query],
            accessToken: accessToken
        )
        return response.page
    }

    func trendingTags(accessToken: String) async throws -> [PixivTrendingTag] {
        let response: TrendingTagsResponse = try await get(
            "/v1/trending-tags/illust",
            query: ["filter": "for_ios"],
            accessToken: accessToken
        )
        return response.tags
    }

    func illustration(id: Int, accessToken: String) async throws -> PixivIllustration {
        let response: IllustrationDetailResponse = try await get(
            "/v1/illust/detail",
            query: ["filter": "for_ios", "illust_id": String(id)],
            accessToken: accessToken
        )
        return response.illustration
    }

    func related(to id: Int, accessToken: String) async throws -> PixivPage<PixivIllustration> {
        let response: IllustrationFeedResponse = try await get(
            "/v2/illust/related",
            query: ["filter": "for_ios", "illust_id": String(id)],
            accessToken: accessToken
        )
        return response.page
    }

    func ugoiraMetadata(id: Int, accessToken: String) async throws -> UgoiraMetadata {
        let response: UgoiraMetadataResponse = try await get(
            "/v1/ugoira/metadata",
            query: ["illust_id": String(id)],
            accessToken: accessToken
        )
        return response.metadata
    }

    func comments(illustrationID: Int, accessToken: String) async throws -> PixivCommentPage {
        try await get(
            "/v3/illust/comments",
            query: ["illust_id": String(illustrationID)],
            accessToken: accessToken
        )
    }

    func commentReplies(commentID: Int, accessToken: String) async throws -> PixivCommentPage {
        try await get(
            "/v2/illust/comment/replies",
            query: ["comment_id": String(commentID)],
            accessToken: accessToken
        )
    }

    func comments(nextURL: URL, accessToken: String) async throws -> PixivCommentPage {
        try await get(nextURL, accessToken: accessToken)
    }

    func postComment(
        illustrationID: Int,
        comment: String,
        parentCommentID: Int?,
        accessToken: String
    ) async throws {
        var form = [
            "illust_id": String(illustrationID),
            "comment": comment
        ]
        if let parentCommentID {
            form["parent_comment_id"] = String(parentCommentID)
        }
        try await post("/v1/illust/comment/add", form: form, accessToken: accessToken)
    }

    func user(id: Int, accessToken: String) async throws -> PixivUserDetail {
        try await get(
            "/v1/user/detail",
            query: ["filter": "for_ios", "user_id": String(id)],
            accessToken: accessToken
        )
    }

    func userWorks(
        id: Int,
        type: PixivArtworkType,
        accessToken: String
    ) async throws -> PixivPage<PixivIllustration> {
        let response: IllustrationFeedResponse = try await get(
            "/v1/user/illusts",
            query: ["filter": "for_ios", "user_id": String(id), "type": type.rawValue],
            accessToken: accessToken
        )
        return response.page
    }

    func illustrationSeries(
        id: Int,
        accessToken: String
    ) async throws -> PixivIllustrationSeriesResponse {
        try await get(
            "/v1/illust/series",
            query: ["filter": "for_ios", "illust_series_id": String(id)],
            accessToken: accessToken
        )
    }

    func illustrationSeries(
        nextURL: URL,
        accessToken: String
    ) async throws -> PixivIllustrationSeriesResponse {
        try await get(nextURL, accessToken: accessToken)
    }

    func mangaWatchlist(accessToken: String) async throws -> PixivPage<PixivMangaSeriesSummary> {
        let response: PixivMangaWatchlistResponse = try await get(
            "/v1/watchlist/manga",
            query: [:],
            accessToken: accessToken
        )
        return response.page
    }

    func mangaWatchlist(
        nextURL: URL,
        accessToken: String
    ) async throws -> PixivPage<PixivMangaSeriesSummary> {
        let response: PixivMangaWatchlistResponse = try await get(nextURL, accessToken: accessToken)
        return response.page
    }

    func updateMangaWatchlist(
        seriesID: Int,
        isWatching: Bool,
        accessToken: String
    ) async throws {
        let path = isWatching ? "/v1/watchlist/manga/add" : "/v1/watchlist/manga/delete"
        try await post(
            path,
            form: ["series_id": String(seriesID)],
            accessToken: accessToken
        )
    }

    func illustrations(nextURL: URL, accessToken: String) async throws -> PixivPage<PixivIllustration> {
        let response: IllustrationFeedResponse = try await get(nextURL, accessToken: accessToken)
        return response.page
    }

    func users(nextURL: URL, accessToken: String) async throws -> PixivPage<PixivUserPreview> {
        let response: UserPreviewResponse = try await get(nextURL, accessToken: accessToken)
        return response.page
    }

    func bookmarkDetail(id: Int, accessToken: String) async throws -> PixivBookmarkDetail {
        let response: PixivBookmarkDetailResponse = try await get(
            "/v2/illust/bookmark/detail",
            query: ["illust_id": String(id)],
            accessToken: accessToken
        )
        return response.detail
    }

    func bookmarkTags(
        userID: Int,
        visibility: PixivVisibility,
        accessToken: String
    ) async throws -> PixivPage<PixivBookmarkTag> {
        let response: PixivBookmarkTagResponse = try await get(
            "/v1/user/bookmark-tags/illust",
            query: [
                "user_id": String(userID),
                "restrict": visibility.rawValue
            ],
            accessToken: accessToken
        )
        return response.page
    }

    func bookmarkTags(nextURL: URL, accessToken: String) async throws -> PixivPage<PixivBookmarkTag> {
        let response: PixivBookmarkTagResponse = try await get(nextURL, accessToken: accessToken)
        return response.page
    }

    func userConnections(
        userID: Int,
        kind: UserConnectionKind,
        visibility: PixivVisibility,
        accessToken: String
    ) async throws -> PixivPage<PixivUserPreview> {
        let path = kind == .following ? "/v1/user/following" : "/v1/user/follower"
        let response: UserPreviewResponse = try await get(
            path,
            query: [
                "filter": "for_ios",
                "user_id": String(userID),
                "restrict": visibility.rawValue
            ],
            accessToken: accessToken
        )
        return response.page
    }

    func followDetail(userID: Int, accessToken: String) async throws -> PixivFollowDetail {
        let response: PixivFollowDetailResponse = try await get(
            "/v1/user/follow/detail",
            query: ["user_id": String(userID)],
            accessToken: accessToken
        )
        return response.detail
    }

    func addBookmark(
        id: Int,
        visibility: PixivVisibility,
        tags: [String],
        accessToken: String
    ) async throws {
        var form = [
            "illust_id": String(id),
            "restrict": visibility.rawValue
        ]
        let normalizedTags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !normalizedTags.isEmpty {
            form["tags[]"] = normalizedTags.joined(separator: " ")
        }
        try await post(
            "/v2/illust/bookmark/add",
            form: form,
            accessToken: accessToken
        )
    }

    func removeBookmark(id: Int, accessToken: String) async throws {
        try await post(
            "/v1/illust/bookmark/delete",
            form: ["illust_id": String(id)],
            accessToken: accessToken
        )
    }

    func follow(
        userID: Int,
        visibility: PixivVisibility,
        accessToken: String
    ) async throws {
        try await post(
            "/v1/user/follow/add",
            form: ["user_id": String(userID), "restrict": visibility.rawValue],
            accessToken: accessToken
        )
    }

    func unfollow(userID: Int, accessToken: String) async throws {
        try await post(
            "/v1/user/follow/delete",
            form: ["user_id": String(userID)],
            accessToken: accessToken
        )
    }

    private func get<Response: Decodable>(
        _ path: String,
        query: [String: String],
        accessToken: String
    ) async throws -> Response {
        var components = URLComponents(
            url: networkSettings.apiBaseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw NetworkError.invalidURL }
        return try await get(url, accessToken: accessToken)
    }

    private func get<Response: Decodable>(
        _ url: URL,
        accessToken: String
    ) async throws -> Response {
        var request = URLRequest(url: url)
        APIConfiguration.standardHeaders(accessToken: accessToken).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        let data = try await client.data(for: request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch let error as DecodingError {
            throw NetworkError.decoding(error.hanairoDescription)
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
    }

    private func post(
        _ path: String,
        form: [String: String],
        accessToken: String
    ) async throws {
        var request = URLRequest(url: networkSettings.apiBaseURL.appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = APIConfiguration.formBody(form)
        APIConfiguration.standardHeaders(accessToken: accessToken).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        _ = try await client.data(for: request)
    }

    private static func requestDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private extension DecodingError {
    var hanairoDescription: String {
        switch self {
        case let .dataCorrupted(context):
            return message(context: context)
        case let .keyNotFound(key, context):
            return "字段 \(path(context.codingPath + [key])) 缺失"
        case let .typeMismatch(type, context):
            return "字段 \(path(context.codingPath)) 类型应为 \(type)"
        case let .valueNotFound(type, context):
            return "字段 \(path(context.codingPath)) 缺少 \(type) 值"
        @unknown default:
            return localizedDescription
        }
    }

    private func message(context: Context) -> String {
        let field = path(context.codingPath)
        return field == "响应" ? context.debugDescription : "字段 \(field)：\(context.debugDescription)"
    }

    private func path(_ codingPath: [CodingKey]) -> String {
        let components = codingPath.map { key in
            if let index = key.intValue {
                return "[\(index)]"
            }
            return key.stringValue
        }
        return components.isEmpty ? "响应" : components.joined(separator: ".")
    }
}

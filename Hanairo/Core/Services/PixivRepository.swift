import Foundation
import Observation

@MainActor
@Observable
final class PixivRepository {
    private let api: PixivAPI
    private let authentication: AuthenticationStore
    private let settings: AppSettings
    private let localBlocks: LocalBlockStore
    private let detailCache: ArtworkDetailCache

    private(set) var bookmarkOverrides: [Int: Bool] = [:]
    private(set) var followOverrides: [Int: Bool] = [:]
    private(set) var seriesWatchOverrides: [Int: Bool] = [:]

    init(
        authentication: AuthenticationStore,
        settings: AppSettings,
        localBlocks: LocalBlockStore,
        networkSettings: NetworkSettings,
        sessionProvider: NetworkSessionProvider
    ) {
        api = PixivAPI(
            client: NetworkClient(sessionProvider: sessionProvider),
            networkSettings: networkSettings
        )
        self.authentication = authentication
        self.settings = settings
        self.localBlocks = localBlocks
        detailCache = ArtworkDetailCache(capacityBytes: settings.detailCacheCapacityBytes)
    }

    init(
        api: PixivAPI,
        authentication: AuthenticationStore,
        settings: AppSettings,
        localBlocks: LocalBlockStore
    ) {
        self.api = api
        self.authentication = authentication
        self.settings = settings
        self.localBlocks = localBlocks
        detailCache = ArtworkDetailCache(capacityBytes: settings.detailCacheCapacityBytes)
    }

    func recommendations(kind: PixivAPI.RecommendationKind) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.recommendations(kind: kind, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func recommendedUsers() async throws -> PixivPage<PixivUserPreview> {
        let page = try await authorized { token in
            try await api.recommendedUsers(accessToken: token)
        }
        return applyingOverrides(to: page)
    }

    func ranking(mode: String, date: Date?) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.ranking(mode: mode, date: date, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func bookmarks(
        visibility: PixivVisibility,
        tag: String?
    ) async throws -> PixivPage<PixivIllustration> {
        guard let userID = authentication.userID else {
            throw NetworkError.authenticationRequired
        }
        let page = try await authorized { token in
            try await api.bookmarks(
                userID: userID,
                visibility: visibility,
                tag: tag,
                accessToken: token
            )
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func followingFeed(scope: FollowingFeedScope) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.following(scope: scope, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func bookmarkTags(visibility: PixivVisibility) async throws -> PixivPage<PixivBookmarkTag> {
        guard let userID = authentication.userID else {
            throw NetworkError.authenticationRequired
        }
        return try await authorized { token in
            try await api.bookmarkTags(
                userID: userID,
                visibility: visibility,
                accessToken: token
            )
        }
    }

    func bookmarkTags(nextURL: URL) async throws -> PixivPage<PixivBookmarkTag> {
        try await authorized { token in
            try await api.bookmarkTags(nextURL: nextURL, accessToken: token)
        }
    }

    func bookmarkDetail(id: Int) async throws -> PixivBookmarkDetail {
        let detail = try await authorized { token in
            try await api.bookmarkDetail(id: id, accessToken: token)
        }
        bookmarkOverrides[id] = detail.isBookmarked
        return detail
    }

    func userConnections(
        userID: Int,
        kind: UserConnectionKind,
        visibility: PixivVisibility
    ) async throws -> PixivPage<PixivUserPreview> {
        let page = try await authorized { token in
            try await api.userConnections(
                userID: userID,
                kind: kind,
                visibility: visibility,
                accessToken: token
            )
        }
        return applyingOverrides(to: page)
    }

    func followDetail(userID: Int) async throws -> PixivFollowDetail {
        let detail = try await authorized { token in
            try await api.followDetail(userID: userID, accessToken: token)
        }
        followOverrides[userID] = detail.isFollowed
        return detail
    }

    func searchIllustrations(
        query: String,
        options: PixivSearchOptions
    ) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            if options.sort.requiresPremium, authentication.account?.isPremium != true {
                return try await api.popularPreview(
                    query: query,
                    options: options,
                    accessToken: token
                )
            }
            return try await api.searchIllustrations(
                query: query,
                options: options,
                accessToken: token
            )
        }
        return try await visibleIllustrationPage(startingAt: page) {
            options.mediaFilter.includes($0)
        }
    }

    func searchIllustrations(
        nextURL: URL,
        options: PixivSearchOptions
    ) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.illustrations(nextURL: nextURL, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: page) {
            options.mediaFilter.includes($0)
        }
    }

    func searchUsers(query: String) async throws -> PixivPage<PixivUserPreview> {
        let page = try await authorized { token in
            try await api.searchUsers(query: query, accessToken: token)
        }
        return applyingOverrides(to: page)
    }

    func searchAutocomplete(query: String) async throws -> [PixivTag] {
        try await authorized { token in
            try await api.searchAutocomplete(query: query, accessToken: token)
        }
    }

    func illustrations(nextURL: URL) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.illustrations(nextURL: nextURL, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func users(nextURL: URL) async throws -> PixivPage<PixivUserPreview> {
        let page = try await authorized { token in
            try await api.users(nextURL: nextURL, accessToken: token)
        }
        return applyingOverrides(to: page)
    }

    func trendingTags() async throws -> [PixivTrendingTag] {
        try await authorized { token in
            try await api.trendingTags(accessToken: token)
        }
    }

    func illustration(id: Int) async throws -> PixivIllustration {
        if let cached = await cachedIllustration(id: id) {
            return cached
        }
        return try await refreshIllustration(id: id)
    }

    func cachedIllustration(id: Int) async -> PixivIllustration? {
        guard settings.detailCacheEnabled else { return nil }
        guard let illustration = await detailCache.illustration(
            id: id,
            userID: authentication.userID
        ) else {
            return nil
        }
        return applyingOverrides(to: illustration)
    }

    func refreshIllustration(id: Int) async throws -> PixivIllustration {
        let illustration = try await authorized { token in
            try await api.illustration(id: id, accessToken: token)
        }
        let visibleIllustration = applyingOverrides(to: illustration)
        if settings.detailCacheEnabled {
            await detailCache.store(visibleIllustration, userID: authentication.userID)
        }
        return visibleIllustration
    }

    func related(to id: Int) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.related(to: id, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func ugoiraMetadata(id: Int) async throws -> UgoiraMetadata {
        try await authorized { token in
            try await api.ugoiraMetadata(id: id, accessToken: token)
        }
    }

    func comments(illustrationID: Int) async throws -> PixivCommentPage {
        let page = try await authorized { token in
            try await api.comments(illustrationID: illustrationID, accessToken: token)
        }
        return visibleCommentPage(page)
    }

    func commentReplies(commentID: Int) async throws -> PixivCommentPage {
        let page = try await authorized { token in
            try await api.commentReplies(commentID: commentID, accessToken: token)
        }
        return visibleCommentPage(page)
    }

    func comments(nextURL: URL) async throws -> PixivCommentPage {
        let page = try await authorized { token in
            try await api.comments(nextURL: nextURL, accessToken: token)
        }
        return visibleCommentPage(page)
    }

    func postComment(illustrationID: Int, comment: String, parentCommentID: Int?) async throws {
        try await authorized { token in
            try await api.postComment(
                illustrationID: illustrationID,
                comment: comment,
                parentCommentID: parentCommentID,
                accessToken: token
            )
        }
    }

    private func visibleCommentPage(_ page: PixivCommentPage) -> PixivCommentPage {
        PixivCommentPage(
            totalComments: page.totalComments,
            comments: page.comments.filter { !localBlocks.isBlocked($0) },
            nextURL: page.nextURL
        )
    }

    func user(id: Int) async throws -> PixivUserDetail {
        var detail = try await authorized { token in
            try await api.user(id: id, accessToken: token)
        }
        detail.user = applyingOverrides(to: detail.user)
        return detail
    }

    func userWorks(
        id: Int,
        type: PixivArtworkType
    ) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.userWorks(id: id, type: type, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func publicBookmarks(userID: Int) async throws -> PixivPage<PixivIllustration> {
        let page = try await authorized { token in
            try await api.bookmarks(
                userID: userID,
                visibility: .public,
                tag: nil,
                accessToken: token
            )
        }
        return try await visibleIllustrationPage(startingAt: page)
    }

    func illustrationSeries(id: Int) async throws -> PixivIllustrationSeriesResult {
        let response = try await authorized { token in
            try await api.illustrationSeries(id: id, accessToken: token)
        }
        guard var detail = response.detail else {
            throw NetworkError.decoding("系列详情不存在")
        }
        if let override = seriesWatchOverrides[id] {
            detail.watchlistAdded = override
        } else {
            seriesWatchOverrides[id] = detail.watchlistAdded
        }
        let page = try await visibleIllustrationPage(startingAt: response.page)
        return PixivIllustrationSeriesResult(detail: detail, page: page)
    }

    func illustrationSeries(nextURL: URL) async throws -> PixivPage<PixivIllustration> {
        let response = try await authorized { token in
            try await api.illustrationSeries(nextURL: nextURL, accessToken: token)
        }
        return try await visibleIllustrationPage(startingAt: response.page)
    }

    func mangaWatchlist() async throws -> PixivPage<PixivMangaSeriesSummary> {
        let page = try await authorized { token in
            try await api.mangaWatchlist(accessToken: token)
        }
        page.items.forEach { seriesWatchOverrides[$0.id] = true }
        return page
    }

    func mangaWatchlist(nextURL: URL) async throws -> PixivPage<PixivMangaSeriesSummary> {
        let page = try await authorized { token in
            try await api.mangaWatchlist(nextURL: nextURL, accessToken: token)
        }
        page.items.forEach { seriesWatchOverrides[$0.id] = true }
        return page
    }

    func setSeriesWatched(seriesID: Int, isWatching: Bool) async throws {
        try await authorized { token in
            try await api.updateMangaWatchlist(
                seriesID: seriesID,
                isWatching: isWatching,
                accessToken: token
            )
        }
        seriesWatchOverrides[seriesID] = isWatching
    }

    func seriesWatchState(seriesID: Int, fallback: Bool) -> Bool {
        seriesWatchOverrides[seriesID] ?? fallback
    }

    func toggleBookmark(_ illustration: PixivIllustration) async throws -> Bool {
        let newValue = !bookmarkState(for: illustration)
        if newValue {
            try await updateBookmark(
                id: illustration.id,
                visibility: settings.defaultBookmarkVisibility,
                tags: []
            )
        } else {
            try await removeBookmark(id: illustration.id)
        }
        return newValue
    }

    func updateBookmark(
        id: Int,
        visibility: PixivVisibility,
        tags: [String]
    ) async throws {
        try await authorized { token in
            try await api.addBookmark(
                id: id,
                visibility: visibility,
                tags: tags,
                accessToken: token
            )
        }
        bookmarkOverrides[id] = true
        await updateCachedBookmarkState(id: id, isBookmarked: true)
    }

    func removeBookmark(id: Int) async throws {
        try await authorized { token in
            try await api.removeBookmark(id: id, accessToken: token)
        }
        bookmarkOverrides[id] = false
        await updateCachedBookmarkState(id: id, isBookmarked: false)
    }

    func bookmarkState(for illustration: PixivIllustration) -> Bool {
        bookmarkOverrides[illustration.id] ?? illustration.isBookmarked
    }

    func clearDetailCache() async {
        await detailCache.clear()
    }

    func detailCacheUsage() async -> CacheUsage {
        await detailCache.usage()
    }

    func updateDetailCacheCapacity() async {
        await detailCache.updateCapacityBytes(settings.detailCacheCapacityBytes)
    }

    func toggleFollow(_ user: PixivUser) async throws -> Bool {
        let newValue = !followState(for: user)
        try await setFollow(
            userID: user.id,
            isFollowed: newValue,
            visibility: settings.defaultFollowVisibility
        )
        return newValue
    }

    func setFollow(
        userID: Int,
        isFollowed: Bool,
        visibility: PixivVisibility
    ) async throws {
        try await authorized { token in
            if isFollowed {
                try await api.follow(
                    userID: userID,
                    visibility: visibility,
                    accessToken: token
                )
            } else {
                try await api.unfollow(userID: userID, accessToken: token)
            }
        }
        followOverrides[userID] = isFollowed
    }

    func followState(for user: PixivUser) -> Bool {
        followOverrides[user.id] ?? user.isFollowed == true
    }

    private func filtered(
        _ illustrations: [PixivIllustration],
        matching predicate: (PixivIllustration) -> Bool = { _ in true }
    ) -> [PixivIllustration] {
        illustrations.filter { illustration in
            (settings.showsAIArtwork || illustration.aiType != 2)
                && (settings.showsMatureArtwork || illustration.xRestrict == 0)
                && !illustration.isMuted
                && !localBlocks.isBlocked(illustration)
                && predicate(illustration)
        }
        .map(applyingOverrides(to:))
    }

    private func applyingOverrides(to illustration: PixivIllustration) -> PixivIllustration {
        var illustration = illustration
        illustration.isBookmarked = bookmarkState(for: illustration)
        illustration.user = applyingOverrides(to: illustration.user)
        return illustration
    }

    private func applyingOverrides(to user: PixivUser) -> PixivUser {
        var user = user
        if let override = followOverrides[user.id] {
            user.isFollowed = override
        }
        return user
    }

    private func applyingOverrides(
        to page: PixivPage<PixivUserPreview>
    ) -> PixivPage<PixivUserPreview> {
        let items = page.items
            .filter { !$0.isMuted && !localBlocks.isBlocked($0.user) }
            .map { preview in
                PixivUserPreview(
                    user: applyingOverrides(to: preview.user),
                    illustrations: filtered(preview.illustrations),
                    isMuted: preview.isMuted
                )
            }
        return PixivPage(items: items, nextURL: page.nextURL)
    }

    private func updateCachedBookmarkState(id: Int, isBookmarked: Bool) async {
        guard settings.detailCacheEnabled,
              var illustration = await detailCache.illustration(
                id: id,
                userID: authentication.userID
              ) else {
            return
        }
        illustration.isBookmarked = isBookmarked
        await detailCache.store(illustration, userID: authentication.userID)
    }

    private func visibleIllustrationPage(
        startingAt initialPage: PixivPage<PixivIllustration>,
        matching predicate: (PixivIllustration) -> Bool = { _ in true }
    ) async throws -> PixivPage<PixivIllustration> {
        var page = initialPage
        var visitedURLs = Set<URL>()

        while true {
            let visibleItems = filtered(page.items, matching: predicate)
            guard visibleItems.isEmpty, let nextURL = page.nextURL else {
                return PixivPage(items: visibleItems, nextURL: page.nextURL)
            }
            guard visitedURLs.insert(nextURL).inserted else {
                return PixivPage(items: [], nextURL: nil)
            }
            try Task.checkCancellation()
            page = try await authorized { token in
                try await api.illustrations(nextURL: nextURL, accessToken: token)
            }
        }
    }

    private func authorized<Value>(
        operation: (String) async throws -> Value
    ) async throws -> Value {
        let token = try await authentication.validAccessToken()
        do {
            return try await operation(token)
        } catch NetworkError.server(let statusCode, _) where statusCode == 401 {
            let refreshedToken = try await authentication.refreshAccessToken()
            return try await operation(refreshedToken)
        }
    }
}

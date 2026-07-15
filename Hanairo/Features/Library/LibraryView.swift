import SwiftUI

struct LibraryView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository

    @State private var section: LibrarySection = .bookmarks
    @State private var bookmarkVisibility: PixivVisibility = .public
    @State private var selectedBookmarkTag: String?
    @State private var followingScope: FollowingFeedScope = .all
    @State private var followingVisibility: PixivVisibility = .public
    @State private var illustrations = PaginatedStore<PixivIllustration>(id: { $0.id })
    @State private var users = PaginatedStore<PixivUserPreview>(id: { $0.id })
    @State private var bookmarkTags = PaginatedStore<PixivBookmarkTag>(id: { $0.id })
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                sectionPicker
                activeFilter
                activeContent
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            await refresh()
        }
        .navigationTitle("收藏与关注")
        .task(id: requestKey) {
            await loadIfNeeded()
        }
        .task(id: tagRequestKey) {
            guard section == .bookmarks else { return }
            await loadBookmarkTagsIfNeeded()
        }
        .onChange(of: bookmarkVisibility) {
            selectedBookmarkTag = nil
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(displayedError ?? "未知错误")
        }
    }

    private var sectionPicker: some View {
        Picker("内容", selection: $section) {
            ForEach(LibrarySection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var activeFilter: some View {
        switch section {
        case .bookmarks:
            Picker("收藏范围", selection: $bookmarkVisibility) {
                ForEach(PixivVisibility.allCases) { visibility in
                    Text(visibility.title).tag(visibility)
                }
            }
            .pickerStyle(.segmented)

            BookmarkTagFilterView(
                tags: bookmarkTags.items,
                phase: bookmarkTags.phase,
                isLoadingMore: bookmarkTags.isLoadingMore,
                errorMessage: bookmarkTags.loadMoreError,
                selection: $selectedBookmarkTag,
                onRetry: retryBookmarkTags,
                onLoadMore: loadMoreBookmarkTags
            )
        case .followingFeed:
            Picker("关注范围", selection: $followingScope) {
                ForEach(FollowingFeedScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
        case .followingUsers:
            Picker("关注范围", selection: $followingVisibility) {
                ForEach(PixivVisibility.allCases) { visibility in
                    Text(visibility.title).tag(visibility)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var activeContent: some View {
        switch section {
        case .bookmarks, .followingFeed:
            illustrationContent
        case .followingUsers:
            userContent
        }
    }

    @ViewBuilder
    private var illustrationContent: some View {
        switch illustrations.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if illustrations.items.isEmpty {
                ContentUnavailableView(
                    section == .bookmarks ? "还没有收藏" : "暂无关注动态",
                    systemImage: section == .bookmarks ? "heart" : "person.2"
                )
                .frame(minHeight: 360)
            } else {
                ArtworkGrid(
                    illustrations: illustrations.items,
                    onLoadMore: loadMoreIllustrations
                ) { id in
                    await toggleBookmark(id: id)
                }
                PaginationStatusView(
                    isLoading: illustrations.isLoadingMore,
                    errorMessage: illustrations.loadMoreError,
                    onRetry: loadMoreIllustrations
                )
            }
        }
    }

    @ViewBuilder
    private var userContent: some View {
        switch users.phase {
        case .idle, .loading:
            ProgressView("正在加载关注用户…")
                .frame(maxWidth: .infinity, minHeight: 360)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if users.items.isEmpty {
                ContentUnavailableView("暂无关注用户", systemImage: "person.2")
                    .frame(minHeight: 360)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(users.items) { preview in
                        UserRow(
                            preview: preview,
                            showsFollowButton: true
                        ) { isFollowed in
                            if !isFollowed {
                                users.removeItem(id: preview.id)
                            }
                        }
                        .task {
                            guard preview.id == users.items.last?.id else { return }
                            await loadMoreUsers()
                        }
                    }
                }
                PaginationStatusView(
                    isLoading: users.isLoadingMore,
                    errorMessage: users.loadMoreError,
                    onRetry: loadMoreUsers
                )
            }
        }
    }

    private var requestKey: String {
        let userID = authentication.userID ?? 0
        switch section {
        case .bookmarks:
            return "\(userID)-bookmarks-\(bookmarkVisibility.rawValue)-\(selectedBookmarkTag ?? "all")"
        case .followingFeed:
            return "\(userID)-feed-\(followingScope.rawValue)"
        case .followingUsers:
            return "\(userID)-users-\(followingVisibility.rawValue)"
        }
    }

    private var tagRequestKey: String {
        "\(authentication.userID ?? 0)-tags-\(bookmarkVisibility.rawValue)"
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { displayedError != nil },
            set: {
                if !$0 {
                    actionError = nil
                    illustrations.clearRefreshError()
                    users.clearRefreshError()
                }
            }
        )
    }

    private var displayedError: String? {
        actionError ?? activeRefreshError
    }

    private var activeRefreshError: String? {
        section == .followingUsers ? users.refreshError : illustrations.refreshError
    }

    private func loadIfNeeded() async {
        let key = requestKey
        switch section {
        case .bookmarks:
            let visibility = bookmarkVisibility
            let tag = selectedBookmarkTag
            await illustrations.loadIfNeeded(requestKey: key) {
                try await repository.bookmarks(visibility: visibility, tag: tag)
            }
        case .followingFeed:
            let scope = followingScope
            await illustrations.loadIfNeeded(requestKey: key) {
                try await repository.followingFeed(scope: scope)
            }
        case .followingUsers:
            guard let userID = authentication.userID else { return }
            let visibility = followingVisibility
            await users.loadIfNeeded(requestKey: key) {
                try await repository.userConnections(
                    userID: userID,
                    kind: .following,
                    visibility: visibility
                )
            }
        }
    }

    private func refresh() async {
        let key = requestKey
        switch section {
        case .bookmarks:
            let visibility = bookmarkVisibility
            let tag = selectedBookmarkTag
            async let feed: Void = illustrations.reload(
                requestKey: key,
                showsInitialLoading: false
            ) {
                try await repository.bookmarks(visibility: visibility, tag: tag)
            }
            async let tags: Void = reloadBookmarkTags(showsInitialLoading: false)
            _ = await (feed, tags)
        case .followingFeed:
            let scope = followingScope
            await illustrations.reload(requestKey: key, showsInitialLoading: false) {
                try await repository.followingFeed(scope: scope)
            }
        case .followingUsers:
            guard let userID = authentication.userID else { return }
            let visibility = followingVisibility
            await users.reload(requestKey: key, showsInitialLoading: false) {
                try await repository.userConnections(
                    userID: userID,
                    kind: .following,
                    visibility: visibility
                )
            }
        }
    }

    private func retry() async {
        let key = requestKey
        switch section {
        case .bookmarks:
            let visibility = bookmarkVisibility
            let tag = selectedBookmarkTag
            await illustrations.reload(requestKey: key, showsInitialLoading: true) {
                try await repository.bookmarks(visibility: visibility, tag: tag)
            }
        case .followingFeed:
            let scope = followingScope
            await illustrations.reload(requestKey: key, showsInitialLoading: true) {
                try await repository.followingFeed(scope: scope)
            }
        case .followingUsers:
            guard let userID = authentication.userID else { return }
            let visibility = followingVisibility
            await users.reload(requestKey: key, showsInitialLoading: true) {
                try await repository.userConnections(
                    userID: userID,
                    kind: .following,
                    visibility: visibility
                )
            }
        }
    }

    private func loadMoreIllustrations() async {
        let key = requestKey
        await illustrations.loadMore(requestKey: key) { nextURL in
            try await repository.illustrations(nextURL: nextURL)
        }
    }

    private func loadMoreUsers() async {
        let key = requestKey
        await users.loadMore(requestKey: key) { nextURL in
            try await repository.users(nextURL: nextURL)
        }
    }

    private func loadBookmarkTagsIfNeeded() async {
        let key = tagRequestKey
        let visibility = bookmarkVisibility
        await bookmarkTags.loadIfNeeded(requestKey: key) {
            try await repository.bookmarkTags(visibility: visibility)
        }
    }

    private func retryBookmarkTags() async {
        await reloadBookmarkTags(showsInitialLoading: true)
    }

    private func reloadBookmarkTags(showsInitialLoading: Bool) async {
        let key = tagRequestKey
        let visibility = bookmarkVisibility
        await bookmarkTags.reload(requestKey: key, showsInitialLoading: showsInitialLoading) {
            try await repository.bookmarkTags(visibility: visibility)
        }
    }

    private func loadMoreBookmarkTags() async {
        let key = tagRequestKey
        await bookmarkTags.loadMore(requestKey: key) { nextURL in
            try await repository.bookmarkTags(nextURL: nextURL)
        }
    }

    private func toggleBookmark(id: Int) async {
        guard let illustration = illustrations.item(id: id) else { return }
        do {
            let newValue = try await repository.toggleBookmark(illustration)
            if section == .bookmarks, !newValue {
                illustrations.removeItem(id: id)
            } else {
                illustrations.updateItem(id: id) { $0.isBookmarked = newValue }
            }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }
}

#Preview("收藏") {
    NavigationStack {
        LibraryView()
    }
    .withPreviewDependencies()
}

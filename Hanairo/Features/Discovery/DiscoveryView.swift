import SwiftUI

struct DiscoveryView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks

    @State private var kind: PixivAPI.RecommendationKind = .illustration
    @State private var feed = PaginatedStore<PixivIllustration>(id: { $0.id })
    @State private var recommendedUsers = PaginatedStore<PixivUserPreview>(id: { $0.id })
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Picker("作品类型", selection: $kind) {
                    ForEach(PixivAPI.RecommendationKind.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                content
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("Hanairo")
        .toolbar { accountToolbar }
        .task(id: requestKey) {
            await loadIfNeeded()
        }
        .refreshable {
            await refresh()
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(displayedError ?? "未知错误")
        }
    }

    @ViewBuilder
    private var recommendedUserSection: some View {
        switch recommendedUsers.phase {
        case .idle, .loading:
            ProgressView("正在发现作者…")
                .frame(maxWidth: .infinity, minHeight: 72)
        case .failed:
            EmptyView()
        case .loaded:
            if !visibleRecommendedUsers.isEmpty {
                HStack {
                    Text("推荐作者")
                        .font(.title3.weight(.bold))
                    Spacer()
                    NavigationLink("查看全部", value: AppRoute.recommendedUsers)
                        .font(.subheadline)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(visibleRecommendedUsers.prefix(10)) { preview in
                            RecommendedUserCard(preview: preview)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch feed.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if visibleFeedItems.isEmpty {
                ContentUnavailableView("暂无推荐", systemImage: "sparkles")
                    .frame(minHeight: 360)
            } else {
                FeaturedArtworkView(illustration: visibleFeedItems[0]) {
                    await toggleBookmark(id: visibleFeedItems[0].id)
                }
                .task {
                    guard visibleFeedItems.count == 1 else { return }
                    await loadMore()
                }
                recommendedUserSection
                Text("更多推荐")
                    .font(.title2.weight(.bold))
                ArtworkMasonryGrid(
                    illustrations: Array(visibleFeedItems.dropFirst()),
                    onLoadMore: loadMore
                ) { id in
                    await toggleBookmark(id: id)
                }
                PaginationStatusView(
                    isLoading: feed.isLoadingMore,
                    errorMessage: feed.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var accountToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if
                let account = authentication.account,
                let id = account.numericID
            {
                NavigationLink(value: AppRoute.user(id: id)) {
                    RemoteImageView(
                        url: account.profileImageURLs.large ?? account.profileImageURLs.medium
                    )
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .clipped()
                }
                .accessibilityLabel("我的主页")
            }
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { displayedError != nil },
            set: {
                if !$0 {
                    actionError = nil
                    feed.clearRefreshError()
                }
            }
        )
    }

    private var displayedError: String? {
        actionError ?? feed.refreshError ?? recommendedUsers.refreshError
    }

    private var requestKey: String {
        "\(kind.rawValue)-\(authentication.userID ?? 0)"
    }

    private func loadIfNeeded() async {
        let activeRequestKey = requestKey
        let activeKind = kind
        let activeUserRequestKey = userRequestKey
        async let artworkTask: Void = feed.loadIfNeeded(requestKey: activeRequestKey) {
            try await repository.recommendations(kind: activeKind)
        }
        async let userTask: Void = recommendedUsers.loadIfNeeded(requestKey: activeUserRequestKey) {
            try await repository.recommendedUsers()
        }
        _ = await (artworkTask, userTask)
    }

    private func refresh() async {
        let activeRequestKey = requestKey
        let activeKind = kind
        let activeUserRequestKey = userRequestKey
        async let artworkTask: Void = feed.reload(requestKey: activeRequestKey, showsInitialLoading: false) {
            try await repository.recommendations(kind: activeKind)
        }
        async let userTask: Void = recommendedUsers.reload(
            requestKey: activeUserRequestKey,
            showsInitialLoading: false
        ) {
            try await repository.recommendedUsers()
        }
        _ = await (artworkTask, userTask)
    }

    private func retry() async {
        let activeRequestKey = requestKey
        let activeKind = kind
        await feed.reload(requestKey: activeRequestKey, showsInitialLoading: true) {
            try await repository.recommendations(kind: activeKind)
        }
    }

    private func loadMore() async {
        let activeRequestKey = requestKey
        await feed.loadMore(requestKey: activeRequestKey) { nextURL in
            try await repository.illustrations(nextURL: nextURL)
        }
    }

    private func toggleBookmark(id: Int) async {
        guard let illustration = feed.item(id: id) else { return }
        do {
            let isBookmarked = try await repository.toggleBookmark(illustration)
            feed.updateItem(id: id) { $0.isBookmarked = isBookmarked }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    private var userRequestKey: String {
        "recommended-users-\(authentication.userID ?? 0)"
    }

    private var visibleFeedItems: [PixivIllustration] {
        feed.items.filter { !localBlocks.isBlocked($0) }
    }

    private var visibleRecommendedUsers: [PixivUserPreview] {
        recommendedUsers.items.filter { !localBlocks.isBlocked($0.user) }
    }
}

private struct RecommendedUserCard: View {
    let preview: PixivUserPreview

    var body: some View {
        VStack(spacing: 8) {
            NavigationLink(value: AppRoute.user(id: preview.user.id)) {
                VStack(spacing: 8) {
                    RemoteImageView(url: preview.user.profileImageURLs.medium)
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                        .clipped()
                    Text(preview.user.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(width: 116)
                }
            }
            .buttonStyle(.plain)
            FollowButton(user: preview.user, compact: true)
        }
        .padding(12)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct FeaturedArtworkView: View {
    @Environment(PixivRepository.self) private var repository

    let illustration: PixivIllustration
    let onBookmark: () async -> Void
    @State private var isChangingBookmark = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            NavigationLink(value: AppRoute.illustration(id: illustration.id)) {
                RemoteImageView(
                    url: illustration.previewURL
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(illustration.aspectRatio > 0 ? illustration.aspectRatio : 0.75, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text("今日灵感")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.75))
                Text(illustration.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(illustration.user.name)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(20)
            .padding(.trailing, 50)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                guard !isChangingBookmark else { return }
                isChangingBookmark = true
                Task {
                    await onBookmark()
                    isChangingBookmark = false
                }
            } label: {
                Image(systemName: isBookmarked ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        isBookmarked
                            ? AnyShapeStyle(.tint)
                            : AnyShapeStyle(.white)
                    )
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    private var isBookmarked: Bool {
        repository.bookmarkState(for: illustration)
    }
}

#Preview("推荐预览") {
    NavigationStack {
        DiscoveryView()
    }
    .withPreviewDependencies()
}

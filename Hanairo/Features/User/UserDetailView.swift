import SwiftUI

struct UserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks
    @Environment(AppSettings.self) private var settings
    @Environment(AppTheme.self) private var theme

    let userID: Int

    @State private var detailState: LoadState<PixivUserDetail> = .idle
    @State private var completedDetailRequestKey: String?
    @State private var selectedSection: AuthorArtworkSection = .illustrations
    @State private var artworks = PaginatedStore<PixivIllustration>(id: { $0.id })
    @State private var actionError: String?
    @State private var showsBlockConfirmation = false
    @State private var profileAccentColor: Color?

    var body: some View {
        Group {
            switch detailState {
            case .idle, .loading:
                ProgressView("正在加载作者…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                ErrorStateView(message: message, usesGlassButton: true) {
                    Task { await retryDetail() }
                }
            case let .loaded(detail):
                userContent(detail)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .tint(profileAccentColor ?? theme.accentColor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: PixivWebLinks.user(id: userID)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("分享作者主页")
            }

            if
                case let .loaded(detail) = detailState,
                authentication.userID != detail.user.id
            {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(
                            "屏蔽作者",
                            systemImage: "person.crop.circle.badge.minus",
                            role: .destructive
                        ) {
                            showsBlockConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多操作")
                }
            }
        }
        .task(id: detailRequestKey) {
            await loadDetailIfNeeded()
        }
        .task(id: artworkRequestKey) {
            await loadArtworksIfNeeded()
        }
        .task(id: profileThemeImageURL) {
            await updateProfileAccent()
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(displayedError ?? "未知错误")
        }
        .confirmationDialog(
            "屏蔽这位作者？",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("屏蔽作者", role: .destructive) {
                guard case let .loaded(detail) = detailState else { return }
                localBlocks.block(user: detail.user)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该作者的作品与用户条目将在 Hanairo 中隐藏。")
        }
    }

    private func userContent(_ detail: PixivUserDetail) -> some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    UserProfileHeaderView(
                        detail: detail,
                        isCurrentUser: authentication.userID == detail.user.id
                    )

                    UserProfileDetailsView(detail: detail)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        Picker("作者内容", selection: $selectedSection) {
                            ForEach(AuthorArtworkSection.allCases) { section in
                                Text(section.title).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)

                        artworkContent(detail)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
                .background(alignment: .top) {
                    ProgressiveFadeImageView(url: backgroundURL(for: detail))
                        .frame(width: proxy.size.width, height: backgroundHeight(in: proxy))
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await refresh()
            }
        }
        .background(Color.secondary.opacity(0.055))
#if os(iOS)
        .ignoresSafeArea(edges: .top)
#endif
    }

    private func backgroundURL(for detail: PixivUserDetail) -> URL? {
        detail.profile.backgroundImageURL
            ?? artworks.items.first?.previewURL
            ?? detail.user.profileImageURLs.medium
    }

    private func backgroundHeight(in proxy: GeometryProxy) -> CGFloat {
        max(proxy.size.height * settings.profileBackgroundScreenRatio, 300)
    }

    @ViewBuilder
    private func artworkContent(_ detail: PixivUserDetail) -> some View {
        HStack {
            Text(selectedSection.heading)
                .font(.title2.weight(.bold))
            Spacer()
            Text(selectedSection.count(in: detail.profile), format: .number)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }

        switch artworks.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message, usesGlassButton: true) {
                Task { await retryArtworks() }
            }
            .frame(minHeight: 260)
        case .loaded:
            if artworks.items.isEmpty {
                ContentUnavailableView(selectedSection.emptyTitle, systemImage: selectedSection.systemImage)
                    .frame(minHeight: 260)
            } else {
                ArtworkGrid(
                    illustrations: artworks.items,
                    onLoadMore: loadMoreArtworks
                ) { id in
                    await toggleBookmark(id: id)
                }
                PaginationStatusView(
                    isLoading: artworks.isLoadingMore,
                    errorMessage: artworks.loadMoreError,
                    usesGlassButton: true,
                    onRetry: loadMoreArtworks
                )
            }
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { displayedError != nil },
            set: {
                if !$0 {
                    actionError = nil
                    artworks.clearRefreshError()
                }
            }
        )
    }

    private var displayedError: String? {
        actionError ?? artworks.refreshError
    }

    private var navigationTitle: String {
        if case .loaded = detailState {
            return ""
        }
        return "作者主页"
    }

    private var detailRequestKey: String {
        "user-detail|\(userID)|\(authentication.userID ?? 0)"
    }

    private var artworkRequestKey: String {
        "user-artworks|\(userID)|\(selectedSection.rawValue)|\(authentication.userID ?? 0)"
    }

    private var profileThemeImageURL: URL? {
        guard case let .loaded(detail) = detailState else { return nil }
        return detail.user.profileImageURLs.medium
    }

    private func updateProfileAccent() async {
        let activeURL = profileThemeImageURL
        guard let activeURL else {
            profileAccentColor = nil
            return
        }
        let color = await theme.accentColor(for: activeURL)
        guard !Task.isCancelled, activeURL == profileThemeImageURL else { return }
        profileAccentColor = color
    }

    private func loadDetailIfNeeded() async {
        guard completedDetailRequestKey != detailRequestKey else { return }
        await loadDetail(showsLoading: true)
    }

    private func loadArtworksIfNeeded() async {
        let activeRequestKey = artworkRequestKey
        let activeSection = selectedSection
        let activeUserID = userID
        await artworks.loadIfNeeded(requestKey: activeRequestKey) {
            try await firstPage(for: activeSection, userID: activeUserID)
        }
    }

    private func loadDetail(showsLoading: Bool) async {
        let activeRequestKey = detailRequestKey
        if showsLoading {
            detailState = .loading
        }
        do {
            let detail = try await repository.user(id: userID)
            guard !Task.isCancelled, activeRequestKey == detailRequestKey else { return }
            detailState = .loaded(detail)
            completedDetailRequestKey = activeRequestKey
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestKey == detailRequestKey else { return }
            if showsLoading {
                detailState = .failed(error.localizedDescription)
            } else {
                actionError = error.localizedDescription
            }
        }
    }

    private func refresh() async {
        let activeRequestKey = artworkRequestKey
        let activeSection = selectedSection
        let activeUserID = userID
        async let detailTask: Void = loadDetail(showsLoading: false)
        async let artworkTask: Void = artworks.reload(
            requestKey: activeRequestKey,
            showsInitialLoading: false
        ) {
            try await firstPage(for: activeSection, userID: activeUserID)
        }
        _ = await (detailTask, artworkTask)
    }

    private func retryDetail() async {
        await loadDetail(showsLoading: true)
    }

    private func retryArtworks() async {
        let activeRequestKey = artworkRequestKey
        let activeSection = selectedSection
        let activeUserID = userID
        await artworks.reload(requestKey: activeRequestKey, showsInitialLoading: true) {
            try await firstPage(for: activeSection, userID: activeUserID)
        }
    }

    private func loadMoreArtworks() async {
        let activeRequestKey = artworkRequestKey
        await artworks.loadMore(requestKey: activeRequestKey) { nextURL in
            try await repository.illustrations(nextURL: nextURL)
        }
    }

    private func firstPage(
        for section: AuthorArtworkSection,
        userID: Int
    ) async throws -> PixivPage<PixivIllustration> {
        switch section {
        case .illustrations:
            try await repository.userWorks(id: userID, type: .illustration)
        case .manga:
            try await repository.userWorks(id: userID, type: .manga)
        case .bookmarks:
            try await repository.publicBookmarks(userID: userID)
        }
    }

    private func toggleBookmark(id: Int) async {
        guard let illustration = artworks.item(id: id) else { return }
        do {
            let isBookmarked = try await repository.toggleBookmark(illustration)
            artworks.updateItem(id: id) { $0.isBookmarked = isBookmarked }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }
}

private enum AuthorArtworkSection: String, CaseIterable, Identifiable {
    case illustrations
    case manga
    case bookmarks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrations: "插画"
        case .manga: "漫画"
        case .bookmarks: "收藏"
        }
    }

    var heading: String {
        switch self {
        case .illustrations: "作品"
        case .manga: "漫画"
        case .bookmarks: "收藏"
        }
    }

    func count(in profile: PixivUserProfile) -> Int {
        switch self {
        case .illustrations: profile.totalIllusts
        case .manga: profile.totalManga
        case .bookmarks: profile.totalPublicBookmarks
        }
    }

    var emptyTitle: String {
        switch self {
        case .illustrations: "暂无公开插画"
        case .manga: "暂无公开漫画"
        case .bookmarks: "暂无公开收藏"
        }
    }

    var systemImage: String {
        switch self {
        case .illustrations: "photo.on.rectangle.angled"
        case .manga: "book.pages"
        case .bookmarks: "heart"
        }
    }
}

#Preview("作者主页") {
    NavigationStack {
        UserDetailView(userID: 101)
    }
    .withPreviewDependencies()
}

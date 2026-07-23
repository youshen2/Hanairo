import SwiftUI

struct IllustrationSeriesView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository

    let seriesID: Int

    @State private var store = IllustrationSeriesStore()
    @State private var isChangingWatch = false

    var body: some View {
        Group {
            switch store.detailState {
            case .idle, .loading:
                ProgressView("正在加载系列…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                ErrorStateView(message: message) {
                    Task { await retry() }
                }
            case let .loaded(detail):
                seriesContent(detail)
            }
        }
        .navigationTitle("插画系列")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: requestKey) {
            await store.loadIfNeeded(
                seriesID: seriesID,
                userID: authentication.userID,
                repository: repository
            )
        }
        .toolbar {
            if let shareURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("分享系列")
                }
            }
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(displayedError ?? "未知错误")
        }
    }

    private func seriesContent(_ detail: PixivIllustrationSeriesDetail) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                IllustrationSeriesHeader(
                    detail: detail,
                    isWatching: repository.seriesWatchState(
                        seriesID: detail.id,
                        fallback: detail.watchlistAdded
                    ),
                    isWorking: isChangingWatch,
                    onToggleWatch: toggleWatch
                )

                Text("系列作品")
                    .font(.title2.weight(.bold))

                worksContent
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            await store.refresh(
                seriesID: seriesID,
                userID: authentication.userID,
                repository: repository
            )
        }
    }

    @ViewBuilder
    private var worksContent: some View {
        switch store.works.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 260)
        case .loaded:
            if store.works.items.isEmpty {
                ContentUnavailableView("系列暂无作品", systemImage: "books.vertical")
                    .frame(minHeight: 260)
            } else {
                ArtworkGrid(
                    illustrations: store.works.items,
                    onLoadMore: loadMore
                ) { id in
                    await store.toggleBookmark(id: id, repository: repository)
                }
                PaginationStatusView(
                    isLoading: store.works.isLoadingMore,
                    errorMessage: store.works.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    private var requestKey: String {
        "\(seriesID)-\(authentication.userID ?? 0)"
    }

    private var shareURL: URL? {
        guard case let .loaded(detail) = store.detailState,
              let userID = detail.user?.id else {
            return nil
        }
        return URL(string: "https://www.pixiv.net/user/\(userID)/series/\(detail.id)")
    }

    private var displayedError: String? {
        store.actionError ?? store.works.refreshError
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { displayedError != nil },
            set: {
                if !$0 {
                    store.actionError = nil
                    store.works.clearRefreshError()
                }
            }
        )
    }

    private func retry() async {
        await store.retry(
            seriesID: seriesID,
            userID: authentication.userID,
            repository: repository
        )
    }

    private func loadMore() async {
        await store.loadMore(
            seriesID: seriesID,
            userID: authentication.userID,
            repository: repository
        )
    }

    private func toggleWatch() {
        guard !isChangingWatch else { return }
        Task {
            isChangingWatch = true
            defer { isChangingWatch = false }
            await store.toggleWatch(seriesID: seriesID, repository: repository)
        }
    }
}

private struct IllustrationSeriesHeader: View {
    let detail: PixivIllustrationSeriesDetail
    let isWatching: Bool
    let isWorking: Bool
    let onToggleWatch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let coverURL = detail.coverImageURLs.medium {
                RemoteImageView(url: coverURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .clipped()
            }

            Text(detail.title)
                .font(.title.weight(.bold))
                .textSelection(.enabled)

            HStack {
                Label("\(detail.seriesWorkCount) 话", systemImage: "books.vertical")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onToggleWatch) {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 96)
                    } else {
                        Label(
                            isWatching ? "已追更" : "追更",
                            systemImage: isWatching ? "checkmark.circle.fill" : "plus.circle"
                        )
                        .frame(minWidth: 96)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isWatching ? .gray : .accentColor)
                .disabled(isWorking)
            }

            if let user = detail.user {
                NavigationLink(value: AppRoute.user(id: user.id, preview: user)) {
                    HStack(spacing: 10) {
                        RemoteImageView(url: user.profileImageURLs.medium)
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                            .clipped()
                        Text(user.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .appNavigationTransitionSource(for: .user(id: user.id))
                }
                .buttonStyle(.plain)
            }

            let caption = TextSanitizer.plainText(from: detail.caption)
            if !caption.isEmpty {
                Text(caption)
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview("插画系列") {
    NavigationStack {
        IllustrationSeriesView(seriesID: 266067)
    }
    .withPreviewDependencies()
}

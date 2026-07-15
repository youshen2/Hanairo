import SwiftUI

struct MangaWatchlistView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository

    @State private var series = PaginatedStore<PixivMangaSeriesSummary>(id: { $0.id })
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                content
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("漫画追更")
        .task(id: requestKey) {
            await loadIfNeeded()
        }
        .refreshable {
            await reload(showsInitialLoading: false)
        }
        .alert("操作失败", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(displayedError ?? "未知错误")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch series.phase {
        case .idle, .loading:
            ProgressView("正在加载追更列表…")
                .frame(maxWidth: .infinity, minHeight: 360)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await reload(showsInitialLoading: true) }
            }
            .frame(minHeight: 360)
        case .loaded:
            if series.items.isEmpty {
                ContentUnavailableView(
                    "还没有追更系列",
                    systemImage: "books.vertical",
                    description: Text("在漫画系列页面可以加入追更。")
                )
                .frame(minHeight: 360)
            } else {
                ForEach(series.items) { item in
                    MangaSeriesRow(series: item) {
                        await remove(item)
                    }
                    .task {
                        guard item.id == series.items.last?.id else { return }
                        await loadMore()
                    }
                    Divider()
                }
                PaginationStatusView(
                    isLoading: series.isLoadingMore,
                    errorMessage: series.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    private var requestKey: String {
        "watchlist-\(authentication.userID ?? 0)"
    }

    private var displayedError: String? {
        actionError ?? series.refreshError
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { displayedError != nil },
            set: {
                if !$0 {
                    actionError = nil
                    series.clearRefreshError()
                }
            }
        )
    }

    private func loadIfNeeded() async {
        let key = requestKey
        await series.loadIfNeeded(requestKey: key) {
            try await repository.mangaWatchlist()
        }
    }

    private func reload(showsInitialLoading: Bool) async {
        let key = requestKey
        await series.reload(requestKey: key, showsInitialLoading: showsInitialLoading) {
            try await repository.mangaWatchlist()
        }
    }

    private func loadMore() async {
        let key = requestKey
        await series.loadMore(requestKey: key) { nextURL in
            try await repository.mangaWatchlist(nextURL: nextURL)
        }
    }

    private func remove(_ item: PixivMangaSeriesSummary) async {
        do {
            try await repository.setSeriesWatched(seriesID: item.id, isWatching: false)
            series.removeItem(id: item.id)
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }
}

#Preview("漫画追更") {
    NavigationStack {
        MangaWatchlistView()
    }
    .withPreviewDependencies()
}

import SwiftUI

struct SearchView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks
    @State private var store: SearchStore
    @State private var showsFilters = false

    init(initialQuery: String = "") {
        _store = State(initialValue: SearchStore(initialQuery: initialQuery))
    }

    var body: some View {
        @Bindable var store = store

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("搜索")
        .searchable(
            text: $store.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索作品、标签或用户"
        )
        .searchScopes($store.scope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .searchSuggestions {
            if store.scope == .illustrations {
                ForEach(store.suggestions) { suggestion in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                            if let translation = suggestion.translatedName {
                                Text(translation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "number")
                    }
                    .searchCompletion(suggestion.name)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsFilters = true
                } label: {
                    Image(systemName: store.options.isDefault
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("搜索筛选")
                .disabled(store.scope == .users)
            }
        }
        .sheet(isPresented: $showsFilters) {
            SearchFiltersView(
                options: store.options,
                isPremium: authentication.account?.isPremium == true
            ) { options in
                store.options = options
            }
            .presentationDetents([.large])
        }
        .task(id: authentication.userID ?? 0) {
            await store.loadTrending(using: repository)
        }
        .task(id: requestKey) {
            await store.searchIfNeeded(requestKey: requestKey, using: repository)
        }
        .task(id: store.suggestionRequestKey) {
            await store.loadSuggestions(
                suggestionKey: store.suggestionRequestKey,
                using: repository
            )
        }
        .refreshable {
            await store.refresh(requestKey: requestKey, using: repository)
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {
                store.clearDisplayedError()
            }
        } message: {
            Text(store.displayedError ?? "未知错误")
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.normalizedQuery.isEmpty {
            searchLanding
        } else {
            switch store.scope {
            case .illustrations:
                illustrationResults
            case .users:
                userResults
            }
        }
    }

    @ViewBuilder
    private var illustrationResults: some View {
        if !store.options.isDefault {
            Button {
                showsFilters = true
            } label: {
                Label(activeFilterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }

        switch store.illustrationResults.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if store.illustrationResults.items.isEmpty {
                ContentUnavailableView.search(text: store.normalizedQuery)
                    .frame(minHeight: 360)
            } else {
                Text("作品结果")
                    .font(.title2.weight(.bold))
                ArtworkGrid(
                    illustrations: store.illustrationResults.items,
                    onLoadMore: loadMore
                ) { id in
                    await store.toggleBookmark(id: id, using: repository)
                }
                PaginationStatusView(
                    isLoading: store.illustrationResults.isLoadingMore,
                    errorMessage: store.illustrationResults.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    @ViewBuilder
    private var userResults: some View {
        switch store.userResults.phase {
        case .idle, .loading:
            ProgressView("正在搜索用户…")
                .frame(maxWidth: .infinity, minHeight: 260)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if visibleUserResults.isEmpty {
                ContentUnavailableView.search(text: store.normalizedQuery)
                    .frame(minHeight: 360)
            } else {
                Text("用户结果")
                    .font(.title2.weight(.bold))
                ForEach(visibleUserResults) { user in
                    UserRow(preview: user, showsFollowButton: true)
                        .task {
                            guard user.id == visibleUserResults.last?.id else { return }
                            await loadMore()
                        }
                    Divider()
                }
                PaginationStatusView(
                    isLoading: store.userResults.isLoadingMore,
                    errorMessage: store.userResults.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    @ViewBuilder
    private var searchLanding: some View {
        if !store.history.isEmpty {
            HStack {
                Text("最近搜索")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("清除") {
                    store.clearHistory()
                }
                .font(.subheadline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(store.history, id: \.self) { term in
                        Button(term) {
                            store.query = term
                        }
                        .buttonStyle(.bordered)
                        .contextMenu {
                            Button("移除", systemImage: "trash", role: .destructive) {
                                store.removeHistory(term)
                            }
                        }
                    }
                }
            }
        }

        Text("热门标签")
            .font(.title2.weight(.bold))
        if store.trendingTags.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            TrendingTagsView(tags: store.trendingTags) { tag in
                store.scope = .illustrations
                store.query = tag
            }
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { store.displayedError != nil },
            set: { if !$0 { store.clearDisplayedError() } }
        )
    }

    private var requestKey: String {
        "\(store.request.key)|\(authentication.userID ?? 0)"
    }

    private var activeFilterSummary: String {
        var values = [store.options.target.title, store.options.sort.title]
        if store.options.mediaFilter != .all {
            values.append(store.options.mediaFilter.title)
        }
        if store.options.aiFilter != .all {
            values.append(store.options.aiFilter.title)
        }
        if store.options.bookmarkThreshold != .any {
            values.append(store.options.bookmarkThreshold.title)
        }
        if store.options.usesDateRange {
            values.append("限定日期")
        }
        return values.joined(separator: " · ")
    }

    private var visibleUserResults: [PixivUserPreview] {
        store.userResults.items.filter { !localBlocks.isBlocked($0.user) }
    }

    private func retry() async {
        await store.retry(requestKey: requestKey, using: repository)
    }

    private func loadMore() async {
        await store.loadMore(requestKey: requestKey, using: repository)
    }
}

#Preview("搜索首页") {
    NavigationStack {
        SearchView()
    }
    .withPreviewDependencies()
}

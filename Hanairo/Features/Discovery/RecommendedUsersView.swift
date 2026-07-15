import SwiftUI

struct RecommendedUsersView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks

    @State private var users = PaginatedStore<PixivUserPreview>(id: { $0.id })

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                content
            }
            .padding()
        }
        .navigationTitle("推荐作者")
        .task(id: requestKey) {
            await users.loadIfNeeded(requestKey: requestKey) {
                try await repository.recommendedUsers()
            }
        }
        .refreshable {
            await users.reload(requestKey: requestKey, showsInitialLoading: false) {
                try await repository.recommendedUsers()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch users.phase {
        case .idle, .loading:
            ProgressView("正在加载推荐作者…")
                .frame(maxWidth: .infinity, minHeight: 320)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task {
                    await users.reload(requestKey: requestKey, showsInitialLoading: true) {
                        try await repository.recommendedUsers()
                    }
                }
            }
            .frame(minHeight: 320)
        case .loaded:
            if visibleUsers.isEmpty {
                ContentUnavailableView("暂无推荐作者", systemImage: "person.2")
                    .frame(minHeight: 320)
            } else {
                ForEach(visibleUsers) { preview in
                    UserRow(preview: preview, showsFollowButton: true)
                        .task {
                            guard preview.id == visibleUsers.last?.id else { return }
                            await loadMore()
                        }
                    Divider()
                }
                PaginationStatusView(
                    isLoading: users.isLoadingMore,
                    errorMessage: users.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    private var requestKey: String {
        "recommended-users-\(authentication.userID ?? 0)"
    }

    private func loadMore() async {
        await users.loadMore(requestKey: requestKey) { nextURL in
            try await repository.users(nextURL: nextURL)
        }
    }

    private var visibleUsers: [PixivUserPreview] {
        users.items.filter { !localBlocks.isBlocked($0.user) }
    }
}

#Preview("推荐作者") {
    NavigationStack {
        RecommendedUsersView()
    }
    .withPreviewDependencies()
}

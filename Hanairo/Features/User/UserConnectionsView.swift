import SwiftUI

struct UserConnectionsView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks

    let userID: Int
    let kind: UserConnectionKind

    @State private var visibility: PixivVisibility = .public
    @State private var users = PaginatedStore<PixivUserPreview>(id: { $0.id })

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if showsVisibilityPicker {
                    Picker("关注范围", selection: $visibility) {
                        ForEach(PixivVisibility.allCases) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                content
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle(kind.title)
        .refreshable {
            await reload(showsInitialLoading: false)
        }
        .task(id: requestKey) {
            await loadIfNeeded()
        }
        .alert("刷新失败", isPresented: refreshErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(users.refreshError ?? "未知错误")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch users.phase {
        case .idle, .loading:
            ProgressView("正在加载用户…")
                .frame(maxWidth: .infinity, minHeight: 360)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await reload(showsInitialLoading: true) }
            }
            .frame(minHeight: 360)
        case .loaded:
            if visibleUsers.isEmpty {
                ContentUnavailableView(kind.emptyTitle, systemImage: "person.2")
                    .frame(minHeight: 360)
            } else {
                ForEach(visibleUsers) { preview in
                    UserRow(preview: preview, showsFollowButton: true) { isFollowed in
                        if kind == .following, !isFollowed {
                            users.removeItem(id: preview.id)
                        }
                    }
                    .task {
                        guard preview.id == visibleUsers.last?.id else { return }
                        await loadMore()
                    }
                }
                PaginationStatusView(
                    isLoading: users.isLoadingMore,
                    errorMessage: users.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    private var showsVisibilityPicker: Bool {
        authentication.userID == userID && kind == .following
    }

    private var requestKey: String {
        "\(authentication.userID ?? 0)-\(userID)-\(kind.rawValue)-\(activeVisibility.rawValue)"
    }

    private var activeVisibility: PixivVisibility {
        showsVisibilityPicker ? visibility : .public
    }

    private var refreshErrorBinding: Binding<Bool> {
        Binding(
            get: { users.refreshError != nil },
            set: { if !$0 { users.clearRefreshError() } }
        )
    }

    private func loadIfNeeded() async {
        let key = requestKey
        let visibility = activeVisibility
        await users.loadIfNeeded(requestKey: key) {
            try await repository.userConnections(
                userID: userID,
                kind: kind,
                visibility: visibility
            )
        }
    }

    private func reload(showsInitialLoading: Bool) async {
        let key = requestKey
        let visibility = activeVisibility
        await users.reload(requestKey: key, showsInitialLoading: showsInitialLoading) {
            try await repository.userConnections(
                userID: userID,
                kind: kind,
                visibility: visibility
            )
        }
    }

    private func loadMore() async {
        let key = requestKey
        await users.loadMore(requestKey: key) { nextURL in
            try await repository.users(nextURL: nextURL)
        }
    }

    private var visibleUsers: [PixivUserPreview] {
        users.items.filter { !localBlocks.isBlocked($0.user) }
    }
}

#Preview("关注列表") {
    NavigationStack {
        UserConnectionsView(userID: 101, kind: .following)
    }
    .withPreviewDependencies()
}

import SwiftUI

struct IllustrationCommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigationCoordinator.self) private var navigation
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks

    let illustrationID: Int
    let allowsPosting: Bool

    @State private var comments = PaginatedStore<PixivComment>(id: { $0.id })
    @State private var totalComments = 0
    @State private var composerContext: CommentComposerContext?
    @State private var repliesContext: CommentRepliesContext?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if allowsPosting {
                        ToolbarItem(placement: .primaryAction) {
                            Button("写评论", systemImage: "square.and.pencil") {
                                composerContext = .artwork
                            }
                            .labelStyle(.iconOnly)
                        }
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭", systemImage: "xmark") {
                            dismiss()
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .navigationDestination(item: $repliesContext) { context in
                    IllustrationCommentRepliesView(
                        illustrationID: illustrationID,
                        parentComment: context.comment,
                        allowsPosting: allowsPosting,
                        onShowUser: showUser
                    )
                }
        }
        .task(id: requestKey) {
            await loadIfNeeded()
        }
        .sheet(item: $composerContext, onDismiss: refreshAfterComposing) { context in
            CommentComposerSheet(illustrationID: illustrationID, context: context)
                .presentationDetents([.medium])
        }
        .alert("刷新失败", isPresented: refreshErrorBinding) {
            Button("好", role: .cancel) {
                comments.clearRefreshError()
            }
        } message: {
            Text(comments.refreshError ?? "未知错误")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch comments.phase {
        case .idle, .loading:
            ProgressView("正在加载评论…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
        case .loaded:
            if visibleComments.isEmpty && comments.nextURL == nil {
                ContentUnavailableView("暂无评论", systemImage: "text.bubble")
            } else {
                commentsList
            }
        }
    }

    private var commentsList: some View {
        List {
            ForEach(visibleComments) { comment in
                PixivCommentRow(
                    illustrationID: illustrationID,
                    comment: comment,
                    onShowUser: showUser,
                    onReply: allowsPosting ? { reply(to: comment) } : nil,
                    onShowReplies: comment.hasReplies ? { showReplies(for: comment) } : nil
                )
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if
                comments.nextURL != nil
                    || comments.isLoadingMore
                    || comments.loadMoreError != nil
            {
                paginationRow
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refresh()
        }
    }

    private var paginationRow: some View {
        PaginationStatusView(
            isLoading: comments.isLoadingMore,
            errorMessage: comments.loadMoreError,
            onRetry: loadMore
        )
        .task(id: comments.nextURL) {
            guard comments.loadMoreError == nil else { return }
            await loadMore()
        }
        .listRowSeparator(.hidden)
    }

    private var visibleComments: [PixivComment] {
        comments.items.filter { !localBlocks.isBlocked($0) }
    }

    private var navigationTitle: String {
        totalComments > 0 ? "评论 \(totalComments)" : "评论"
    }

    private var requestKey: String {
        "comments-\(illustrationID)"
    }

    private var refreshErrorBinding: Binding<Bool> {
        Binding(
            get: { comments.refreshError != nil },
            set: { if !$0 { comments.clearRefreshError() } }
        )
    }

    private func loadIfNeeded() async {
        await comments.loadIfNeeded(requestKey: requestKey) {
            let page = try await repository.comments(illustrationID: illustrationID)
            totalComments = page.totalComments
            return page.page
        }
    }

    private func retry() async {
        await comments.reload(requestKey: requestKey, showsInitialLoading: true) {
            let page = try await repository.comments(illustrationID: illustrationID)
            totalComments = page.totalComments
            return page.page
        }
    }

    private func refresh() async {
        await comments.reload(requestKey: requestKey, showsInitialLoading: false) {
            let page = try await repository.comments(illustrationID: illustrationID)
            totalComments = page.totalComments
            return page.page
        }
    }

    private func loadMore() async {
        await comments.loadMore(requestKey: requestKey) { nextURL in
            try await repository.comments(nextURL: nextURL).page
        }
    }

    private func reply(to comment: PixivComment) {
        composerContext = CommentComposerContext(
            parentCommentID: comment.id,
            parentName: comment.user.name
        )
    }

    private func showReplies(for comment: PixivComment) {
        repliesContext = CommentRepliesContext(comment: comment)
    }

    private func showUser(_ userID: Int) {
        navigation.push(.user(id: userID))
        dismiss()
    }

    private func refreshAfterComposing() {
        Task { await refresh() }
    }
}

private struct CommentRepliesContext: Identifiable, Hashable {
    let comment: PixivComment

    var id: Int { comment.id }
}

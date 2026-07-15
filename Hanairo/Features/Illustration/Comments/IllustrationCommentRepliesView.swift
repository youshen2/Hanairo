import SwiftUI

struct IllustrationCommentRepliesView: View {
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks

    let illustrationID: Int
    let parentComment: PixivComment
    let allowsPosting: Bool
    let onShowUser: (Int) -> Void

    @State private var replies = PaginatedStore<PixivComment>(id: { $0.id })
    @State private var composerContext: CommentComposerContext?

    var body: some View {
        content
            .navigationTitle("回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if allowsPosting {
                    ToolbarItem(placement: .primaryAction) {
                        Button("回复", systemImage: "arrowshape.turn.up.left") {
                            composerContext = replyContext
                        }
                        .labelStyle(.iconOnly)
                    }
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
                    replies.clearRefreshError()
                }
            } message: {
                Text(replies.refreshError ?? "未知错误")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch replies.phase {
        case .idle, .loading:
            ProgressView("正在加载回复…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
        case .loaded:
            List {
                Section("原评论") {
                    if localBlocks.isBlocked(parentComment) {
                        Text("原评论已在本地隐藏")
                            .foregroundStyle(.secondary)
                    } else {
                        PixivCommentRow(
                            illustrationID: illustrationID,
                            comment: parentComment,
                            onShowUser: onShowUser,
                            onReply: nil,
                            onShowReplies: nil
                        )
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                Section("回复") {
                    if visibleReplies.isEmpty && replies.nextURL == nil {
                        Text("暂无回复")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleReplies) { reply in
                            PixivCommentRow(
                                illustrationID: illustrationID,
                                comment: reply,
                                onShowUser: onShowUser,
                                onReply: allowsPosting ? { composerContext = replyContext } : nil,
                                onShowReplies: nil
                            )
                            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }

                    if
                        replies.nextURL != nil
                            || replies.isLoadingMore
                            || replies.loadMoreError != nil
                    {
                        PaginationStatusView(
                            isLoading: replies.isLoadingMore,
                            errorMessage: replies.loadMoreError,
                            onRetry: loadMore
                        )
                        .task(id: replies.nextURL) {
                            guard replies.loadMoreError == nil else { return }
                            await loadMore()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await refresh()
            }
        }
    }

    private var visibleReplies: [PixivComment] {
        replies.items.filter { !localBlocks.isBlocked($0) }
    }

    private var replyContext: CommentComposerContext {
        CommentComposerContext(
            parentCommentID: parentComment.id,
            parentName: parentComment.user.name
        )
    }

    private var requestKey: String {
        "comment-replies-\(parentComment.id)"
    }

    private var refreshErrorBinding: Binding<Bool> {
        Binding(
            get: { replies.refreshError != nil },
            set: { if !$0 { replies.clearRefreshError() } }
        )
    }

    private func loadIfNeeded() async {
        await replies.loadIfNeeded(requestKey: requestKey) {
            try await repository.commentReplies(commentID: parentComment.id).page
        }
    }

    private func retry() async {
        await replies.reload(requestKey: requestKey, showsInitialLoading: true) {
            try await repository.commentReplies(commentID: parentComment.id).page
        }
    }

    private func refresh() async {
        await replies.reload(requestKey: requestKey, showsInitialLoading: false) {
            try await repository.commentReplies(commentID: parentComment.id).page
        }
    }

    private func loadMore() async {
        await replies.loadMore(requestKey: requestKey) { nextURL in
            try await repository.comments(nextURL: nextURL).page
        }
    }

    private func refreshAfterComposing() {
        Task { await refresh() }
    }
}

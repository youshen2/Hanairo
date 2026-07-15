import SwiftUI

struct PixivCommentRow: View {
    @Environment(LocalBlockStore.self) private var localBlocks

    let illustrationID: Int
    let comment: PixivComment
    let onShowUser: (Int) -> Void
    let onReply: (() -> Void)?
    let onShowReplies: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: showUser) {
                RemoteImageView(url: comment.user.profileImageURLs.medium)
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .clipped()
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                header
                parentComment
                content
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .contextMenu { moreActions }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: showUser) {
                Text(comment.user.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            if !comment.displayDate.isEmpty {
                Text(comment.displayDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    @ViewBuilder
    private var parentComment: some View {
        if let parent = comment.parentComment {
            VStack(alignment: .leading, spacing: 3) {
                if let user = parent.user {
                    Text("回复 \(user.name)")
                        .font(.caption.weight(.semibold))
                }
                if !parent.comment.isEmpty {
                    PixivCommentText(content: parent.comment, font: .caption)
                        .lineLimit(3)
                }
            }
            .foregroundStyle(.secondary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var content: some View {
        if let stampURL = comment.stamp?.url {
            RemoteImageView(url: stampURL, contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .clipped()
        } else if !comment.comment.isEmpty {
            PixivCommentText(content: comment.comment)
        } else {
            Text("（无内容）")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: 16) {
            if let onReply {
                Button("回复", systemImage: "arrowshape.turn.up.left", action: onReply)
            }
            if let onShowReplies {
                Button("查看回复", systemImage: "text.bubble", action: onShowReplies)
            }
            Menu { moreActions } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 24)
            }
            .accessibilityLabel("更多评论操作")
        }
        .font(.caption.weight(.medium))
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    @ViewBuilder
    private var moreActions: some View {
        if !comment.comment.isEmpty {
            ShareLink(item: comment.comment) {
                Label("分享评论文字", systemImage: "square.and.arrow.up")
            }
        }
        Button("隐藏此评论", systemImage: "eye.slash", role: .destructive) {
            localBlocks.block(comment: comment)
        }
        Button("屏蔽该用户", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
            localBlocks.block(user: comment.user)
        }
        Link(destination: PixivWebLinks.artwork(id: illustrationID)) {
            Label("前往 Pixiv 举报", systemImage: "exclamationmark.bubble")
        }
    }

    private func showUser() {
        onShowUser(comment.user.id)
    }
}

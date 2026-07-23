import SwiftUI

struct ArtworkCard: View {
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    let illustration: PixivIllustration
    var rank: Int?
    var previewAspectRatio: CGFloat = 0.78
    let onBookmark: () async -> Void

    @State private var isChangingBookmark = false
    @State private var downloadNotice: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: route) {
                VStack(alignment: .leading, spacing: 8) {
                    RemoteImageView(
                        url: illustration.previewURL
                    )
                    .aspectRatio(previewAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let rank {
                                Text("#\(rank)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.black.opacity(0.62), in: Capsule())
                            }
                            if illustration.isUgoira {
                                Label("动图", systemImage: "play.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.black.opacity(0.62), in: Capsule())
                            }
                        }
                        .padding(8)
                    }
                    .appNavigationTransitionSource(for: route)
                    Text(illustration.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(illustration.user.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            bookmarkButton
                .disabled(isChangingBookmark)
                .padding(8)
                .accessibilityLabel(isBookmarked ? "取消收藏" : "收藏")
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .contextMenu {
            Button(downloadTitle, systemImage: "arrow.down.circle") {
                enqueueDownload()
            }
            Divider()
            Button("屏蔽作品", systemImage: "photo.badge.minus", role: .destructive) {
                localBlocks.block(artwork: illustration)
            }
            Button("屏蔽作者", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                localBlocks.block(user: illustration.user)
            }
            if !illustration.tags.isEmpty {
                Menu("屏蔽标签", systemImage: "number") {
                    ForEach(illustration.tags) { tag in
                        Button("#\(tag.displayName)") {
                            localBlocks.block(tag: tag)
                        }
                    }
                }
            }
        }
        .alert("下载", isPresented: downloadNoticeBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(downloadNotice ?? "未知状态")
        }
    }

    private var downloadTitle: String {
        illustration.pageCount > 1 ? "下载全部图片" : "下载图片"
    }

    private var route: AppRoute {
        .illustration(id: illustration.id, preview: illustration)
    }

    private var downloadNoticeBinding: Binding<Bool> {
        Binding(
            get: { downloadNotice != nil },
            set: { if !$0 { downloadNotice = nil } }
        )
    }

    private func enqueueDownload() {
        downloadNotice = downloadManager.enqueue(
            illustration: illustration,
            pageIndices: Array(illustration.originalPageURLs.indices)
        ).message
    }

    private var isBookmarked: Bool {
        repository.bookmarkState(for: illustration)
    }

    private var bookmarkButton: some View {
        Button {
            guard !isChangingBookmark else { return }
            isChangingBookmark = true
            Task {
                await onBookmark()
                isChangingBookmark = false
            }
        } label: {
            Image(systemName: isBookmarked ? "heart.fill" : "heart")
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    isBookmarked
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(.white)
                )
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .background(.black.opacity(0.45), in: Circle())
    }
}

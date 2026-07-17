import SwiftUI

struct TrendingTagsView: View {
    @Environment(LocalBlockStore.self) private var localBlocks
    @Environment(PixivRepository.self) private var repository
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    let tags: [PixivTrendingTag]
    let onSelect: (String) -> Void

    @State private var previewTag: PixivTrendingTag?

    var body: some View {
#if os(iOS)
        tagsGrid
            .fullScreenCover(item: $previewTag) { tag in
                imageViewer(for: tag)
            }
#else
        tagsGrid
            .sheet(item: $previewTag) { tag in
                imageViewer(for: tag)
            }
#endif
    }

    private var tagsGrid: some View {
        MasonryGrid(items: visibleTags, spacing: 12, estimatedHeight: { _ in 1 }) { tag in
            Button {
                onSelect(tag.tag)
            } label: {
                HStack(spacing: 10) {
                    RemoteImageView(
                        url: tag.illustration.imageURLs.squareMedium
                    )
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipped()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("#\(tag.tag)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let translatedName = tag.translatedName {
                            Text(translatedName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("查看大图", systemImage: "arrow.up.left.and.arrow.down.right") {
                    previewTag = tag
                }
                .disabled(tag.illustration.imageURLs.fullSizeURL == nil)

                Button("屏蔽此标签", systemImage: "number", role: .destructive) {
                    localBlocks.blockTag(
                        name: tag.tag,
                        translatedName: tag.translatedName
                    )
                }
            }
        }
    }

    private func imageViewer(for tag: PixivTrendingTag) -> some View {
        ArtworkViewerView(
            title: "#\(tag.tag)",
            urls: [tag.illustration.imageURLs.fullSizeURL],
            initialPage: 0,
            onDownload: { _ in
                await enqueueDownload(for: tag)
            }
        )
    }

    private func enqueueDownload(for tag: PixivTrendingTag) async -> String {
        do {
            let illustration = try await repository.illustration(id: tag.illustration.id)
            return downloadManager.enqueue(
                illustration: illustration,
                pageIndices: [0]
            ).message
        } catch {
            return "下载失败：\(error.localizedDescription)"
        }
    }

    private var visibleTags: [PixivTrendingTag] {
        tags.filter { !localBlocks.isTagBlocked($0.tag) }
    }
}

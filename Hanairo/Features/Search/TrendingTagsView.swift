import SwiftUI

struct TrendingTagsView: View {
    @Environment(LocalBlockStore.self) private var localBlocks

    let tags: [PixivTrendingTag]
    let onSelect: (String) -> Void

    var body: some View {
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
                Button("屏蔽此标签", systemImage: "number", role: .destructive) {
                    localBlocks.blockTag(
                        name: tag.tag,
                        translatedName: tag.translatedName
                    )
                }
            }
        }
    }

    private var visibleTags: [PixivTrendingTag] {
        tags.filter { !localBlocks.isTagBlocked($0.tag) }
    }
}

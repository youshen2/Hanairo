import SwiftUI

struct ArtworkMasonryGrid: View {
    @Environment(LocalBlockStore.self) private var localBlocks

    let illustrations: [PixivIllustration]
    var showsRanking = false
    var columnCount: Int? = nil
    var onLoadMore: (() async -> Void)?
    let onBookmark: (Int) async -> Void

    var body: some View {
        MasonryGrid(
            items: items,
            spacing: 12,
            columnCount: columnCount,
            estimatedHeight: { $0.estimatedHeight }
        ) { item in
            ArtworkCard(
                illustration: item.illustration,
                rank: showsRanking ? item.position + 1 : nil,
                previewAspectRatio: item.aspectRatio
            ) {
                await onBookmark(item.id)
            }
            .task {
                guard item.id == visibleIllustrations.last?.id else { return }
                await onLoadMore?()
            }
        }
    }

    private var visibleIllustrations: [PixivIllustration] {
        illustrations.filter { !localBlocks.isBlocked($0) }
    }

    private var items: [MasonryArtworkItem] {
        visibleIllustrations.enumerated().map { position, illustration in
            MasonryArtworkItem(illustration: illustration, position: position)
        }
    }
}

private struct MasonryArtworkItem: Identifiable {
    let illustration: PixivIllustration
    let position: Int

    var id: Int { illustration.id }

    var aspectRatio: CGFloat {
        illustration.aspectRatio > 0 ? illustration.aspectRatio : 0.75
    }

    var estimatedHeight: CGFloat {
        1 / aspectRatio + 0.34
    }
}

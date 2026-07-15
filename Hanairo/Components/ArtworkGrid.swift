import SwiftUI

struct ArtworkGrid: View {
    let illustrations: [PixivIllustration]
    var showsRanking = false
    var onLoadMore: (() async -> Void)? = nil
    let onBookmark: (Int) async -> Void

    var body: some View {
        ArtworkMasonryGrid(
            illustrations: illustrations,
            showsRanking: showsRanking,
            onLoadMore: onLoadMore,
            onBookmark: onBookmark
        )
    }
}

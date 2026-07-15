import SwiftUI

struct ArtworkPagesView: View {
    let illustration: PixivIllustration
    let displayURLs: [URL?]
    let fullSizeURLs: [URL?]

    @State private var viewerPresentation: ArtworkViewerPresentation?

    var body: some View {
        if illustration.isUgoira {
            UgoiraPlayerView(illustration: illustration)
        } else {
            staticArtworkPages
        }
    }

    @ViewBuilder
    private var staticArtworkPages: some View {
#if os(iOS)
        pages
            .fullScreenCover(item: $viewerPresentation) { presentation in
                artworkViewer(for: presentation)
            }
#else
        pages
            .sheet(item: $viewerPresentation) { presentation in
                artworkViewer(for: presentation)
            }
#endif
    }

    private var pages: some View {
        LazyVStack(spacing: 2) {
            ForEach(displayURLs.indices, id: \.self) { index in
                Button {
                    viewerPresentation = ArtworkViewerPresentation(page: index)
                } label: {
                    RemoteImageView(url: displayURLs[index], contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(clampedAspectRatio, contentMode: .fit)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                bottomLeadingRadius: index == displayURLs.indices.last ? 28 : 0,
                                bottomTrailingRadius: index == displayURLs.indices.last ? 28 : 0,
                                style: .continuous
                            )
                        )
                        .overlay(alignment: .topTrailing) {
                            if displayURLs.count > 1 {
                                pageBadge(index: index)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.55), in: Circle())
                                .padding(10)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看第 \(index + 1) 页大图")
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func artworkViewer(for presentation: ArtworkViewerPresentation) -> some View {
        ArtworkViewerView(
            title: illustration.title,
            urls: fullSizeURLs,
            initialPage: presentation.page
        )
    }

    private var clampedAspectRatio: CGFloat {
        min(max(illustration.aspectRatio, 0.42), 1.6)
    }

    private func pageBadge(index: Int) -> some View {
        Text("\(index + 1) / \(displayURLs.count)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(10)
    }
}

private struct ArtworkViewerPresentation: Identifiable {
    let page: Int

    var id: Int { page }
}

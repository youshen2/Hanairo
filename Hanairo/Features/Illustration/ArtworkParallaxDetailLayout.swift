import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ArtworkRelatedFlowConfiguration: Equatable {
    let sidebarWidth: CGFloat
    let availableSidebarHeight: CGFloat
}

private struct ArtworkRelatedFlowConfigurationKey: EnvironmentKey {
    static let defaultValue: ArtworkRelatedFlowConfiguration? = nil
}

extension EnvironmentValues {
    var artworkRelatedFlowConfiguration: ArtworkRelatedFlowConfiguration? {
        get { self[ArtworkRelatedFlowConfigurationKey.self] }
        set { self[ArtworkRelatedFlowConfigurationKey.self] = newValue }
    }
}

struct ArtworkParallaxDetailLayout<Details: View, Footer: View>: View {
    let illustration: PixivIllustration
    let displayURLs: [URL?]
    let fullSizeURLs: [URL?]
    let isParallaxEnabled: Bool
    @ViewBuilder let details: Details
    @ViewBuilder let footer: Footer

    @State private var scrollOffset: CGFloat = 0
    @State private var wideDetailsHeight: CGFloat = 0

    init(
        illustration: PixivIllustration,
        displayURLs: [URL?],
        fullSizeURLs: [URL?],
        isParallaxEnabled: Bool,
        @ViewBuilder details: () -> Details,
        @ViewBuilder footer: () -> Footer
    ) {
        self.illustration = illustration
        self.displayURLs = displayURLs
        self.fullSizeURLs = fullSizeURLs
        self.isParallaxEnabled = isParallaxEnabled
        self.details = details()
        self.footer = footer()
    }

    @ViewBuilder
    var body: some View {
        GeometryReader { safeAreaProxy in
            if isParallaxEnabled {
                detailLayout(topSafeAreaInset: safeAreaProxy.safeAreaInsets.top)
#if os(iOS)
                    .ignoresSafeArea(edges: .top)
#endif
            } else {
                detailLayout(topSafeAreaInset: safeAreaProxy.safeAreaInsets.top)
            }
        }
    }

    private func detailLayout(topSafeAreaInset: CGFloat) -> some View {
        GeometryReader { proxy in
            ScrollView {
                Group {
                    if usesWideLayout(for: proxy.size.width) {
                        wideDetailLayout(
                            proxy: proxy,
                            topSafeAreaInset: topSafeAreaInset
                        )
                    } else {
                        compactDetailLayout(size: proxy.size)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newOffset in
                scrollOffset = newOffset
            }
            .scrollEdgeEffectHidden(true, for: .top)
        }
        .background {
            ArtworkDetailSurface()
                .ignoresSafeArea()
        }
        .scrollIndicators(.hidden)
    }

    private func compactDetailLayout(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            artworkPages(
                width: size.width,
                viewportHeight: size.height,
                startsParallaxImmediately: false
            )
            .zIndex(0)

            VStack(alignment: .leading, spacing: 20) {
                details
                footer
            }
            .padding(.horizontal)
            .padding(.top, isParallaxEnabled ? -32 : 20)
            .zIndex(1)
        }
    }

    @ViewBuilder
    private func wideDetailLayout(
        proxy: GeometryProxy,
        topSafeAreaInset: CGFloat
    ) -> some View {
        let metrics = ArtworkWideDetailMetrics(availableWidth: proxy.size.width)
        let detailTopPadding = isParallaxEnabled ? topSafeAreaInset + 20 : 20
        let detailWidth = metrics.detailWidth
        let mediaWidth = isParallaxEnabled
            ? metrics.parallaxMediaWidth
            : metrics.mediaWidth
        let mediaHeight = ArtworkMediaMetrics.height(
            illustration: illustration,
            pageCount: displayURLs.count,
            width: mediaWidth
        )
        let pageHeight = ArtworkMediaMetrics.pageHeight(
            illustration: illustration,
            width: mediaWidth
        )
        let parallaxOverflow = isParallaxEnabled
            ? ArtworkParallaxMetrics.offset(
                activeScrollOffset: max(scrollOffset, 0),
                viewportHeight: proxy.size.height
            )
            : 0
        let visualMediaHeight = mediaHeight + parallaxOverflow
        let availableSidebarHeight = max(
            visualMediaHeight - detailTopPadding - wideDetailsHeight - 20,
            0
        )
        let relatedFlow = ArtworkRelatedFlowConfiguration(
            sidebarWidth: max(detailWidth - 32, 1),
            availableSidebarHeight: availableSidebarHeight
        )

        if isParallaxEnabled {
            ZStack(alignment: .topTrailing) {
                artworkPages(
                    width: mediaWidth,
                    viewportHeight: proxy.size.height,
                    startsParallaxImmediately: true,
                    showsOuterEdgeBlur: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .zIndex(0)

                ArtworkWideParallaxEdgeFill(
                    displayURLs: displayURLs,
                    pageHeight: pageHeight,
                    mediaHeight: mediaHeight,
                    viewportHeight: proxy.size.height,
                    parallaxOffset: parallaxOverflow
                )
                    .frame(
                        width: metrics.parallaxDetailWidth,
                        height: visualMediaHeight
                    )
                    .allowsHitTesting(false)
                    .zIndex(1)

                ArtworkProgressiveDetailBackdrop()
                    .frame(
                        width: min(detailWidth + 36, proxy.size.width),
                        height: visualMediaHeight
                    )
                    .allowsHitTesting(false)
                    .zIndex(2)

                wideForeground(
                    detailWidth: detailWidth,
                    detailTopPadding: detailTopPadding,
                    relatedFlow: relatedFlow
                )
                .zIndex(3)
            }
        } else {
            ZStack(alignment: .topLeading) {
                artworkPages(
                    width: mediaWidth,
                    viewportHeight: proxy.size.height,
                    startsParallaxImmediately: false,
                    showsOutwardBlur: true
                )
                .frame(width: metrics.mediaWidth, alignment: .topLeading)
                .zIndex(0)

                Color.secondary.opacity(0.18)
                    .frame(width: 1, height: mediaHeight)
                    .offset(x: metrics.mediaWidth)
                    .allowsHitTesting(false)
                    .zIndex(1)

                wideForeground(
                    detailWidth: detailWidth,
                    detailTopPadding: detailTopPadding,
                    relatedFlow: relatedFlow
                )
                .zIndex(2)
            }
        }
    }

    private func wideForeground(
        detailWidth: CGFloat,
        detailTopPadding: CGFloat,
        relatedFlow: ArtworkRelatedFlowConfiguration
    ) -> some View {
        VStack(alignment: .trailing, spacing: 20) {
            details
                .environment(\.horizontalSizeClass, .compact)
                .padding(.horizontal)
                .frame(width: detailWidth, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { newHeight in
                    guard abs(wideDetailsHeight - newHeight) > 0.5 else { return }
                    wideDetailsHeight = newHeight
                }

            footer
                .environment(\.artworkRelatedFlowConfiguration, relatedFlow)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.top, detailTopPadding)
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }

    private func artworkPages(
        width: CGFloat,
        viewportHeight: CGFloat,
        startsParallaxImmediately: Bool,
        showsOutwardBlur: Bool = false,
        showsOuterEdgeBlur: Bool = false
    ) -> some View {
        ArtworkDetailPagesLayout(
            illustration: illustration,
            displayURLs: displayURLs,
            fullSizeURLs: fullSizeURLs,
            availableWidth: width,
            viewportHeight: viewportHeight,
            scrollOffset: scrollOffset,
            isParallaxEnabled: isParallaxEnabled,
            startsParallaxImmediately: startsParallaxImmediately,
            showsOutwardBlur: showsOutwardBlur,
            showsOuterEdgeBlur: showsOuterEdgeBlur
        )
    }

    private func usesWideLayout(for width: CGFloat) -> Bool {
        guard width >= ArtworkWideDetailMetrics.minimumLayoutWidth else { return false }
#if os(iOS)
        return UIDevice.current.userInterfaceIdiom != .phone
#else
        return true
#endif
    }
}

private struct ArtworkWideDetailMetrics {
    static let minimumLayoutWidth: CGFloat = 900

    let availableWidth: CGFloat

    var detailWidth: CGFloat {
        min(max(availableWidth * 0.34, 360), 480)
    }

    var mediaWidth: CGFloat {
        max(availableWidth - detailWidth - 1, 1)
    }

    var parallaxDetailWidth: CGFloat {
        availableWidth * 0.25
    }

    var parallaxMediaWidth: CGFloat {
        max(availableWidth - parallaxDetailWidth, 1)
    }
}

private enum ArtworkMediaMetrics {
    static func pageHeight(
        illustration: PixivIllustration,
        width: CGFloat
    ) -> CGFloat {
        let aspectRatio = min(max(illustration.aspectRatio, 0.42), 1.6)
        return width / aspectRatio
    }

    static func height(
        illustration: PixivIllustration,
        pageCount: Int,
        width: CGFloat
    ) -> CGFloat {
        let pageCount = max(pageCount, 1)
        let pageHeight = pageHeight(illustration: illustration, width: width)
        return pageHeight * CGFloat(pageCount) + CGFloat(max(pageCount - 1, 0)) * 2
    }
}

private enum ArtworkParallaxMetrics {
    static func offset(
        activeScrollOffset: CGFloat,
        viewportHeight: CGFloat
    ) -> CGFloat {
        min(activeScrollOffset * 0.55, max(viewportHeight, 1) * 0.55)
    }
}

private struct ArtworkDetailPagesLayout: View {
    let illustration: PixivIllustration
    let displayURLs: [URL?]
    let fullSizeURLs: [URL?]
    let availableWidth: CGFloat
    let viewportHeight: CGFloat
    let scrollOffset: CGFloat
    let isParallaxEnabled: Bool
    let startsParallaxImmediately: Bool
    let showsOutwardBlur: Bool
    let showsOuterEdgeBlur: Bool

    @ViewBuilder
    var body: some View {
        if isParallaxEnabled {
            parallaxPages
        } else {
            pages
        }
    }

    private var parallaxPages: some View {
        ZStack(alignment: .top) {
            pages
                .overlay(alignment: .bottom) {
                    ArtworkImageTransition()
                        .frame(height: transitionHeight)
                        .opacity(transitionOpacity)
                        .allowsHitTesting(false)
                }
                .offset(y: parallaxOffset)
        }
        .frame(height: mediaHeight, alignment: .top)
    }

    private var pages: some View {
        ZStack(alignment: .top) {
            if showsOutwardBlur {
                pageContent
                    .scaleEffect(x: 1.02, y: 1.012)
                    .blur(radius: 24, opaque: false)
                    .opacity(0.72)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            pageContent
        }
        .frame(width: availableWidth, height: mediaHeight, alignment: .top)
        .overlay {
            if showsOuterEdgeBlur {
                ArtworkImageOuterEdgeBlur()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var pageContent: some View {
        ArtworkPagesView(
            illustration: illustration,
            displayURLs: displayURLs,
            fullSizeURLs: fullSizeURLs
        )
        .frame(width: availableWidth, height: mediaHeight, alignment: .top)
    }

    private var mediaHeight: CGFloat {
        ArtworkMediaMetrics.height(
            illustration: illustration,
            pageCount: displayURLs.count,
            width: availableWidth
        )
    }

    private var parallaxOffset: CGFloat {
        ArtworkParallaxMetrics.offset(
            activeScrollOffset: activeScrollOffset,
            viewportHeight: viewportHeight
        )
    }

    private var parallaxStartOffset: CGFloat {
        guard !startsParallaxImmediately else { return 0 }
        return max(mediaHeight - max(viewportHeight, 1) - 32, 0)
    }

    private var transitionHeight: CGFloat {
        let viewportTransition = min(max(viewportHeight * 0.28, 180), 280)
        return min(viewportTransition, max(mediaHeight * 0.3, 100))
    }

    private var activeScrollOffset: CGFloat {
        max(scrollOffset - parallaxStartOffset, 0)
    }

    private var transitionProgress: CGFloat {
        min(activeScrollOffset / max(transitionHeight * 0.7, 1), 1)
    }

    private var transitionOpacity: CGFloat {
        startsParallaxImmediately ? 1 : transitionProgress
    }
}

private struct ArtworkProgressiveDetailBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.28), location: 0.03),
                            .init(color: .black, location: 0.18)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }

            Rectangle()
                .fill(.thinMaterial)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.08),
                            .init(color: .black.opacity(0.68), location: 0.26),
                            .init(color: .black, location: 0.48)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
        }
        .accessibilityHidden(true)
    }
}

private struct ArtworkImageOuterEdgeBlur: View {
    var body: some View {
        GeometryReader { proxy in
            let horizontalEdgeWidth = min(max(proxy.size.width * 0.025, 16), 28)
            let verticalEdgeHeight = min(max(proxy.size.height * 0.018, 18), 32)

            ZStack {
                HStack(spacing: 0) {
                    edgeMaterial(
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: horizontalEdgeWidth)

                    Spacer(minLength: 0)

                    edgeMaterial(
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                    .frame(width: horizontalEdgeWidth)
                }

                VStack(spacing: 0) {
                    edgeMaterial(
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: verticalEdgeHeight)

                    Spacer(minLength: 0)

                    edgeMaterial(
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: verticalEdgeHeight)
                }
            }
        }
    }

    private func edgeMaterial(
        startPoint: UnitPoint,
        endPoint: UnitPoint
    ) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                LinearGradient(
                    colors: [.black.opacity(0.72), .clear],
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            }
    }
}

private struct ArtworkWideParallaxEdgeFill: View {
    let displayURLs: [URL?]
    let pageHeight: CGFloat
    let mediaHeight: CGFloat
    let viewportHeight: CGFloat
    let parallaxOffset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            ArtworkDetailSurface()

            VStack(spacing: 2) {
                ForEach(pageURLs.indices, id: \.self) { index in
                    ArtworkPageRightEdgeFill(url: pageURLs[index])
                        .frame(height: pageHeight)
                }
            }
            .frame(height: mediaHeight, alignment: .top)
            .overlay(alignment: .bottom) {
                ArtworkImageTransition()
                    .frame(height: transitionHeight)
            }
            .offset(y: parallaxOffset)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pageURLs: [URL?] {
        displayURLs.isEmpty ? [nil] : displayURLs
    }

    private var transitionHeight: CGFloat {
        let viewportTransition = min(max(viewportHeight * 0.28, 180), 280)
        return min(viewportTransition, max(mediaHeight * 0.3, 100))
    }
}

private struct ArtworkPageRightEdgeFill: View {
    @Environment(ImageRepository.self) private var imageRepository

    let url: URL?

    @State private var edgeImage: CGImage?
    @State private var loadedURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ArtworkDetailSurface()

                if let edgeImage {
                    Image(decorative: edgeImage, scale: 1)
                        .resizable(resizingMode: .stretch)
                        .interpolation(.high)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: url) {
            await loadEdgeImage()
        }
    }

    private func loadEdgeImage() async {
        if let url, loadedURL == url, edgeImage != nil {
            return
        }

        edgeImage = nil
        loadedURL = nil
        guard let url else { return }

        do {
            let image = try await imageRepository.image(for: url)
            guard !Task.isCancelled, self.url == url else { return }
            edgeImage = Self.rightEdgeStrip(from: image)
            loadedURL = url
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private static func rightEdgeStrip(from image: CGImage) -> CGImage? {
        guard image.width > 0, image.height > 0 else { return nil }

        let cropRect = CGRect(
            x: image.width - 1,
            y: 0,
            width: 1,
            height: image.height
        )
        return image.cropping(to: cropRect)
    }
}

private struct ArtworkImageTransition: View {
    var body: some View {
        ArtworkDetailSurface()
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.12), location: 0.2),
                        .init(color: .black.opacity(0.55), location: 0.65),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}

private struct ArtworkDetailSurface: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
            Color.secondary.opacity(0.04)
            Color.accentColor.opacity(0.08)
        }
    }
}

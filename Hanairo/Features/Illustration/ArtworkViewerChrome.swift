import SwiftUI

struct ArtworkViewerChrome: View {
    let currentPage: Int
    let pageCount: Int
    let isZoomed: Bool
    let onSelectPage: (Int) -> Void

    var body: some View {
        if pageCount > 1 || isZoomed {
            VStack {
                Spacer()
                pageIndicator
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var pageIndicator: some View {
#if os(visionOS)
        pageIndicatorContent
            .background(.regularMaterial, in: Capsule())
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            pageIndicatorContent
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            pageIndicatorContent
                .background(.regularMaterial, in: Capsule())
        }
#endif
    }

    private var pageIndicatorContent: some View {
        HStack(spacing: 6) {
            if isZoomed {
                Label("双击还原", systemImage: "magnifyingglass")
                    .font(.caption.weight(.medium))
            }

            if pageCount > 1 {
                if isZoomed || pageCount > 8 {
                    Text("\(currentPage + 1) / \(pageCount)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 4)
                } else {
                    ForEach(0..<pageCount, id: \.self) { page in
                        Button {
                            onSelectPage(page)
                        } label: {
                            Capsule()
                                .fill(page == currentPage ? Color.white : Color.white.opacity(0.38))
                                .frame(width: page == currentPage ? 18 : 6, height: 6)
                                .frame(width: 24, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(page + 1) 页")
                        .accessibilityAddTraits(page == currentPage ? .isSelected : [])
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .accessibilityElement(children: .contain)
    }
}

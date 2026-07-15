import SwiftUI

struct ArtworkToolbarActions: ToolbarContent {
    let isBookmarked: Bool
    let isChangingBookmark: Bool
    let pageCount: Int
    let shareURL: URL
    let onBookmark: () -> Void
    let onDownloadAll: () -> Void
    let onDownload: (Int) -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onBookmark) {
                Image(systemName: isBookmarked ? "heart.fill" : "heart")
                    .foregroundStyle(
                        isBookmarked
                            ? AnyShapeStyle(.tint)
                            : AnyShapeStyle(.primary)
                    )
            }
            .disabled(isChangingBookmark)
            .accessibilityLabel(isBookmarked ? "取消收藏" : "收藏")

            ShareLink(item: shareURL) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享作品")

            downloadControl
        }
    }

    @ViewBuilder
    private var downloadControl: some View {
        if pageCount > 1 {
            Menu {
                Button("下载全部 \(pageCount) 页", systemImage: "square.and.arrow.down") {
                    onDownloadAll()
                }
                Divider()
                ForEach(0..<pageCount, id: \.self) { index in
                    Button("下载第 \(index + 1) 页") {
                        onDownload(index)
                    }
                }
            } label: {
                Image(systemName: "arrow.down.to.line")
            }
            .accessibilityLabel("下载作品")
        } else {
            Button {
                onDownload(0)
            } label: {
                Image(systemName: "arrow.down.to.line")
            }
            .accessibilityLabel("下载作品")
        }
    }
}

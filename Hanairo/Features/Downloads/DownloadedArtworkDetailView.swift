import SwiftUI

struct DownloadedArtworkDetailView: View {
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    let recordID: String

    @State private var viewer: DownloadedPageViewerContext?

    var body: some View {
        Group {
            if let record {
                recordContent(record)
            } else {
                ContentUnavailableView("下载记录不存在", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle("下载详情")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $viewer) { context in
            DownloadedPageViewer(context: context)
        }
    }

    private func recordContent(_ record: ArtworkDownloadRecord) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.title)
                        .font(.title2.weight(.bold))
                        .textSelection(.enabled)
                    Text(record.artistName)
                        .foregroundStyle(.secondary)
                    Label(record.detailText, systemImage: record.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(record.isComplete ? .green : .orange)
                }

                if record.destination == .photoLibrary {
                    ContentUnavailableView(
                        "图片已保存到相册",
                        systemImage: "photo.on.rectangle",
                        description: Text("Hanairo 只保留下载记录，不会重复保存相册图片。")
                    )
                    .frame(minHeight: 260)
                } else {
                    ForEach(record.pages) { page in
                        if let url = downloadManager.localURL(for: record, page: page) {
                            VStack(alignment: .trailing, spacing: 8) {
                                Button {
                                    viewer = DownloadedPageViewerContext(
                                        pageIndex: page.pageIndex,
                                        url: url
                                    )
                                } label: {
                                    LocalImageView(url: url, contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 480)
                                        .background(.black.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .clipped()
                                }
                                .buttonStyle(.plain)

                                ShareLink(item: url) {
                                    Label("导出第 \(page.pageIndex + 1) 页", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Color.gray.opacity(0.28)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    Text("第 \(page.pageIndex + 1) 页文件不存在")
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                }

                NavigationLink(value: AppRoute.illustration(id: record.illustrationID)) {
                    Label("查看在线作品", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .padding(.bottom, 20)
        }
    }

    private var record: ArtworkDownloadRecord? {
        downloadManager.records.first { $0.id == recordID }
    }
}

private struct DownloadedPageViewerContext: Identifiable {
    let pageIndex: Int
    let url: URL

    var id: String { "\(pageIndex)-\(url.path)" }
}

private struct DownloadedPageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let context: DownloadedPageViewerContext

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ZoomableMediaView {
                LocalImageView(url: context.url, contentMode: .fit)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.leading, 14)
            .accessibilityLabel("关闭")
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

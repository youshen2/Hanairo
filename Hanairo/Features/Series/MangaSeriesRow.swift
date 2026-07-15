import SwiftUI

struct MangaSeriesRow: View {
    let series: PixivMangaSeriesSummary
    let onRemove: () async -> Void

    @State private var isRemoving = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            NavigationLink(value: AppRoute.illustrationSeries(id: series.id)) {
                HStack(alignment: .top, spacing: 12) {
                    RemoteImageView(url: series.coverURL)
                        .frame(width: 92, height: 122)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .clipped()
                        .overlay(alignment: .topTrailing) {
                            Text(series.publishedContentCount, format: .number)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.58), in: Capsule())
                                .padding(6)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(series.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if let name = series.user?.name, !name.isEmpty {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let date = series.lastPublishedContentDate {
                            Text(String(date.prefix(10)))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 12) {
                if series.latestContentID > 0 {
                    NavigationLink(value: AppRoute.illustration(id: series.latestContentID)) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                    .accessibilityLabel("查看最新一话")
                }

                Menu {
                    Button("取消追更", systemImage: "minus.circle", role: .destructive) {
                        remove()
                    }
                } label: {
                    if isRemoving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
                .disabled(isRemoving)
                .accessibilityLabel("系列操作")
            }
        }
        .padding(.vertical, 6)
    }

    private func remove() {
        guard !isRemoving else { return }
        Task {
            isRemoving = true
            await onRemove()
            isRemoving = false
        }
    }
}

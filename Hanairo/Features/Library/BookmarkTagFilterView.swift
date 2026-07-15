import SwiftUI

struct BookmarkTagFilterView: View {
    let tags: [PixivBookmarkTag]
    let phase: PaginationPhase
    let isLoadingMore: Bool
    let errorMessage: String?
    @Binding var selection: String?
    let onRetry: () async -> Void
    let onLoadMore: () async -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                tagButton(title: "全部", count: nil, tag: nil)

                ForEach(tags) { tag in
                    tagButton(title: tag.name, count: tag.count, tag: tag.name)
                        .task {
                            guard tag.id == tags.last?.id else { return }
                            await onLoadMore()
                        }
                }

                trailingStatus
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func tagButton(title: String, count: Int?, tag: String?) -> some View {
        Button {
            selection = tag
        } label: {
            HStack(spacing: 5) {
                Text(title)
                if let count {
                    Text(count, format: .number)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(selection == tag ? .accentColor : .secondary)
    }

    @ViewBuilder
    private var trailingStatus: some View {
        switch phase {
        case .idle, .loading:
            ProgressView()
                .controlSize(.small)
                .padding(.horizontal, 8)
        case .failed:
            Button("重试") {
                Task { await onRetry() }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        case .loaded:
            if isLoadingMore {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 8)
            } else if errorMessage != nil {
                Button("重试") {
                    Task { await onLoadMore() }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
    }
}

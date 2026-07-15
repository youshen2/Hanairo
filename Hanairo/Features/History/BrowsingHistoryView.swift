import SwiftUI

struct BrowsingHistoryView: View {
    @Environment(BrowsingHistoryStore.self) private var history
    @Environment(LocalBlockStore.self) private var localBlocks
    @Environment(PixivRepository.self) private var repository

    @State private var query = ""
    @State private var showsClearConfirmation = false
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    normalizedQuery.isEmpty ? "暂无浏览历史" : "没有匹配的历史记录",
                    systemImage: "clock.arrow.circlepath"
                )
                .frame(minHeight: 420)
            } else {
                MasonryGrid(
                    items: filteredEntries,
                    spacing: 12,
                    estimatedHeight: estimatedHeight
                ) { entry in
                    HistoryArtworkCard(
                        entry: entry,
                        onRemove: { history.remove(id: entry.id) }
                    ) {
                        await toggleBookmark(entry)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("浏览历史")
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索标题或作者"
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("清空", systemImage: "trash", role: .destructive) {
                    showsClearConfirmation = true
                }
                .labelStyle(.iconOnly)
                .disabled(history.entries.isEmpty)
            }
        }
        .confirmationDialog(
            "清空全部浏览历史？",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) { history.clear() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不会删除缓存或已下载的图片。")
        }
        .alert("操作失败", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(actionError ?? "未知错误")
        }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredEntries: [BrowsingHistoryEntry] {
        history.entries.filter { entry in
            guard !localBlocks.isBlocked(entry.illustration) else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return entry.illustration.title.localizedCaseInsensitiveContains(normalizedQuery)
                || entry.illustration.user.name.localizedCaseInsensitiveContains(normalizedQuery)
                || entry.illustration.user.account.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )
    }

    private func toggleBookmark(_ entry: BrowsingHistoryEntry) async {
        do {
            let value = try await repository.toggleBookmark(entry.illustration)
            history.updateBookmark(id: entry.id, isBookmarked: value)
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func estimatedHeight(for entry: BrowsingHistoryEntry) -> CGFloat {
        let ratio = entry.illustration.aspectRatio > 0 ? entry.illustration.aspectRatio : 0.75
        return 1 / ratio + 0.42
    }
}

private struct HistoryArtworkCard: View {
    let entry: BrowsingHistoryEntry
    let onRemove: () -> Void
    let onBookmark: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topLeading) {
                ArtworkCard(
                    illustration: entry.illustration,
                    previewAspectRatio: entry.illustration.aspectRatio > 0
                        ? entry.illustration.aspectRatio
                        : 0.75,
                    onBookmark: onBookmark
                )
                Menu {
                    Button("从历史中移除", systemImage: "trash", role: .destructive) {
                        onRemove()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(8)
            }
            Text(entry.viewedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview("浏览历史") {
    NavigationStack {
        BrowsingHistoryView()
    }
    .withPreviewDependencies()
}

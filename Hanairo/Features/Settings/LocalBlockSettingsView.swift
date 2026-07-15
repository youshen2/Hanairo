import SwiftUI

struct LocalBlockSettingsView: View {
    @Environment(LocalBlockStore.self) private var localBlocks

    @State private var showsAddTag = false
    @State private var newTag = ""
    @State private var showsClearConfirmation = false

    var body: some View {
        List {
            if localBlocks.totalCount == 0 {
                ContentUnavailableView(
                    "没有本地屏蔽内容",
                    systemImage: "hand.raised",
                    description: Text("可在作品卡片、作品详情、评论区或作者主页中添加屏蔽。")
                )
            }

            if !localBlocks.tags.isEmpty {
                Section("标签") {
                    ForEach(localBlocks.tags) { tag in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("#\(tag.displayName)")
                            if tag.translatedName != nil {
                                Text(tag.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.tags[$0].id }
                            .forEach(localBlocks.removeTag(id:))
                    }
                }
            }

            if !localBlocks.users.isEmpty {
                Section("作者") {
                    ForEach(localBlocks.users) { user in
                        LabeledContent(user.name, value: "ID \(user.id)")
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.users[$0].id }
                            .forEach(localBlocks.removeUser(id:))
                    }
                }
            }

            if !localBlocks.artworks.isEmpty {
                Section("作品") {
                    ForEach(localBlocks.artworks) { artwork in
                        LabeledContent(artwork.title, value: "ID \(artwork.id)")
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.artworks[$0].id }
                            .forEach(localBlocks.removeArtwork(id:))
                    }
                }
            }

            if !localBlocks.comments.isEmpty {
                Section("评论") {
                    ForEach(localBlocks.comments) { comment in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(comment.authorName)
                                .font(.subheadline.weight(.semibold))
                            Text(comment.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.comments[$0].id }
                            .forEach(localBlocks.removeComment(id:))
                    }
                }
            }
        }
        .navigationTitle("本地屏蔽")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("添加标签", systemImage: "plus") {
                    newTag = ""
                    showsAddTag = true
                }
                .labelStyle(.iconOnly)

                Button("清空", systemImage: "trash", role: .destructive) {
                    showsClearConfirmation = true
                }
                .labelStyle(.iconOnly)
                .disabled(localBlocks.totalCount == 0)
            }
        }
        .alert("添加屏蔽标签", isPresented: $showsAddTag) {
            TextField("标签名称", text: $newTag)
            Button("取消", role: .cancel) {}
            Button("添加") {
                localBlocks.blockTag(name: newTag)
            }
        }
        .confirmationDialog(
            "清空全部本地屏蔽？",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) { localBlocks.clear() }
            Button("取消", role: .cancel) {}
        }
    }
}

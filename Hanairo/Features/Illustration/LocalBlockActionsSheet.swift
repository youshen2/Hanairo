import SwiftUI

enum LocalBlockAction: Hashable {
    case artwork
    case user
    case tag(String)
}

struct LocalBlockActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalBlockStore.self) private var localBlocks

    let illustration: PixivIllustration
    let onBlocked: (LocalBlockAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("作品与作者") {
                    Button("屏蔽作品《\(illustration.title)》", systemImage: "photo.badge.minus", role: .destructive) {
                        localBlocks.block(artwork: illustration)
                        finish(.artwork)
                    }
                    Button("屏蔽作者 \(illustration.user.name)", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                        localBlocks.block(user: illustration.user)
                        finish(.user)
                    }
                }

                if !illustration.tags.isEmpty {
                    Section("标签") {
                        ForEach(illustration.tags) { tag in
                            Button {
                                localBlocks.block(tag: tag)
                                finish(.tag(tag.name))
                            } label: {
                                HStack {
                                    Text("#\(tag.displayName)")
                                    Spacer()
                                    if localBlocks.isTagBlocked(tag.name) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(localBlocks.isTagBlocked(tag.name))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("本地屏蔽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func finish(_ action: LocalBlockAction) {
        onBlocked(action)
        dismiss()
    }
}

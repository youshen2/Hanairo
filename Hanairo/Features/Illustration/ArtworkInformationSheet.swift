import SwiftUI

struct ArtworkInformationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let illustration: PixivIllustration

    var body: some View {
        NavigationStack {
            Form {
                Section("作品") {
                    LabeledContent("标题", value: illustration.title)
                    LabeledContent("作品 ID", value: String(illustration.id))
                    LabeledContent("作者", value: illustration.user.name)
                    LabeledContent("作者 ID", value: String(illustration.user.id))
                    LabeledContent("页数", value: String(illustration.pageCount))
                    LabeledContent("尺寸", value: "\(illustration.width) × \(illustration.height)")
                    if !illustration.createDate.isEmpty {
                        LabeledContent("发布日期", value: String(illustration.createDate.prefix(10)))
                    }
                }

                if !illustration.tags.isEmpty {
                    Section("标签") {
                        Text(illustration.tags.map { "#\($0.displayName)" }.joined(separator: "  "))
                            .textSelection(.enabled)
                    }
                }

                let caption = TextSanitizer.plainText(from: illustration.caption)
                if !caption.isEmpty {
                    Section("简介") {
                        Text(caption)
                            .textSelection(.enabled)
                    }
                }

                Section("分享") {
                    ShareLink(item: shareText) {
                        Label("分享作品信息", systemImage: "doc.text")
                    }
                    ShareLink(item: PixivWebLinks.artwork(id: illustration.id)) {
                        Label("分享作品链接", systemImage: "link")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("作品信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var shareText: String {
        [
            "标题：\(illustration.title)",
            "作者：\(illustration.user.name)",
            "作品 ID：\(illustration.id)",
            PixivWebLinks.artwork(id: illustration.id).absoluteString
        ].joined(separator: "\n")
    }
}

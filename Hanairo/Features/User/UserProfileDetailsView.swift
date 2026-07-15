import SwiftUI

struct UserProfileDetailsView: View {
    let detail: PixivUserDetail

    @State private var showsWorkspace = false

    @ViewBuilder
    var body: some View {
#if os(visionOS)
        content
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                content
            }
        } else {
            content
        }
#endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            FloatingGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("关于")
                        .font(.title3.weight(.bold))

                    Text(profileComment)
                        .font(.body)
                        .foregroundStyle(hasProfileComment ? .primary : .secondary)
                        .textSelection(.enabled)

                    if !profileRows.isEmpty || !profileLinks.isEmpty {
                        Divider()
                            .padding(.vertical, 2)
                    }

                    ForEach(profileRows, id: \.label) { row in
                        LabeledContent(row.label, value: row.value)
                    }
                    if !profileLinks.isEmpty {
                        profileLinkButtons
                    }
                }
                .font(.subheadline)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let workspace = detail.workspace, !workspaceRows(workspace).isEmpty {
                FloatingGlassCard {
                    VStack(spacing: 10) {
                        workspaceButton

                        if showsWorkspace {
                            VStack(spacing: 10) {
                                ForEach(workspaceRows(workspace), id: \.label) { row in
                                    LabeledContent(row.label, value: row.value)
                                }
                            }
                            .font(.subheadline)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var workspaceButton: some View {
        workspaceAction
            .buttonStyle(.plain)
    }

    private var workspaceAction: some View {
        Button {
            withAnimation(.snappy(duration: 0.24)) {
                showsWorkspace.toggle()
            }
        } label: {
            HStack {
                Text("创作环境")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(showsWorkspace ? 180 : 0))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(showsWorkspace ? "收起创作环境" : "展开创作环境")
    }

    @ViewBuilder
    private var profileLinkButtons: some View {
#if os(visionOS)
        profileLinkButtons(usesGlass: false)
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            profileLinkButtons(usesGlass: true)
        } else {
            profileLinkButtons(usesGlass: false)
        }
#endif
    }

    private func profileLinkButtons(usesGlass: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(profileLinks, id: \.url) { link in
                UserProfileLinkButton(link: link, usesGlass: usesGlass)
            }
        }
    }

    private var hasProfileComment: Bool {
        guard let comment = detail.user.comment else { return false }
        return !TextSanitizer.plainText(from: comment).isEmpty
    }

    private var profileComment: String {
        guard let comment = detail.user.comment else { return "这位作者还没有填写简介" }
        let plainText = TextSanitizer.plainText(from: comment)
        return plainText.isEmpty ? "这位作者还没有填写简介" : plainText
    }

    private var profileRows: [ProfileRow] {
        [
            profileRow(label: "地区", value: detail.profile.region),
            profileRow(label: "职业", value: detail.profile.job),
            profileRow(label: "生日", value: detail.profile.birth)
        ].compactMap { $0 }
    }

    private var profileLinks: [ProfileLink] {
        var links: [ProfileLink] = []
        if let url = detail.profile.webpage {
            links.append(ProfileLink(title: "个人网站", url: url))
        }
        if let url = detail.profile.twitterURL {
            let title = detail.profile.twitterAccount.map { "X / Twitter @\($0)" } ?? "X / Twitter"
            links.append(ProfileLink(title: title, url: url))
        }
        if let url = detail.profile.pawooURL {
            links.append(ProfileLink(title: "Pawoo", url: url))
        }
        return links
    }

    private func workspaceRows(_ workspace: PixivUserWorkspace) -> [ProfileRow] {
        [
            profileRow(label: "电脑", value: workspace.computer),
            profileRow(label: "显示器", value: workspace.monitor),
            profileRow(label: "创作工具", value: workspace.tool),
            profileRow(label: "数位板", value: workspace.tablet),
            profileRow(label: "音乐", value: workspace.music),
            profileRow(label: "桌子", value: workspace.desk),
            profileRow(label: "椅子", value: workspace.chair),
            profileRow(label: "说明", value: workspace.comment)
        ].compactMap { $0 }
    }

    private func profileRow(label: String, value: String?) -> ProfileRow? {
        guard let value, !value.isEmpty else { return nil }
        return ProfileRow(label: label, value: value)
    }
}

private struct ProfileRow {
    let label: String
    let value: String
}

private struct ProfileLink {
    let title: String
    let url: URL
}

private struct UserProfileLinkButton: View {
    let link: ProfileLink
    let usesGlass: Bool

    @ViewBuilder
    var body: some View {
#if os(visionOS)
        fallback
#else
        if #available(iOS 26.0, macOS 26.0, *), usesGlass {
            linkView
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            fallback
        }
#endif
    }

    private var linkView: some View {
        Link(destination: link.url) {
            Label(link.title, systemImage: "arrow.up.right.square")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var fallback: some View {
        linkView
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
    }
}

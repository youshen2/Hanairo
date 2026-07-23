import SwiftUI

struct MoreView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @State private var showsSignOutConfirmation = false

    var body: some View {
        List {
            accountSection

            Section("Pixiv") {
                NavigationLink(value: AppRoute.mangaWatchlist) {
                    Label("漫画追更", systemImage: "books.vertical")
                }
                NavigationLink(value: AppRoute.downloads) {
                    Label("下载管理", systemImage: "arrow.down.circle")
                }
                NavigationLink(value: AppRoute.browsingHistory) {
                    Label("浏览历史", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Hanairo") {
                NavigationLink(value: AppRoute.settings) {
                    Label("设置", systemImage: "gearshape")
                }
                NavigationLink(value: AppRoute.about) {
                    Label("关于", systemImage: "info.circle")
                }
            }

            Section("链接") {
                Link(destination: URL(string: "https://www.pixiv.net")!) {
                    Label("打开 Pixiv", systemImage: "arrow.up.right.square")
                }
            }

            Section {
                Text("Hanairo 是非官方 Pixiv 客户端，与 pixiv Inc. 没有隶属关系。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我的")
        .confirmationDialog(
            "退出当前账户？",
            isPresented: $showsSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                authentication.signOut()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("本机钥匙串中的 Pixiv 令牌将被删除。")
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("账户") {
            if let account = authentication.account, let id = account.numericID {
                let preview = PixivUser(
                    id: id,
                    name: account.name,
                    account: account.account,
                    profileImageURLs: .init(
                        medium: account.profileImageURLs.large
                            ?? account.profileImageURLs.medium
                    )
                )

                NavigationLink(value: AppRoute.user(id: id, preview: preview)) {
                    HStack(spacing: 12) {
                        RemoteImageView(
                            url: account.profileImageURLs.large ?? account.profileImageURLs.medium
                        )
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                        .clipped()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.name)
                                .font(.headline)
                            Text("@\(account.account)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .appNavigationTransitionSource(for: .user(id: id))
                }
                Button("退出登录", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    showsSignOutConfirmation = true
                }
            }
        }
    }
}

#Preview("我的") {
    NavigationStack {
        MoreView()
    }
    .withPreviewDependencies()
}

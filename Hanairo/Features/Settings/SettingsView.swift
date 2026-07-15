import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("界面与内容") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("外观与图片", systemImage: "paintbrush")
                }

                NavigationLink {
                    ContentSettingsView()
                } label: {
                    Label("内容过滤", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            Section("Pixiv 交互") {
                NavigationLink {
                    InteractionSettingsView()
                } label: {
                    Label("收藏与关注", systemImage: "heart.text.square")
                }
            }

            Section("连接") {
                NavigationLink {
                    NetworkSettingsView()
                } label: {
                    Label("网络", systemImage: "network")
                }
            }

            Section("文件与存储") {
                NavigationLink {
                    DownloadSettingsView()
                } label: {
                    Label("下载", systemImage: "arrow.down.circle")
                }

                NavigationLink {
                    CacheSettingsView()
                } label: {
                    Label("缓存", systemImage: "internaldrive")
                }
            }

            Section("隐私与本地数据") {
                NavigationLink(value: AppRoute.localDataSettings) {
                    Label("历史与屏蔽", systemImage: "hand.raised")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
}

#Preview("设置") {
    NavigationStack {
        SettingsView()
    }
    .withPreviewDependencies()
}

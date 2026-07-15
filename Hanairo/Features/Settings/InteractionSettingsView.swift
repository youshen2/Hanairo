import SwiftUI

struct InteractionSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("默认收藏范围", selection: $settings.defaultBookmarkVisibility) {
                    ForEach(PixivVisibility.allCases) { visibility in
                        Text(visibility.title).tag(visibility)
                    }
                }

                Picker("默认关注范围", selection: $settings.defaultFollowVisibility) {
                    ForEach(PixivVisibility.allCases) { visibility in
                        Text(visibility.title).tag(visibility)
                    }
                }
            } header: {
                Text("默认可见性")
            } footer: {
                Text("快速收藏或关注时使用这里的范围；在作品与作者页面仍可单独修改。")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("收藏与关注")
    }
}

#Preview("收藏与关注设置") {
    NavigationStack {
        InteractionSettingsView()
    }
    .withPreviewDependencies()
}

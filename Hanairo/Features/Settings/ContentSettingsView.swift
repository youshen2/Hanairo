import SwiftUI

struct ContentSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("显示 AI 生成作品", isOn: $settings.showsAIArtwork)
                Toggle("显示成人向作品", isOn: $settings.showsMatureArtwork)
            } footer: {
                Text("过滤设置会在下一次刷新列表时生效。成人向内容默认关闭。")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("内容过滤")
    }
}

#Preview("内容过滤") {
    NavigationStack {
        ContentSettingsView()
    }
    .withPreviewDependencies()
}

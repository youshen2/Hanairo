import SwiftUI

struct LocalDataSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(BrowsingHistoryStore.self) private var history
    @Environment(LocalBlockStore.self) private var localBlocks

    @State private var showsClearHistoryConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("记录浏览历史", isOn: $settings.recordsBrowsingHistory)
                Stepper(
                    "最多保留 \(settings.browsingHistoryLimit) 条",
                    value: $settings.browsingHistoryLimit,
                    in: AppSettings.browsingHistoryLimitRange,
                    step: 50
                )
                .onChange(of: settings.browsingHistoryLimit) {
                    history.applyCurrentLimit()
                }
                NavigationLink(value: AppRoute.browsingHistory) {
                    LabeledContent("管理浏览历史", value: "\(history.entries.count)")
                }
                Button("清空浏览历史", systemImage: "trash", role: .destructive) {
                    showsClearHistoryConfirmation = true
                }
                .disabled(history.entries.isEmpty)
            } header: {
                Text("浏览历史")
            } footer: {
                Text("历史仅保存在本机，不会同步到 Pixiv。关闭记录后不会自动删除现有历史。")
            }

            Section {
                NavigationLink {
                    LocalBlockSettingsView()
                } label: {
                    LabeledContent("管理屏蔽内容", value: "\(localBlocks.totalCount)")
                }
            } header: {
                Text("本地屏蔽")
            } footer: {
                Text("本地屏蔽不会修改 Pixiv 账户，只影响 Hanairo 内显示的作品与作者。")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("历史与屏蔽")
        .confirmationDialog(
            "清空全部浏览历史？",
            isPresented: $showsClearHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) { history.clear() }
            Button("取消", role: .cancel) {}
        }
    }
}

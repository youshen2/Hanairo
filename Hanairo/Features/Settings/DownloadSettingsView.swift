import SwiftUI

struct DownloadSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    @State private var storageUsage: ArtworkDownloadStorageUsage?

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("默认保存位置", selection: $settings.downloadDestination) {
                    ForEach(ArtworkDownloadDestination.allCases) { destination in
                        Text(destination.title).tag(destination)
                    }
                }
            } header: {
                Text("保存位置")
            } footer: {
                Text("相册会在任务完成一页后直接写入照片；文件会保存到系统文件中的 Hanairo Downloads，并可在下载详情中逐页导出。")
            }

            Section {
                Stepper(
                    value: $settings.downloadConcurrentTaskCount,
                    in: AppSettings.downloadConcurrentTaskRange
                ) {
                    LabeledContent("同时任务数", value: "\(settings.downloadConcurrentTaskCount)")
                }

                Stepper(
                    value: $settings.downloadRetryCount,
                    in: AppSettings.downloadRetryRange
                ) {
                    LabeledContent("失败重试", value: "\(settings.downloadRetryCount) 次")
                }

                Toggle("优先读取图片缓存", isOn: $settings.downloadReadsImageCache)
                Toggle("下载时自动收藏", isOn: $settings.bookmarksOnDownload)
            } header: {
                Text("任务")
            } footer: {
                Text("自动收藏会使用默认收藏范围。正在运行的任务会在每页结束后响应暂停；应用重启后，未完成任务会恢复到等待状态。")
            }

            Section("下载管理") {
                LabeledContent("下载记录", value: "\(downloadManager.records.count) 个")
                if let storageUsage {
                    LabeledContent(
                        "本地占用",
                        value: ByteCountFormatter.string(
                            fromByteCount: storageUsage.totalBytes,
                            countStyle: .file
                        )
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("下载")
        .task(id: usageRequestKey) {
            storageUsage = await downloadManager.storageUsage()
        }
    }

    private var usageRequestKey: String {
        "\(downloadManager.tasks.count)-\(downloadManager.records.count)"
    }
}

#Preview("下载") {
    NavigationStack {
        DownloadSettingsView()
    }
    .withPreviewDependencies()
}

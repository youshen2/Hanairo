import SwiftUI

struct DownloadsView: View {
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    @State private var section: DownloadsSection = .queue
    @State private var showsClearConfirmation = false

    var body: some View {
        List {
            Picker("下载内容", selection: $section) {
                ForEach(DownloadsSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch section {
            case .queue:
                queueContent
            case .completed:
                completedContent
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("下载管理")
        .toolbar {
            if hasContent {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showsClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(section == .queue ? "清空下载队列" : "清空下载记录")
                }
            }
        }
        .alert(clearTitle, isPresented: $showsClearConfirmation) {
            Button("清空", role: .destructive, action: clear)
            Button("取消", role: .cancel) {}
        } message: {
            Text(clearMessage)
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        if downloadManager.tasks.isEmpty {
            ContentUnavailableView(
                "暂无下载任务",
                systemImage: "tray",
                description: Text("作品会从详情页加入下载队列。")
            )
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(downloadManager.tasks) { task in
                    ArtworkDownloadTaskRow(task: task)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if task.status == .paused {
                                Button {
                                    downloadManager.resume(task)
                                } label: {
                                    Label("继续", systemImage: "play.fill")
                                }
                                .tint(.green)
                            } else if task.status == .queued || task.status == .downloading {
                                Button {
                                    downloadManager.pause(task)
                                } label: {
                                    Label("暂停", systemImage: "pause.fill")
                                }
                                .tint(.orange)
                            }

                            Button {
                                downloadManager.prioritize(task)
                            } label: {
                                Label("优先", systemImage: "arrow.up.to.line")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                downloadManager.removeTask(task)
                            } label: {
                                Label("移除", systemImage: "trash")
                            }
                            if task.status == .failed {
                                Button {
                                    downloadManager.retry(task)
                                } label: {
                                    Label("重试", systemImage: "arrow.clockwise")
                                }
                                .tint(.blue)
                            }
                        }
                }
            } footer: {
                Text("右滑可暂停、继续或设为优先；左滑可移除，失败任务可以重试。")
            }
        }
    }

    @ViewBuilder
    private var completedContent: some View {
        if downloadManager.records.isEmpty {
            ContentUnavailableView(
                "暂无下载记录",
                systemImage: "checkmark.circle",
                description: Text("成功保存的图片会显示在这里。")
            )
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(downloadManager.records) { record in
                    NavigationLink(value: AppRoute.downloadRecord(id: record.id)) {
                        ArtworkDownloadRecordRow(record: record)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            downloadManager.removeRecord(record)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("删除文件记录会同时删除 Hanairo Downloads 中对应的本地图片；相册中的图片不会被删除。")
            }
        }
    }

    private var hasContent: Bool {
        section == .queue ? !downloadManager.tasks.isEmpty : !downloadManager.records.isEmpty
    }

    private var clearTitle: String {
        section == .queue ? "清空下载队列？" : "清空下载记录？"
    }

    private var clearMessage: String {
        section == .queue
            ? "所有等待、下载中、暂停和失败的任务都会被移除，已完成的文件不会删除。"
            : "文件记录及 Hanairo Downloads 中的本地图片会被删除，相册中的图片不会删除。"
    }

    private func clear() {
        switch section {
        case .queue: downloadManager.clearTasks()
        case .completed: downloadManager.clearRecords()
        }
    }
}

private enum DownloadsSection: String, CaseIterable, Identifiable {
    case queue
    case completed

    var id: String { rawValue }
    var title: String { self == .queue ? "队列" : "已完成" }
}

#Preview("下载管理") {
    NavigationStack {
        DownloadsView()
    }
    .withPreviewDependencies()
}

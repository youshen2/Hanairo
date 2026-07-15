import Foundation
import SwiftUI

struct CacheSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ImageRepository.self) private var imageRepository
    @Environment(PixivRepository.self) private var repository
    @Environment(UgoiraRepository.self) private var ugoiraRepository

    @State private var imageUsage: CacheUsage?
    @State private var detailUsage: CacheUsage?
    @State private var ugoiraUsage: CacheUsage?
    @State private var pendingClear: CacheClearTarget?
    @State private var activeClear: CacheClearTarget?

    private var totalUsageText: String {
        guard let imageUsage, let detailUsage, let ugoiraUsage else { return "计算中…" }
        return CacheByteCountFormatter.string(
            imageUsage.byteCount + detailUsage.byteCount + ugoiraUsage.byteCount
        )
    }

    private var showsClearConfirmation: Binding<Bool> {
        Binding {
            pendingClear != nil
        } set: { isPresented in
            if !isPresented {
                pendingClear = nil
            }
        }
    }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("总览") {
                LabeledContent("缓存总占用", value: totalUsageText)
            }

            Section {
                CacheUsageRows(usage: imageUsage)

                Stepper(
                    "最大容量：\(settings.imageCacheLimitMB) MB",
                    value: $settings.imageCacheLimitMB,
                    in: AppSettings.imageCacheLimitRange,
                    step: 50
                )

                CacheClearButton(
                    title: "清空图片缓存",
                    isWorking: isClearing(.images),
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.images)
                }
            } header: {
                Text("图片缓存")
            } footer: {
                Text("封面和作品图片会优先使用磁盘缓存；超过容量后会自动删除最久未使用的文件。清理时也会释放内存图片。")
            }

            Section {
                Toggle("启用作品详情缓存", isOn: $settings.detailCacheEnabled)

                CacheUsageRows(usage: detailUsage)

                Stepper(
                    "最大容量：\(settings.detailCacheLimitMB) MB",
                    value: $settings.detailCacheLimitMB,
                    in: AppSettings.detailCacheLimitRange,
                    step: 5
                )
                .disabled(!settings.detailCacheEnabled)

                CacheClearButton(
                    title: "清空作品详情缓存",
                    isWorking: isClearing(.details),
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.details)
                }
            } header: {
                Text("作品详情缓存")
            } footer: {
                Text("开启后，再次打开作品时会先显示本地详情，再从 Pixiv 更新最新数据。关闭不会自动删除已有缓存。")
            }

            Section {
                CacheUsageRows(usage: ugoiraUsage)

                Stepper(
                    "最大容量：\(settings.ugoiraCacheLimitMB) MB",
                    value: $settings.ugoiraCacheLimitMB,
                    in: AppSettings.ugoiraCacheLimitRange,
                    step: 50
                )

                CacheClearButton(
                    title: "清空动图缓存",
                    isWorking: isClearing(.ugoira),
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.ugoira)
                }
            } header: {
                Text("动图缓存")
            } footer: {
                Text("Ugoira 原始压缩包会保存在本地，再次播放时无需重复下载；超过容量后会自动清理最久未使用的文件。")
            }

            Section("清理") {
                CacheClearButton(
                    title: "清空所有缓存",
                    isWorking: activeClear == .all,
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.all)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("缓存")
        .task {
            await prepareAndRefreshUsage()
        }
        .refreshable {
            await refreshUsage()
        }
        .onChange(of: settings.imageCacheLimitMB) { _, _ in
            applyImageCacheCapacity()
        }
        .onChange(of: settings.detailCacheLimitMB) { _, _ in
            applyDetailCacheCapacity()
        }
        .onChange(of: settings.ugoiraCacheLimitMB) { _, _ in
            applyUgoiraCacheCapacity()
        }
        .confirmationDialog(
            pendingClear?.confirmationTitle ?? "清空缓存？",
            isPresented: showsClearConfirmation,
            titleVisibility: .visible,
            presenting: pendingClear
        ) { target in
            Button(target.actionTitle, role: .destructive) {
                performClear(target)
            }
            Button("取消", role: .cancel) {}
        } message: { target in
            Text(target.message)
        }
    }

    private func isClearing(_ target: CacheClearTarget) -> Bool {
        activeClear == target || activeClear == .all
    }

    private func requestClear(_ target: CacheClearTarget) {
        pendingClear = target
    }

    private func performClear(_ target: CacheClearTarget) {
        pendingClear = nil
        Task {
            await clear(target)
        }
    }

    private func applyImageCacheCapacity() {
        Task {
            await imageRepository.updateCacheCapacity()
            await refreshUsage()
        }
    }

    private func applyDetailCacheCapacity() {
        Task {
            await repository.updateDetailCacheCapacity()
            await refreshUsage()
        }
    }

    private func applyUgoiraCacheCapacity() {
        Task {
            await ugoiraRepository.updateCacheCapacity()
            await refreshUsage()
        }
    }

    private func prepareAndRefreshUsage() async {
        await imageRepository.updateCacheCapacity()
        await repository.updateDetailCacheCapacity()
        await ugoiraRepository.updateCacheCapacity()
        await refreshUsage()
    }

    private func refreshUsage() async {
        async let nextImageUsage = imageRepository.cacheUsage()
        async let nextDetailUsage = repository.detailCacheUsage()
        async let nextUgoiraUsage = ugoiraRepository.cacheUsage()
        let usages = await (nextImageUsage, nextDetailUsage, nextUgoiraUsage)
        guard !Task.isCancelled else { return }
        imageUsage = usages.0
        detailUsage = usages.1
        ugoiraUsage = usages.2
    }

    private func clear(_ target: CacheClearTarget) async {
        guard activeClear == nil else { return }
        activeClear = target
        defer { activeClear = nil }

        switch target {
        case .images:
            await imageRepository.clear()
        case .details:
            await repository.clearDetailCache()
        case .ugoira:
            await ugoiraRepository.clear()
        case .all:
            await imageRepository.clear()
            await repository.clearDetailCache()
            await ugoiraRepository.clear()
        }
        await refreshUsage()
    }
}

private struct CacheUsageRows: View {
    let usage: CacheUsage?

    var body: some View {
        if let usage {
            LabeledContent(
                "当前占用",
                value: CacheByteCountFormatter.string(usage.byteCount)
            )
            LabeledContent("缓存项目", value: "\(usage.itemCount) 项")
            ProgressView(value: usage.fraction) {
                Text("容量使用")
            } currentValueLabel: {
                Text(
                    "\(CacheByteCountFormatter.string(usage.byteCount)) / "
                        + CacheByteCountFormatter.string(usage.capacityBytes)
                )
                .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 10) {
                ProgressView()
                Text("正在计算占用…")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CacheClearButton: View {
    let title: String
    let isWorking: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            if isWorking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在清理…")
                }
            } else {
                Label(title, systemImage: "trash")
            }
        }
        .disabled(isDisabled)
    }
}

private enum CacheClearTarget: Equatable {
    case images
    case details
    case ugoira
    case all

    var confirmationTitle: String {
        switch self {
        case .images: "清空图片缓存？"
        case .details: "清空作品详情缓存？"
        case .ugoira: "清空动图缓存？"
        case .all: "清空所有缓存？"
        }
    }

    var actionTitle: String {
        switch self {
        case .images: "清空图片缓存"
        case .details: "清空详情缓存"
        case .ugoira: "清空动图缓存"
        case .all: "全部清空"
        }
    }

    var message: String {
        switch self {
        case .images:
            "将删除缓存的封面和作品图片，不影响已经保存到相册或文件的图片。"
        case .details:
            "将删除本地作品详情，下次打开时会重新从 Pixiv 获取。"
        case .ugoira:
            "将删除本地 Ugoira 压缩包，下次播放时会重新下载。"
        case .all:
            "将删除图片、动图与作品详情缓存，不影响登录状态、收藏或已经下载的文件。"
        }
    }
}

private nonisolated enum CacheByteCountFormatter {
    static func string(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

#Preview("缓存") {
    NavigationStack {
        CacheSettingsView()
    }
    .withPreviewDependencies()
}

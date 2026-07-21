import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    @State private var isCheckingUpdate = false
    @State private var updateAlert: UpdateAlert?

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(Color.accentColor.gradient)
                    Text("Hanairo")
                        .font(.title.weight(.bold))
                    Text("版本 \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }

            Section {
                Button {
                    Task {
                        await checkForUpdates()
                    }
                } label: {
                    HStack {
                        Label(
                            isCheckingUpdate ? "正在检查更新" : "检查更新",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        Spacer()
                        if isCheckingUpdate {
                            ProgressView()
                        }
                    }
                }
                .disabled(isCheckingUpdate)

                Toggle("启动时检查更新", isOn: $settings.checksUpdatesOnLaunch)
            } header: {
                Text("更新")
            } footer: {
                Text("自动检查只会在发现新版本时提示，检查失败不会打断启动。")
            }

            Section("说明") {
                Text("Hanairo 使用 SwiftUI 与系统框架构建，是面向 Pixiv 的第三方客户端。")
                Text("Pixiv、pixiv 及相关标志归 pixiv Inc. 所有。")
            }

            Section("开源许可") {
                Text("Hanairo 依据 Mozilla Public License 2.0（MPL-2.0）发布。")
                Link(destination: AppUpdateService.repositoryURL) {
                    Label("开源地址", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://www.mozilla.org/MPL/2.0/")!) {
                    Label("查看 MPL 2.0", systemImage: "doc.text")
                }
            }

            Section("社区") {
                Link(destination: URL(string: "https://t.me/hanairo_official")!) {
                    HStack {
                        Label("Telegram 群组", systemImage: "paperplane")
                        Spacer()
                        Text("@hanairo_official")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("致谢") {
                Text("功能结构参考了 PixEz Flutter 项目。")
                Link(destination: URL(string: "https://github.com/Notsfsssf/pixez-flutter")!) {
                    Label("PixEz Flutter", systemImage: "arrow.up.right.square")
                }
            }
        }
        .navigationTitle("关于")
        .alert(item: $updateAlert) { alert in
            if let releaseURL = alert.releaseURL {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("打开发布页")) {
                        openURL(releaseURL)
                    },
                    secondaryButton: .cancel(Text("好"))
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    @MainActor
    private func checkForUpdates() async {
        guard !isCheckingUpdate else { return }

        isCheckingUpdate = true
        defer { isCheckingUpdate = false }

        do {
            let result = try await AppUpdateService.checkLatestRelease(currentVersion: version)
            if result.hasUpdate {
                updateAlert = UpdateAlert(
                    title: "发现新版本",
                    message: "当前版本 \(result.currentVersion)，最新版本 \(result.latestVersion)。可以前往发布页查看更新内容。",
                    releaseURL: result.releaseURL
                )
            } else {
                updateAlert = UpdateAlert(
                    title: "已是最新版本",
                    message: "当前版本 \(result.currentVersion) 已是最新版本。",
                    releaseURL: nil
                )
            }
        } catch {
            updateAlert = UpdateAlert(
                title: "检查更新失败",
                message: error.localizedDescription,
                releaseURL: nil
            )
        }
    }

    private struct UpdateAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let releaseURL: URL?
    }
}

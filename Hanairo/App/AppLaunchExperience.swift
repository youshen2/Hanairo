import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    func withAppLaunchExperience(isReady: Bool) -> some View {
        modifier(AppLaunchExperienceModifier(isReady: isReady))
    }
}

private struct AppLaunchExperienceModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    let isReady: Bool

    @State private var didHandleLaunch = false
    @State private var showsRecommendationDialog = false
    @State private var sharesRecommendationAfterDialogDismissal = false
    @State private var showsRecommendationShareSheet = false
    @State private var didRunAutomaticUpdateCheck = false
    @State private var automaticUpdateAlert: AutomaticUpdateAlert?

    func body(content: Content) -> some View {
        content
            .task(id: isReady) {
                guard isReady else { return }
                await handleLaunch()
            }
            .confirmationDialog(
                "喜欢 Hanairo 吗？",
                isPresented: $showsRecommendationDialog,
                titleVisibility: .visible
            ) {
                Button("分享 Hanairo") {
                    shareApplication()
                }
                Button("还是算了") {}
            } message: {
                Text("如果 Hanairo 对你有帮助，欢迎把它推荐给更多人。你的分享会帮助项目被更多用户发现。")
            }
            .onChange(of: showsRecommendationDialog) { _, isPresented in
                guard !isPresented else { return }
#if os(iOS)
                if sharesRecommendationAfterDialogDismissal {
                    sharesRecommendationAfterDialogDismissal = false
                    DispatchQueue.main.async {
                        showsRecommendationShareSheet = true
                    }
                    return
                }
#endif
                Task { await checkForUpdatesOnLaunch() }
            }
            .alert(item: $automaticUpdateAlert) { alert in
                Alert(
                    title: Text("发现新版本"),
                    message: Text(
                        "当前版本 \(alert.currentVersion)，最新版本 \(alert.latestVersion)。可以前往发布页查看更新内容。"
                    ),
                    primaryButton: .default(Text("打开发布页")) {
                        openURL(alert.releaseURL)
                    },
                    secondaryButton: .cancel(Text("稍后"))
                )
            }
#if os(iOS)
            .sheet(isPresented: $showsRecommendationShareSheet, onDismiss: {
                Task { await checkForUpdatesOnLaunch() }
            }) {
                ApplicationRecommendationShareSheet(
                    activityItems: ["我正在使用 Hanairo，推荐你也试试！", AppUpdateService.repositoryURL]
                )
            }
#endif
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    @MainActor
    private func handleLaunch() async {
        guard !didHandleLaunch else { return }
        didHandleLaunch = true

        if AppRecommendationPrompt.recordLaunch() {
            showsRecommendationDialog = true
        } else {
            await checkForUpdatesOnLaunch()
        }
    }

    private func shareApplication() {
#if os(iOS)
        sharesRecommendationAfterDialogDismissal = true
#else
        openURL(AppUpdateService.repositoryURL)
#endif
    }

    @MainActor
    private func checkForUpdatesOnLaunch() async {
        guard settings.checksUpdatesOnLaunch, !didRunAutomaticUpdateCheck else { return }
        didRunAutomaticUpdateCheck = true

        do {
            let result = try await AppUpdateService.checkLatestRelease(currentVersion: appVersion)
            guard result.hasUpdate else { return }

            automaticUpdateAlert = AutomaticUpdateAlert(
                currentVersion: result.currentVersion,
                latestVersion: result.latestVersion,
                releaseURL: result.releaseURL
            )
        } catch {
            // 自动检查失败时不打断启动流程。
        }
    }

    private struct AutomaticUpdateAlert: Identifiable {
        let id = UUID()
        let currentVersion: String
        let latestVersion: String
        let releaseURL: URL
    }
}

#if os(iOS)
private struct ApplicationRecommendationShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

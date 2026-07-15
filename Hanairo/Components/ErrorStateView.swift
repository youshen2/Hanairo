import SwiftUI

struct ErrorStateView: View {
    let message: String
    var usesGlassButton = false
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("加载失败", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            retryButton
        }
    }

    @ViewBuilder
    private var retryButton: some View {
#if os(visionOS)
        fallbackRetryButton
#else
        if #available(iOS 26.0, macOS 26.0, *), usesGlassButton {
            Button("重试", action: retry)
                .buttonStyle(.glassProminent)
        } else {
            fallbackRetryButton
        }
#endif
    }

    private var fallbackRetryButton: some View {
        Button("重试", action: retry)
            .buttonStyle(.borderedProminent)
    }
}

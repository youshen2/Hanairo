import SwiftUI

struct PaginationStatusView: View {
    let isLoading: Bool
    let errorMessage: String?
    var usesGlassButton = false
    let onRetry: () async -> Void

    var body: some View {
        Group {
            if isLoading {
                ProgressView("正在加载更多…")
                    .controlSize(.small)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    retryButton
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isLoading || errorMessage != nil ? 12 : 0)
    }

    @ViewBuilder
    private var retryButton: some View {
#if os(visionOS)
        fallbackRetryButton
#else
        if #available(iOS 26.0, macOS 26.0, *), usesGlassButton {
            retryAction
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            fallbackRetryButton
        }
#endif
    }

    private var retryAction: some View {
        Button("重新加载", systemImage: "arrow.clockwise") {
            Task { await onRetry() }
        }
    }

    private var fallbackRetryButton: some View {
        retryAction
            .buttonStyle(.bordered)
    }
}

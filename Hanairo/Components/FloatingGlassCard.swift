import SwiftUI

struct FloatingGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 28
    @ViewBuilder let content: Content

    init(
        cornerRadius: CGFloat = 28,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
#if os(visionOS)
        fallback
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
        } else {
            fallback
        }
#endif
    }

    private var fallback: some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}

import SwiftUI

struct ZoomableMediaView<Content: View>: View {
    private let content: Content
    private let resetToken: Int
    private let onSingleTap: () -> Void
    private let onZoomChange: (Bool) -> Void

    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero
    @State private var reportedZoomed = false

    init(
        resetToken: Int = 0,
        onSingleTap: @escaping () -> Void = {},
        onZoomChange: @escaping (Bool) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.resetToken = resetToken
        self.onSingleTap = onSingleTap
        self.onZoomChange = onZoomChange
    }

    var body: some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(magnificationGesture(in: proxy.size))
                .simultaneousGesture(
                    dragGesture(in: proxy.size),
                    including: scale > 1.01 ? .gesture : .none
                )
                .simultaneousGesture(tapGesture)
                .onChange(of: resetToken) {
                    resetPosition()
                }
        }
        .clipped()
    }

    private func magnificationGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(settledScale * value.magnification, 1), 5)
                offset = clamped(offset: offset, in: size, scale: scale)
                reportZoomStateIfNeeded()
            }
            .onEnded { _ in
                settledScale = scale
                offset = clamped(offset: offset, in: size, scale: scale)
                settledOffset = offset
                if scale == 1 {
                    resetPosition()
                }
                reportZoomStateIfNeeded()
            }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                let proposed = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
                offset = clamped(offset: proposed, in: size, scale: scale)
            }
            .onEnded { _ in
                settledOffset = offset
            }
    }

    private var tapGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { value in
                switch value {
                case .first:
                    toggleZoom()
                case .second:
                    onSingleTap()
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.snappy(duration: 0.22)) {
            if scale > 1 {
                resetPosition()
            } else {
                scale = 2.5
                settledScale = 2.5
                reportZoomStateIfNeeded()
            }
        }
    }

    private func resetPosition() {
        scale = 1
        settledScale = 1
        offset = .zero
        settledOffset = .zero
        reportZoomStateIfNeeded()
    }

    private func clamped(offset: CGSize, in size: CGSize, scale: CGFloat) -> CGSize {
        let maximumX = size.width * (scale - 1) / 2
        let maximumY = size.height * (scale - 1) / 2
        return CGSize(
            width: min(max(offset.width, -maximumX), maximumX),
            height: min(max(offset.height, -maximumY), maximumY)
        )
    }

    private func reportZoomStateIfNeeded() {
        let isZoomed = scale > 1.01
        guard reportedZoomed != isZoomed else { return }
        reportedZoomed = isZoomed
        onZoomChange(isZoomed)
    }
}

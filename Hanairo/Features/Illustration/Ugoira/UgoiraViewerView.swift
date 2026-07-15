import SwiftUI

struct UgoiraViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let animation: UgoiraAnimation
    let initialFrame: Int
    let title: String

    @State private var player: UgoiraPlayer
    @State private var preparationID = UUID()

    init(animation: UgoiraAnimation, initialFrame: Int, title: String) {
        self.animation = animation
        self.initialFrame = initialFrame
        self.title = title
        _player = State(initialValue: UgoiraPlayer(illustrationID: animation.illustrationID))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                viewerContent
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .topLeading) {
                closeButton
                    .padding(.leading, 12)
                    .padding(.top, proxy.safeAreaInsets.top + 8)
            }
            .overlay(alignment: .bottom) {
                if player.isReady {
                    UgoiraPlaybackControls(player: player)
                        .padding(.horizontal, 12)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 10)
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .presentationBackground(.black)
        .task(id: preparationID) {
            await player.prepare(animation: animation, initialFrame: initialFrame)
        }
        .task(id: player.playbackTaskKey) {
            await player.runPlayback()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            player.setSuspended(phase != .active, reason: .inactiveScene)
        }
#if os(iOS)
        .statusBarHidden(true)
#endif
    }

    @ViewBuilder
    private var viewerContent: some View {
        switch player.phase {
        case .idle, .loading:
            ProgressView("正在准备动图…")
                .tint(.white)
                .foregroundStyle(.white)
        case let .failed(message):
            VStack(spacing: 14) {
                ContentUnavailableView(
                    "动图无法播放",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                Button("重试", systemImage: "arrow.clockwise") {
                    preparationID = UUID()
                }
                .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(.white)
        case .ready:
            ZoomableMediaView {
                UgoiraFrameView(image: player.currentImage)
            }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
#if os(visionOS)
        closeButtonContent
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Circle())
#else
        closeButtonContent
            .buttonStyle(.glass)
#endif
    }

    private var closeButtonContent: some View {
        Button("关闭", systemImage: "xmark") {
            dismiss()
        }
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
        .accessibilityLabel("关闭动图")
    }
}

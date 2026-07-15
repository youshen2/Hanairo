import SwiftUI

struct UgoiraPlayerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(UgoiraRepository.self) private var repository

    let illustration: PixivIllustration

    @State private var player: UgoiraPlayer
    @State private var loadRequestID: UUID?
    @State private var viewerPresentation: UgoiraViewerPresentation?

    init(illustration: PixivIllustration) {
        self.illustration = illustration
        _player = State(initialValue: UgoiraPlayer(illustrationID: illustration.id))
    }

    var body: some View {
        playerContent
            .frame(maxWidth: .infinity)
            .aspectRatio(clampedAspectRatio, contentMode: .fit)
            .background(.black)
            .clipped()
            .task(id: loadRequestID) {
                guard loadRequestID != nil else { return }
                await player.load(using: repository)
            }
            .task(id: player.playbackTaskKey) {
                await player.runPlayback()
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                player.setSuspended(phase != .active, reason: .inactiveScene)
            }
            .viewerPresentation($viewerPresentation, onDismiss: viewerDidDismiss)
    }

    @ViewBuilder
    private var playerContent: some View {
        ZStack {
            switch player.phase {
            case .ready:
                UgoiraFrameView(image: player.currentImage)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        presentViewer()
                    }
            case .idle, .loading, .failed:
                RemoteImageView(url: illustration.previewURL, contentMode: .fit)
            }

            switch player.phase {
            case .idle:
                playButton
            case let .loading(stage):
                loadingOverlay(stage)
            case let .failed(message):
                failureOverlay(message)
            case .ready:
                EmptyView()
            }
        }
        .overlay(alignment: .bottom) {
            if player.isReady {
                UgoiraPlaybackControls(player: player, onFullscreen: presentViewer)
                    .padding(10)
            }
        }
        .overlay(alignment: .topLeading) {
            Label("动图", systemImage: "play.rectangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.58), in: Capsule())
                .padding(10)
        }
    }

    private var playButton: some View {
        Button("播放动图", systemImage: "play.fill") {
            loadRequestID = UUID()
        }
        .labelStyle(.iconOnly)
        .font(.title2.weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: 58, height: 58)
        .background(.black.opacity(0.58), in: Circle())
        .buttonStyle(.plain)
        .accessibilityHint("下载并播放 Ugoira")
    }

    private func loadingOverlay(_ stage: UgoiraLoadingStage) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text(stage.title)
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.62), in: Capsule())
    }

    private func failureOverlay(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Button("重新加载", systemImage: "arrow.clockwise") {
                loadRequestID = UUID()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding()
    }

    private func presentViewer() {
        guard let animation = player.animation else { return }
        player.setSuspended(true, reason: .covered)
        viewerPresentation = UgoiraViewerPresentation(
            animation: animation,
            initialFrame: player.currentFrameIndex,
            title: illustration.title
        )
    }

    private func viewerDidDismiss() {
        player.setSuspended(false, reason: .covered)
    }

    private var clampedAspectRatio: CGFloat {
        min(max(illustration.aspectRatio, 0.42), 1.6)
    }
}

private struct UgoiraViewerPresentation: Identifiable {
    let id = UUID()
    let animation: UgoiraAnimation
    let initialFrame: Int
    let title: String
}

private extension View {
    @ViewBuilder
    func viewerPresentation(
        _ presentation: Binding<UgoiraViewerPresentation?>,
        onDismiss: @escaping () -> Void
    ) -> some View {
#if os(iOS)
        fullScreenCover(item: presentation, onDismiss: onDismiss) { item in
            UgoiraViewerView(
                animation: item.animation,
                initialFrame: item.initialFrame,
                title: item.title
            )
        }
#else
        sheet(item: presentation, onDismiss: onDismiss) { item in
            UgoiraViewerView(
                animation: item.animation,
                initialFrame: item.initialFrame,
                title: item.title
            )
        }
#endif
    }
}

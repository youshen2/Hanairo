import SwiftUI

struct UgoiraPlaybackControls: View {
    let player: UgoiraPlayer
    var onFullscreen: (() -> Void)?

    private let playbackRates = [0.5, 1, 1.5, 2]

    var body: some View {
#if os(visionOS)
        controls
            .padding(4)
            .background(.regularMaterial, in: Capsule())
#else
        controls
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)
#endif
    }

    private var controls: some View {
        HStack(spacing: 2) {
            Button(player.isPlaying ? "暂停" : "播放", systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
                player.togglePlayback()
            }
            .labelStyle(.iconOnly)
            .frame(width: 36, height: 36)
            .buttonStyle(.plain)

            if player.frameCount > 1 {
                Slider(
                    value: frameBinding,
                    in: 0...Double(player.frameCount - 1),
                    step: 1
                ) { isEditing in
                    player.setSuspended(isEditing, reason: .seeking)
                }
                .frame(minWidth: 76, maxWidth: 170)
                .accessibilityLabel("动图进度")

                Text("\(player.currentFrameIndex + 1)/\(player.frameCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 42)
            }

            Menu {
                ForEach(playbackRates, id: \.self) { rate in
                    Button {
                        player.setPlaybackRate(rate)
                    } label: {
                        if player.playbackRate == rate {
                            Label(rateTitle(rate), systemImage: "checkmark")
                        } else {
                            Text(rateTitle(rate))
                        }
                    }
                }
            } label: {
                Text(rateTitle(player.playbackRate))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("播放速度")

            if let onFullscreen {
                Button("全屏", systemImage: "arrow.up.left.and.arrow.down.right") {
                    onFullscreen()
                }
                .labelStyle(.iconOnly)
                .frame(width: 36, height: 36)
                .buttonStyle(.plain)
            }
        }
    }

    private var frameBinding: Binding<Double> {
        Binding(
            get: { Double(player.currentFrameIndex) },
            set: { player.seek(to: Int($0.rounded())) }
        )
    }

    private func rateTitle(_ rate: Double) -> String {
        rate == rate.rounded() ? "\(Int(rate))×" : "\(rate.formatted(.number.precision(.fractionLength(1))))×"
    }
}

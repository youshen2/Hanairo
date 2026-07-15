import CoreGraphics
import Foundation
import Observation

enum UgoiraPlayerPhase: Equatable {
    case idle
    case loading(UgoiraLoadingStage)
    case ready
    case failed(String)
}

enum UgoiraPlaybackSuspension: Hashable {
    case covered
    case inactiveScene
    case seeking
}

nonisolated struct UgoiraPlaybackTaskKey: Hashable {
    let isReady: Bool
    let isPlaying: Bool
    let playbackRate: Double
    let revision: Int
}

@MainActor
@Observable
final class UgoiraPlayer {
    let illustrationID: Int

    private(set) var phase: UgoiraPlayerPhase = .idle
    private(set) var animation: UgoiraAnimation?
    private(set) var currentImage: CGImage?
    private(set) var currentFrameIndex = 0
    private(set) var playbackRate = 1.0
    private(set) var wantsToPlay = true
    private(set) var suspensions: Set<UgoiraPlaybackSuspension> = []
    private(set) var playbackRevision = 0

    @ObservationIgnored private var decoder: UgoiraFrameDecoder?
    @ObservationIgnored private var frameTask: Task<Void, Never>?
    @ObservationIgnored private var activeFrameRequest = UUID()

    init(illustrationID: Int) {
        self.illustrationID = illustrationID
    }

    var isReady: Bool {
        phase == .ready
    }

    var isPlaying: Bool {
        isReady && wantsToPlay && suspensions.isEmpty
    }

    var frameCount: Int {
        animation?.frames.count ?? 0
    }

    var playbackTaskKey: UgoiraPlaybackTaskKey {
        UgoiraPlaybackTaskKey(
            isReady: isReady,
            isPlaying: isPlaying,
            playbackRate: playbackRate,
            revision: playbackRevision
        )
    }

    func load(using repository: UgoiraRepository) async {
        guard phase != .ready else { return }
        do {
            let animation = try await repository.animation(for: illustrationID) { [weak self] stage in
                self?.phase = .loading(stage)
            }
            try Task.checkCancellation()
            await prepare(animation: animation, initialFrame: 0)
        } catch is CancellationError {
            if phase != .ready {
                phase = .idle
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func prepare(animation: UgoiraAnimation, initialFrame: Int) async {
        guard !animation.frames.isEmpty else {
            phase = .failed(UgoiraError.emptyFrames.localizedDescription)
            return
        }
        if
            phase == .ready,
            self.animation?.illustrationID == animation.illustrationID
        {
            return
        }

        phase = .loading(.decodingFirstFrame)
        let decoder = UgoiraFrameDecoder(frames: animation.frames)
        let target = min(max(initialFrame, 0), animation.frames.count - 1)
        do {
            let image = try await decoder.image(at: target)
            try Task.checkCancellation()
            self.animation = animation
            self.decoder = decoder
            currentFrameIndex = target
            currentImage = image
            wantsToPlay = true
            suspensions.removeAll()
            playbackRevision &+= 1
            phase = .ready
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func runPlayback() async {
        guard
            isPlaying,
            let animation,
            let decoder,
            !animation.frames.isEmpty
        else {
            return
        }

        while !Task.isCancelled, isPlaying {
            let sourceIndex = currentFrameIndex
            let nextIndex = (sourceIndex + 1) % animation.frames.count
            let delay = animation.frames[sourceIndex].duration / playbackRate

            do {
                async let nextImage = decoder.image(at: nextIndex)
                try await ContinuousClock().sleep(for: .seconds(delay))
                let image = try await nextImage
                try Task.checkCancellation()
                guard isPlaying, currentFrameIndex == sourceIndex else { return }
                currentFrameIndex = nextIndex
                currentImage = image
            } catch is CancellationError {
                return
            } catch {
                wantsToPlay = false
                phase = .failed(error.localizedDescription)
                return
            }
        }
    }

    func togglePlayback() {
        guard isReady else { return }
        wantsToPlay.toggle()
        playbackRevision &+= 1
    }

    func setPlaybackRate(_ rate: Double) {
        guard rate > 0, playbackRate != rate else { return }
        playbackRate = rate
        playbackRevision &+= 1
    }

    func seek(to frameIndex: Int) {
        guard
            let animation,
            let decoder,
            !animation.frames.isEmpty
        else {
            return
        }

        let target = min(max(frameIndex, 0), animation.frames.count - 1)
        guard target != currentFrameIndex else { return }

        playbackRevision &+= 1
        frameTask?.cancel()
        let requestID = UUID()
        activeFrameRequest = requestID
        frameTask = Task { [weak self] in
            do {
                let image = try await decoder.image(at: target)
                try Task.checkCancellation()
                guard let self, self.activeFrameRequest == requestID else { return }
                self.currentFrameIndex = target
                self.currentImage = image
            } catch is CancellationError {
                return
            } catch {
                self?.wantsToPlay = false
                self?.phase = .failed(error.localizedDescription)
            }
        }
    }

    func setSuspended(_ suspended: Bool, reason: UgoiraPlaybackSuspension) {
        let changed: Bool
        if suspended {
            changed = suspensions.insert(reason).inserted
        } else {
            changed = suspensions.remove(reason) != nil
        }
        if changed {
            playbackRevision &+= 1
        }
    }
}

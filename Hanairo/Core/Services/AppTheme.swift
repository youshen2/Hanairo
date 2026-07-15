import Observation
import SwiftUI

@MainActor
@Observable
final class AppTheme {
    private(set) var accentColor: Color = .pink

    @ObservationIgnored private let imageRepository: ImageRepository
    @ObservationIgnored private var cachedColors: [URL: Color] = [:]
    @ObservationIgnored private var accountImageURL: URL?

    init(imageRepository: ImageRepository) {
        self.imageRepository = imageRepository
    }

    func updateAccountAccent(imageURL: URL?) async {
        accountImageURL = imageURL
        guard let imageURL else {
            accentColor = .pink
            return
        }
        let color = await accentColor(for: imageURL)
        guard !Task.isCancelled, accountImageURL == imageURL else { return }
        accentColor = color ?? .pink
    }

    func accentColor(for imageURL: URL?) async -> Color? {
        guard let imageURL else { return nil }
        if let cachedColor = cachedColors[imageURL] {
            return cachedColor
        }
        do {
            let image = try await imageRepository.image(for: imageURL)
            guard !Task.isCancelled, let color = ImageAccentColorExtractor.color(from: image) else {
                return nil
            }
            cachedColors[imageURL] = color
            return color
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }
}

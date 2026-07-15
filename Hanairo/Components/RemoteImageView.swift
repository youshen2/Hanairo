import SwiftUI

struct RemoteImageView: View {
    @Environment(ImageRepository.self) private var imageRepository

    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: CGImage?
    @State private var loadedURL: URL?
    @State private var didFail = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear

                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                } else if didFail {
                    Color.gray.opacity(0.28)
                        .accessibilityLabel("图片加载失败")
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("正在加载图片")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipped()
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        if let url, loadedURL == url, image != nil {
            return
        }
        image = nil
        loadedURL = nil
        didFail = false
        guard let url else {
            didFail = true
            return
        }
        do {
            let loadedImage = try await imageRepository.image(for: url)
            guard !Task.isCancelled, self.url == url else { return }
            image = loadedImage
            loadedURL = url
        } catch is CancellationError {
            return
        } catch {
            guard self.url == url else { return }
            didFail = true
        }
    }
}

import SwiftUI

struct ProgressiveFadeImageView: View {
    let url: URL?

    var body: some View {
        GeometryReader { proxy in
            RemoteImageView(url: url)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .mask(imageFade)
        }
        .allowsHitTesting(false)
    }

    private var imageFade: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.58),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

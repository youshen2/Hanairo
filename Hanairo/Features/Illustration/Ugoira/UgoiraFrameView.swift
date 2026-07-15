import CoreGraphics
import SwiftUI

struct UgoiraFrameView: View {
    let image: CGImage?
    var contentMode: ContentMode = .fit

    var body: some View {
        GeometryReader { proxy in
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                Color.gray.opacity(0.28)
            }
        }
        .clipped()
    }
}

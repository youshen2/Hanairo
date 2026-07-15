import SwiftUI

struct LoadingArtworkGrid: View {
    var body: some View {
        ProgressView("正在加载作品…")
            .frame(maxWidth: .infinity, minHeight: 320)
    }
}

import SwiftUI

struct AuthenticationErrorView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    AuthenticationErrorView(message: "令牌无效，请重新检查。")
        .padding()
}

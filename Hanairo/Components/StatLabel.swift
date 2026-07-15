import SwiftUI

struct StatLabel: View {
    let value: Int
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value, format: .number.notation(.compactName))
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

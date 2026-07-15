import SwiftUI

struct ArtworkDownloadRecordRow: View {
    let record: ArtworkDownloadRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImageView(url: record.previewURL)
                .frame(width: 62, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(record.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(record.detailText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(record.isComplete ? .green : .orange)
                Text("\(record.artistName) · \(record.destination.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

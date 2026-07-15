import SwiftUI

struct ArtworkDownloadTaskRow: View {
    let task: ArtworkDownloadTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImageView(url: task.previewURL)
                .frame(width: 62, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(task.statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                ProgressView(value: task.progress)
                    .tint(.accentColor)
                HStack {
                    Text(task.progressText)
                    Spacer()
                    Text(task.destination.title)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch task.status {
        case .failed: .red
        case .paused: .orange
        case .queued, .downloading: .secondary
        }
    }
}

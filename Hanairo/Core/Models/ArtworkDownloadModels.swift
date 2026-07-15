import Foundation

struct ArtworkDownloadPage: Codable, Hashable, Sendable {
    let pageIndex: Int
    let url: URL
}

struct DownloadedArtworkPage: Codable, Hashable, Identifiable, Sendable {
    let pageIndex: Int
    let fileName: String?
    let byteCount: Int64

    var id: Int { pageIndex }
}

struct ArtworkDownloadTask: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let illustrationID: Int
    let title: String
    let artistName: String
    let previewURL: URL?
    let pages: [ArtworkDownloadPage]
    let totalArtworkPageCount: Int
    let destination: ArtworkDownloadDestination
    var status: ArtworkDownloadTaskStatus
    let createdAt: Date
    var startedAt: Date?
    var completedPageIndexes: Set<Int>
    var currentPageIndex: Int?
    var downloadedBytes: Int64
    var errorMessage: String?

    var progress: Double {
        guard !pages.isEmpty else { return 0 }
        return min(Double(completedPageIndexes.count) / Double(pages.count), 1)
    }

    var statusText: String {
        switch status {
        case .queued:
            "等待下载"
        case .downloading:
            if let currentPageIndex {
                "正在下载第 \(currentPageIndex + 1) 页"
            } else {
                "正在准备"
            }
        case .paused:
            "已暂停"
        case .failed:
            errorMessage ?? "下载失败"
        }
    }

    var progressText: String {
        "\(completedPageIndexes.count)/\(pages.count) 页"
    }
}

enum ArtworkDownloadTaskStatus: String, Codable, Hashable, Sendable {
    case queued
    case downloading
    case paused
    case failed

    var canRun: Bool { self == .queued }
}

struct ArtworkDownloadRecord: Codable, Identifiable, Hashable, Sendable {
    let illustrationID: Int
    let title: String
    let artistName: String
    let previewURL: URL?
    let destination: ArtworkDownloadDestination
    var pages: [DownloadedArtworkPage]
    let totalArtworkPageCount: Int
    var totalBytes: Int64
    var updatedAt: Date

    var id: String {
        "\(illustrationID)-\(destination.rawValue)"
    }

    var detailText: String {
        let size = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let progress = "\(pages.count)/\(totalArtworkPageCount) 页"
        return totalBytes > 0 ? "\(progress) · \(size)" : progress
    }

    var isComplete: Bool {
        pages.count >= totalArtworkPageCount
    }
}

enum ArtworkDownloadEnqueueResult: Equatable {
    case queued(Int)
    case alreadyQueued
    case alreadyDownloaded
    case noAvailablePages

    var message: String {
        switch self {
        case let .queued(count): "已加入下载队列：\(count) 页"
        case .alreadyQueued: "该作品已在下载队列中"
        case .alreadyDownloaded: "所选图片已经下载"
        case .noAvailablePages: "没有可用的下载地址"
        }
    }
}

struct ArtworkDownloadStorageUsage: Sendable {
    let filesBytes: Int64
    let metadataBytes: Int64

    var totalBytes: Int64 { filesBytes + metadataBytes }
}

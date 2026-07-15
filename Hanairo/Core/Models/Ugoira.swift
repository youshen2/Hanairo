import Foundation

nonisolated struct UgoiraMetadataResponse: Decodable, Sendable {
    let metadata: UgoiraMetadata

    enum CodingKeys: String, CodingKey {
        case metadata = "ugoira_metadata"
    }
}

nonisolated struct UgoiraMetadata: Decodable, Sendable {
    let zipURLs: UgoiraZipURLs
    let frames: [UgoiraMetadataFrame]

    enum CodingKeys: String, CodingKey {
        case zipURLs = "zip_urls"
        case frames
    }
}

nonisolated struct UgoiraZipURLs: Decodable, Sendable {
    let medium: URL?
}

nonisolated struct UgoiraMetadataFrame: Decodable, Sendable {
    let file: String
    let delay: Int
}

nonisolated struct UgoiraAnimation: Sendable {
    let illustrationID: Int
    let archiveURL: URL
    let frames: [UgoiraAnimationFrame]

    var totalDuration: TimeInterval {
        frames.reduce(0) { $0 + $1.duration }
    }

    var byteCount: Int {
        frames.reduce(0) { $0 + $1.data.count }
    }
}

nonisolated struct UgoiraAnimationFrame: Sendable {
    let filename: String
    let delayMilliseconds: Int
    let data: Data

    var duration: TimeInterval {
        max(TimeInterval(delayMilliseconds) / 1_000, 0.01)
    }
}

enum UgoiraLoadingStage: Equatable {
    case metadata
    case downloading
    case extracting
    case decodingFirstFrame

    var title: String {
        switch self {
        case .metadata: "正在获取动图信息…"
        case .downloading: "正在下载动图…"
        case .extracting: "正在解压动图…"
        case .decodingFirstFrame: "正在准备播放…"
        }
    }
}

nonisolated enum UgoiraError: LocalizedError, Sendable {
    case missingArchiveURL
    case emptyFrames
    case invalidArchive
    case encryptedArchive
    case unsupportedCompression(Int)
    case missingFrame(String)
    case invalidFrame(String)
    case archiveTooLarge

    var errorDescription: String? {
        switch self {
        case .missingArchiveURL:
            "Pixiv 没有返回可用的动图文件"
        case .emptyFrames:
            "动图不包含任何帧"
        case .invalidArchive:
            "动图压缩包已损坏"
        case .encryptedArchive:
            "暂不支持加密的动图压缩包"
        case let .unsupportedCompression(method):
            "动图使用了不支持的压缩方式（\(method)）"
        case let .missingFrame(filename):
            "动图缺少帧：\(filename)"
        case let .invalidFrame(filename):
            "动图帧无法读取：\(filename)"
        case .archiveTooLarge:
            "动图文件过大，无法安全加载"
        }
    }
}

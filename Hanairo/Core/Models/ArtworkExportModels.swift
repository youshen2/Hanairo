import Foundation
import UniformTypeIdentifiers

enum ArtworkExportFormat: String, Sendable {
    case zip
    case pdf

    var contentType: UTType {
        switch self {
        case .zip: .zip
        case .pdf: .pdf
        }
    }

    var fileExtension: String { rawValue }
}

struct PreparedArtworkExport: Sendable {
    let fileURL: URL
    let format: ArtworkExportFormat
    let document: ArtworkExportDocument
}

nonisolated enum ArtworkExportError: LocalizedError, Sendable {
    case noAvailablePages
    case missingPage(Int)
    case cannotCreateOutput
    case invalidImage(Int)
    case invalidFilename
    case archiveTooLarge
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .noAvailablePages:
            "没有可导出的图片"
        case let .missingPage(index):
            "第 \(index + 1) 页没有可用的原图地址"
        case .cannotCreateOutput:
            "无法创建导出文件"
        case let .invalidImage(index):
            "第 \(index + 1) 页不是有效图片"
        case .invalidFilename:
            "无法生成有效的压缩包文件名"
        case .archiveTooLarge:
            "作品过大，超出了 ZIP 格式支持的容量"
        case .compressionFailed:
            "压缩图片时发生错误"
        }
    }
}

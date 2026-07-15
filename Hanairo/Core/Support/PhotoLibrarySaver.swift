import Foundation

#if os(iOS) || os(macOS)
import Photos
#endif

enum PhotoLibrarySaver {
    static func save(_ data: Data) async throws {
#if os(iOS) || os(macOS)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
#else
        throw PhotoLibrarySaveError.unsupportedPlatform
#endif
    }
}

private enum PhotoLibrarySaveError: LocalizedError {
    case permissionDenied
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有相册写入权限，请前往系统设置允许 Hanairo 添加照片。"
        case .unsupportedPlatform:
            "当前平台不支持保存到相册。"
        }
    }
}

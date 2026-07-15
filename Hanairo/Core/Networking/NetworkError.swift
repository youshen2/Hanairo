import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationRequired
    case server(statusCode: Int, message: String)
    case decoding(String)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "请求地址无效"
        case .invalidResponse:
            "服务器返回了无法识别的响应"
        case .authenticationRequired:
            "请先登录 Pixiv 账户"
        case let .server(statusCode, message):
            message.isEmpty ? "请求失败（\(statusCode)）" : message
        case let .decoding(message):
            "数据解析失败：\(message)"
        case .invalidImage:
            "图片数据无法读取"
        }
    }
}

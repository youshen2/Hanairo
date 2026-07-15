import CryptoKit
import Foundation

enum APIConfiguration {
    static let apiBaseURL = URL(string: "https://app-api.pixiv.net")!
    static let oauthBaseURL = URL(string: "https://oauth.secure.pixiv.net")!
    static let oauthRedirectURI = "https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback"
    static let oauthCallbackScheme = "pixiv"
    static let clientID = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
    static let clientSecret = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
    static let hashSalt = "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"
    static let userAgent = "PixivAndroidApp/5.0.166 (Android 10.0; Pixel C)"

    static func standardHeaders(accessToken: String? = nil) -> [String: String] {
        let time = clientTime()
        var headers = [
            "X-Client-Time": time,
            "X-Client-Hash": md5(time + hashSalt),
            "User-Agent": userAgent,
            "Accept-Language": "zh-CN",
            "App-OS": "Android",
            "App-OS-Version": "Android 10.0",
            "App-Version": "5.0.166"
        ]
        if let accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        return headers
    }

    static func formBody(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private static func clientTime() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter.string(from: Date()).replacingOccurrences(of: "Z", with: "+00:00")
    }

    private static func md5(_ value: String) -> String {
        Insecure.MD5.hash(data: Data(value.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }
}

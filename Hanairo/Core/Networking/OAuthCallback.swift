import Foundation

enum OAuthCallback {
    static func authorizationCode(from url: URL) throws -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        if let message = value(named: "error_description", in: queryItems)
            ?? value(named: "error", in: queryItems)
        {
            throw OAuthCallbackError.authorizationDenied(message)
        }

        guard
            url.scheme?.lowercased() == APIConfiguration.oauthCallbackScheme,
            url.host?.lowercased() == "account",
            let code = value(named: "code", in: queryItems),
            !code.isEmpty
        else {
            throw OAuthCallbackError.invalidCallback
        }
        return code
    }

    private static func value(named name: String, in queryItems: [URLQueryItem]) -> String? {
        queryItems.first(where: { $0.name == name })?.value
    }
}

private enum OAuthCallbackError: LocalizedError {
    case authorizationDenied(String)
    case invalidCallback

    var errorDescription: String? {
        switch self {
        case let .authorizationDenied(message):
            "Pixiv 未完成授权：\(message)"
        case .invalidCallback:
            "Pixiv 返回的登录结果无效"
        }
    }
}

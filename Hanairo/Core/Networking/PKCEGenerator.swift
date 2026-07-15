import CryptoKit
import Foundation

enum PKCEGenerator {
    static func makePreparation(
        for flow: PixivAuthorizationFlow,
        baseURL: URL
    ) -> AuthorizationPreparation {
        let verifier = randomURLSafeString(length: 64)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        var components = URLComponents(
            url: baseURL.appending(path: authorizationPath(for: flow)),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "client", value: "pixiv-android")
        ]
        return AuthorizationPreparation(url: components.url!, verifier: verifier)
    }

    private static func authorizationPath(for flow: PixivAuthorizationFlow) -> String {
        switch flow {
        case .login:
            "/web/v1/login"
        case .accountCreation:
            "/web/v1/provisional-accounts/create"
        }
    }

    private static func randomURLSafeString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters.randomElement(using: &generator)! })
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

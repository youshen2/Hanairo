import Foundation

final class AuthenticationAPI {
    private let client: NetworkClient
    private let networkSettings: NetworkSettings
    private let decoder = JSONDecoder()

    init(client: NetworkClient, networkSettings: NetworkSettings) {
        self.client = client
        self.networkSettings = networkSettings
    }

    func exchange(refreshToken: String) async throws -> AuthTokenResponse {
        try await tokenRequest([
            "client_id": APIConfiguration.clientID,
            "client_secret": APIConfiguration.clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "include_policy": "true"
        ])
    }

    func exchange(code: String, verifier: String) async throws -> AuthTokenResponse {
        try await tokenRequest([
            "client_id": APIConfiguration.clientID,
            "client_secret": APIConfiguration.clientSecret,
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": APIConfiguration.oauthRedirectURI,
            "include_policy": "true"
        ])
    }

    func prepareAuthorization(for flow: PixivAuthorizationFlow) -> AuthorizationPreparation {
        PKCEGenerator.makePreparation(for: flow, baseURL: networkSettings.apiBaseURL)
    }

    private func tokenRequest(_ values: [String: String]) async throws -> AuthTokenResponse {
        var request = URLRequest(url: networkSettings.oauthBaseURL.appending(path: "/auth/token"))
        request.httpMethod = "POST"
        request.httpBody = APIConfiguration.formBody(values)
        APIConfiguration.standardHeaders().forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let data = try await client.data(for: request)
        if let envelope = try? decoder.decode(AuthTokenEnvelope.self, from: data) {
            return envelope.response
        }
        do {
            return try decoder.decode(AuthTokenResponse.self, from: data)
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
    }
}

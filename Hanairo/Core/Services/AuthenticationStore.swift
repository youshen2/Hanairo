import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationStore {
    private(set) var account: AuthenticatedUser?
    private(set) var isRestoring = true
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?

    private let api: AuthenticationAPI
    private let credentialStore: CredentialStore
    private let defaults: UserDefaults
    private var credentials: StoredCredentials?

    private static let accountKey = "authenticatedPixivUser"

    init(defaults: UserDefaults = .standard) {
        let networkSettings = NetworkSettings(defaults: defaults)
        let sessionProvider = NetworkSessionProvider(settings: networkSettings)
        api = AuthenticationAPI(
            client: NetworkClient(sessionProvider: sessionProvider),
            networkSettings: networkSettings
        )
        credentialStore = CredentialStore()
        self.defaults = defaults
    }

    init(
        api: AuthenticationAPI,
        credentialStore: CredentialStore,
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.credentialStore = credentialStore
        self.defaults = defaults
    }

    var isAuthenticated: Bool {
        account != nil && credentials != nil
    }

    var userID: Int? {
        account?.numericID
    }

    func restore() async {
        guard isRestoring else { return }
        defer { isRestoring = false }
        credentials = credentialStore.load()
        account = loadAccount()
        guard let credentials else {
            account = nil
            defaults.removeObject(forKey: Self.accountKey)
            return
        }
        if !credentials.needsRefresh, account != nil {
            return
        }
        do {
            let response = try await api.exchange(refreshToken: credentials.refreshToken)
            try apply(response)
        } catch {
            self.credentials = nil
            account = nil
            errorMessage = "无法恢复登录，请重新登录：\(error.localizedDescription)"
        }
    }

    func prepareAuthorization(for flow: PixivAuthorizationFlow) -> AuthorizationPreparation {
        api.prepareAuthorization(for: flow)
    }

    func signIn(refreshToken: String) async throws {
        try await authenticate {
            try await api.exchange(refreshToken: refreshToken.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func signIn(code: String, verifier: String) async throws {
        try await authenticate {
            try await api.exchange(
                code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                verifier: verifier
            )
        }
    }

    func validAccessToken() async throws -> String {
        guard let credentials else {
            throw NetworkError.authenticationRequired
        }
        guard credentials.needsRefresh else {
            return credentials.accessToken
        }
        let response = try await api.exchange(refreshToken: credentials.refreshToken)
        try apply(response)
        return response.accessToken
    }

    func refreshAccessToken() async throws -> String {
        guard let credentials else {
            throw NetworkError.authenticationRequired
        }
        let response = try await api.exchange(refreshToken: credentials.refreshToken)
        try apply(response)
        return response.accessToken
    }

    func signOut() {
        credentials = nil
        account = nil
        errorMessage = nil
        credentialStore.delete()
        defaults.removeObject(forKey: Self.accountKey)
    }

    func clearError() {
        errorMessage = nil
    }

    private func authenticate(operation: () async throws -> AuthTokenResponse) async throws {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        do {
            let response = try await operation()
            try apply(response)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func apply(_ response: AuthTokenResponse) throws {
        let stored = StoredCredentials(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expirationDate: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
        try credentialStore.save(stored)
        credentials = stored
        account = response.user
        defaults.set(try JSONEncoder().encode(response.user), forKey: Self.accountKey)
    }

    private func loadAccount() -> AuthenticatedUser? {
        guard let data = defaults.data(forKey: Self.accountKey) else { return nil }
        return try? JSONDecoder().decode(AuthenticatedUser.self, from: data)
    }
}

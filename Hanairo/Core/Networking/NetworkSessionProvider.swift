import Foundation

@MainActor
final class NetworkSessionProvider {
    private let settings: NetworkSettings
    private var session: URLSession?
    private var signature: NetworkConfigurationSignature?

    init(settings: NetworkSettings) {
        self.settings = settings
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await currentSession().data(for: request)
    }

    func reset() {
        session?.invalidateAndCancel()
        session = nil
        signature = nil
    }

    private func currentSession() -> URLSession {
        let currentSignature = settings.signature
        if let session, signature == currentSignature {
            return session
        }
        session?.invalidateAndCancel()
        let newSession = URLSession(configuration: settings.makeSessionConfiguration())
        session = newSession
        signature = currentSignature
        return newSession
    }
}

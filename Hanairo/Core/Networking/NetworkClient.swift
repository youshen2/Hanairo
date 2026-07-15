import Foundation

struct NetworkClient {
    private let sessionProvider: NetworkSessionProvider

    init(sessionProvider: NetworkSessionProvider) {
        self.sessionProvider = sessionProvider
    }

    func data(for request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sessionProvider.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard 200..<300 ~= response.statusCode else {
            throw NetworkError.server(
                statusCode: response.statusCode,
                message: Self.errorMessage(from: data)
            )
        }
        return data
    }

    private static func errorMessage(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any]
        else {
            return ""
        }
        if let message = error["message"] as? String {
            return message
        }
        if
            let userMessage = error["user_message"] as? String,
            !userMessage.isEmpty
        {
            return userMessage
        }
        return ""
    }
}

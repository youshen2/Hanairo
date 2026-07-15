import Foundation
import ImageIO

enum NetworkDiagnosticState: Equatable {
    case idle
    case testing
    case succeeded(milliseconds: Int)
    case failed(String)

    var title: String {
        switch self {
        case .idle: "尚未测试"
        case .testing: "正在测试"
        case let .succeeded(milliseconds): "成功 · \(milliseconds) ms"
        case let .failed(message): message
        }
    }

    var systemImage: String {
        switch self {
        case .idle: "minus.circle"
        case .testing: "arrow.triangle.2.circlepath"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
struct NetworkDiagnosticsService {
    let settings: NetworkSettings

    func testAPI() async -> NetworkDiagnosticState {
        let url = settings.apiBaseURL.appending(path: "/v1/walkthrough/illusts")
        var request = URLRequest(url: url)
        APIConfiguration.standardHeaders().forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        return await perform(request: request) { _, response in
            guard 200..<300 ~= response.statusCode else {
                throw NetworkError.server(statusCode: response.statusCode, message: "")
            }
        }
    }

    func testImage() async -> NetworkDiagnosticState {
        let originalURL = URL(
            string: "https://i.pximg.net/c/360x360_70/img-master/img/2016/04/29/03/33/27/56585648_p0_square1200.jpg"
        )!
        var request = URLRequest(url: settings.resolvedImageURL(originalURL))
        request.setValue("https://www.pixiv.net/", forHTTPHeaderField: "Referer")
        request.setValue(APIConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        return await perform(request: request) { data, response in
            guard
                200..<300 ~= response.statusCode,
                CGImageSourceCreateWithData(data as CFData, nil) != nil
            else {
                throw NetworkError.invalidImage
            }
        }
    }

    private func perform(
        request: URLRequest,
        validation: (Data, HTTPURLResponse) throws -> Void
    ) async -> NetworkDiagnosticState {
        let session = URLSession(configuration: settings.makeSessionConfiguration())
        let start = ContinuousClock.now
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            try validation(data, response)
            let duration = start.duration(to: .now)
            let milliseconds = Int(duration.components.seconds * 1_000)
                + Int(duration.components.attoseconds / 1_000_000_000_000_000)
            return .succeeded(milliseconds: max(milliseconds, 0))
        } catch is CancellationError {
            return .idle
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

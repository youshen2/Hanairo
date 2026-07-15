import CFNetwork
import Foundation
import Observation

enum AppNetworkMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case direct
    case httpProxy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .direct: "直连"
        case .httpProxy: "HTTP 代理"
        }
    }

    var description: String {
        switch self {
        case .system: "使用系统网络、DNS、VPN 与代理设置"
        case .direct: "忽略系统 HTTP 代理，仍使用系统 DNS"
        case .httpProxy: "为 Hanairo 的 API 与图片请求指定代理"
        }
    }
}

@MainActor
@Observable
final class NetworkSettings {
    static let defaultAPIBaseURL = "https://app-api.pixiv.net"
    static let defaultOAuthBaseURL = "https://oauth.secure.pixiv.net"
    static let timeoutRange = 10...120
    static let proxyPortRange = 1...65_535

    var mode: AppNetworkMode {
        didSet { defaults.set(mode.rawValue, forKey: Keys.mode) }
    }
    var allowsCellularAccess: Bool {
        didSet { defaults.set(allowsCellularAccess, forKey: Keys.allowsCellularAccess) }
    }
    var requestTimeout: Int {
        didSet { defaults.set(requestTimeout, forKey: Keys.requestTimeout) }
    }
    var proxyHost: String {
        didSet { defaults.set(proxyHost, forKey: Keys.proxyHost) }
    }
    var proxyPort: Int {
        didSet { defaults.set(proxyPort, forKey: Keys.proxyPort) }
    }
    var apiBaseURLString: String {
        didSet { defaults.set(apiBaseURLString, forKey: Keys.apiBaseURL) }
    }
    var oauthBaseURLString: String {
        didSet { defaults.set(oauthBaseURLString, forKey: Keys.oauthBaseURL) }
    }
    var imageHostOverride: String {
        didSet { defaults.set(imageHostOverride, forKey: Keys.imageHostOverride) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = AppNetworkMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .system
        allowsCellularAccess = defaults.object(forKey: Keys.allowsCellularAccess) as? Bool ?? true
        requestTimeout = min(
            max(defaults.integer(forKey: Keys.requestTimeout), Self.timeoutRange.lowerBound),
            Self.timeoutRange.upperBound
        )
        if defaults.object(forKey: Keys.requestTimeout) == nil {
            requestTimeout = 30
        }
        proxyHost = defaults.string(forKey: Keys.proxyHost) ?? "127.0.0.1"
        let storedProxyPort = defaults.integer(forKey: Keys.proxyPort)
        proxyPort = Self.proxyPortRange.contains(storedProxyPort) ? storedProxyPort : 7890
        apiBaseURLString = defaults.string(forKey: Keys.apiBaseURL) ?? Self.defaultAPIBaseURL
        oauthBaseURLString = defaults.string(forKey: Keys.oauthBaseURL) ?? Self.defaultOAuthBaseURL
        imageHostOverride = defaults.string(forKey: Keys.imageHostOverride) ?? ""
    }

    var apiBaseURL: URL {
        Self.httpsURL(from: apiBaseURLString) ?? URL(string: Self.defaultAPIBaseURL)!
    }

    var oauthBaseURL: URL {
        Self.httpsURL(from: oauthBaseURLString) ?? URL(string: Self.defaultOAuthBaseURL)!
    }

    var hasValidAPIBaseURL: Bool { Self.httpsURL(from: apiBaseURLString) != nil }
    var hasValidOAuthBaseURL: Bool { Self.httpsURL(from: oauthBaseURLString) != nil }
    var hasValidProxy: Bool {
        mode != .httpProxy
            || (!normalizedProxyHost.isEmpty && Self.proxyPortRange.contains(proxyPort))
    }
    var hasValidImageHost: Bool {
        normalizedImageHost.isEmpty || Self.isValidHost(normalizedImageHost)
    }

    var signature: NetworkConfigurationSignature {
        NetworkConfigurationSignature(
            mode: mode,
            allowsCellularAccess: allowsCellularAccess,
            requestTimeout: requestTimeout,
            proxyHost: normalizedProxyHost,
            proxyPort: proxyPort
        )
    }

    func resolvedImageURL(_ url: URL) -> URL {
        guard
            ["i.pximg.net", "s.pximg.net"].contains(url.host?.lowercased() ?? ""),
            hasValidImageHost,
            !normalizedImageHost.isEmpty,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return url
        }
        components.host = normalizedImageHost
        return components.url ?? url
    }

    func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = allowsCellularAccess
        configuration.timeoutIntervalForRequest = TimeInterval(requestTimeout)
        configuration.timeoutIntervalForResource = TimeInterval(max(requestTimeout * 4, 60))

        switch mode {
        case .system:
            break
        case .direct:
            configuration.connectionProxyDictionary = [:]
        case .httpProxy where hasValidProxy:
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: normalizedProxyHost,
                kCFNetworkProxiesHTTPPort as String: proxyPort,
                "HTTPSEnable": true,
                "HTTPSProxy": normalizedProxyHost,
                "HTTPSPort": proxyPort
            ]
        case .httpProxy:
            configuration.connectionProxyDictionary = [:]
        }
        return configuration
    }

    func reset() {
        mode = .system
        allowsCellularAccess = true
        requestTimeout = 30
        proxyHost = "127.0.0.1"
        proxyPort = 7890
        apiBaseURLString = Self.defaultAPIBaseURL
        oauthBaseURLString = Self.defaultOAuthBaseURL
        imageHostOverride = ""
    }

    private var normalizedProxyHost: String {
        proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedImageHost: String {
        var value = imageHostOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if let components = URLComponents(string: value), let host = components.host {
            value = host
        }
        return value.lowercased()
    }

    private static func httpsURL(from value: String) -> URL? {
        guard
            let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme?.lowercased() == "https",
            url.host != nil
        else {
            return nil
        }
        return url
    }

    private static func isValidHost(_ value: String) -> Bool {
        guard !value.isEmpty, !value.contains(" ") else { return false }
        return URL(string: "https://\(value)")?.host == value
    }

    private enum Keys {
        static let mode = "network.mode"
        static let allowsCellularAccess = "network.allowsCellularAccess"
        static let requestTimeout = "network.requestTimeout"
        static let proxyHost = "network.proxyHost"
        static let proxyPort = "network.proxyPort"
        static let apiBaseURL = "network.apiBaseURL"
        static let oauthBaseURL = "network.oauthBaseURL"
        static let imageHostOverride = "network.imageHostOverride"
    }
}

struct NetworkConfigurationSignature: Hashable, Sendable {
    let mode: AppNetworkMode
    let allowsCellularAccess: Bool
    let requestTimeout: Int
    let proxyHost: String
    let proxyPort: Int
}

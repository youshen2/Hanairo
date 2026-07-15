import Foundation

enum DeepLinkParser {
    static func route(for url: URL) -> AppRoute? {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased() ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let segments = url.pathComponents.filter { $0 != "/" }

        if let query = queryValue(named: "query", in: components),
           scheme == "hanairo",
           host == "search" {
            return .search(query: query)
        }

        if ["hanairo", "pixiv", "pixez"].contains(scheme) {
            return routeForCustomURL(host: host, segments: segments, components: components)
        }

        guard ["http", "https"].contains(scheme) else { return nil }

        if host == "i.pximg.net" || host == "s.pximg.net" {
            return artworkRouteFromImageURL(url)
        }

        if host == "pixiv.me", let id = segments.compactMap(positiveID).first {
            return .user(id: id)
        }

        guard host == "pixiv.net" || host.hasSuffix(".pixiv.net") else { return nil }

        if let value = queryValue(named: "illust_id", in: components), let id = positiveID(value) {
            return .illustration(id: id)
        }
        return routeForPixivSegments(segments, queryID: queryValue(named: "id", in: components))
    }

    private static func routeForCustomURL(
        host: String,
        segments: [String],
        components: URLComponents?
    ) -> AppRoute? {
        let values = host.isEmpty ? segments : [host] + segments
        guard let kind = values.first?.lowercased() else { return nil }

        if kind == "search", let query = queryValue(named: "query", in: components) {
            return .search(query: query)
        }
        if let seriesRoute = routeForSeries(in: values) {
            return seriesRoute
        }

        if ["artwork", "artworks", "illust", "illusts", "i"].contains(kind),
           let id = firstPositiveID(in: Array(values.dropFirst()), components: components) {
            return .illustration(id: id)
        }
        if ["user", "users", "u"].contains(kind),
           let id = firstPositiveID(in: Array(values.dropFirst()), components: components) {
            return .user(id: id)
        }
        if ["series", "illust-series", "illustration-series"].contains(kind),
           let id = firstPositiveID(in: Array(values.dropFirst()), components: components) {
            return .illustrationSeries(id: id)
        }
        return routeForPixivSegments(values, queryID: queryValue(named: "id", in: components))
    }

    private static func routeForPixivSegments(_ segments: [String], queryID: String?) -> AppRoute? {
        let values = segments.map { $0.lowercased() }

        if let seriesIndex = values.firstIndex(of: "series"),
           let id = value(after: seriesIndex, in: segments) {
            return .illustrationSeries(id: id)
        }
        if let index = values.firstIndex(where: { ["artwork", "artworks", "illust", "illusts", "i"].contains($0) }),
           let id = value(after: index, in: segments) {
            return .illustration(id: id)
        }
        if let index = values.firstIndex(where: { ["user", "users", "u"].contains($0) }),
           let id = value(after: index, in: segments) {
            return .user(id: id)
        }
        if let queryID, let id = positiveID(queryID) {
            if values.last == "member.php" {
                return .user(id: id)
            }
            return .illustration(id: id)
        }
        return nil
    }

    private static func routeForSeries(in segments: [String]) -> AppRoute? {
        let values = segments.map { $0.lowercased() }
        guard
            let seriesIndex = values.firstIndex(of: "series"),
            let id = value(after: seriesIndex, in: segments)
        else {
            return nil
        }
        return .illustrationSeries(id: id)
    }

    private static func artworkRouteFromImageURL(_ url: URL) -> AppRoute? {
        let fileName = url.deletingPathExtension().lastPathComponent
        guard let value = fileName.split(separator: "_").first, let id = positiveID(String(value)) else {
            return nil
        }
        return .illustration(id: id)
    }

    private static func firstPositiveID(
        in segments: [String],
        components: URLComponents?
    ) -> Int? {
        segments.compactMap(positiveID).first
            ?? queryValue(named: "id", in: components).flatMap(positiveID)
            ?? queryValue(named: "illust_id", in: components).flatMap(positiveID)
    }

    private static func value(after index: Int, in segments: [String]) -> Int? {
        guard segments.indices.contains(index + 1) else { return nil }
        return positiveID(segments[index + 1])
    }

    private static func queryValue(named name: String, in components: URLComponents?) -> String? {
        components?.queryItems?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    nonisolated private static func positiveID(_ value: String) -> Int? {
        guard let id = Int(value), id > 0 else { return nil }
        return id
    }
}

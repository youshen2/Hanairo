import Foundation
import ImageIO
import Observation

@MainActor
@Observable
final class ImageRepository {
    private var cache: [URL: CGImage] = [:]
    private var insertionOrder: [URL] = []
    private let sessionProvider: NetworkSessionProvider
    private let networkSettings: NetworkSettings
    private let diskCache: DiskCacheStore
    private let settings: AppSettings
    private let capacity = 48

    init(
        settings: AppSettings,
        networkSettings: NetworkSettings,
        sessionProvider: NetworkSessionProvider
    ) {
        self.settings = settings
        self.networkSettings = networkSettings
        self.sessionProvider = sessionProvider
        diskCache = DiskCacheStore(
            directoryName: "ImageCache",
            capacityBytes: settings.imageCacheCapacityBytes
        )
    }

    func image(for url: URL) async throws -> CGImage {
        if let cached = cache[url] {
            return cached
        }
        let data = try await data(for: url)
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw NetworkError.invalidImage
        }
        if cache.count >= capacity, let oldest = insertionOrder.first {
            cache[oldest] = nil
            insertionOrder.removeFirst()
        }
        cache[url] = image
        insertionOrder.append(url)
        return image
    }

    func data(for url: URL, bypassingCache: Bool = false) async throws -> Data {
        if !bypassingCache, let cachedData = await diskCache.data(forKey: url.absoluteString) {
            if Self.isValidImageData(cachedData) {
                return cachedData
            }
            await diskCache.removeValue(forKey: url.absoluteString)
        }

        var request = URLRequest(url: networkSettings.resolvedImageURL(url))
        request.setValue("https://www.pixiv.net/", forHTTPHeaderField: "Referer")
        request.setValue(APIConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sessionProvider.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
        guard
            let response = response as? HTTPURLResponse,
            200..<300 ~= response.statusCode,
            !data.isEmpty
        else {
            throw NetworkError.invalidImage
        }
        guard Self.isValidImageData(data) else {
            throw NetworkError.invalidImage
        }
        await diskCache.store(data, forKey: url.absoluteString)
        return data
    }

    func clear() async {
        cache.removeAll(keepingCapacity: false)
        insertionOrder.removeAll(keepingCapacity: false)
        await diskCache.clear()
    }

    func cacheUsage() async -> CacheUsage {
        await diskCache.usage()
    }

    func updateCacheCapacity() async {
        await diskCache.updateCapacityBytes(settings.imageCacheCapacityBytes)
    }

    private static func isValidImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }
}

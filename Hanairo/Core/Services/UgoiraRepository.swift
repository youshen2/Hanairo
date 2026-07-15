import Foundation
import Observation

@MainActor
@Observable
final class UgoiraRepository {
    @ObservationIgnored private let pixivRepository: PixivRepository
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let networkSettings: NetworkSettings
    @ObservationIgnored private let sessionProvider: NetworkSessionProvider
    @ObservationIgnored private let diskCache: DiskCacheStore
    @ObservationIgnored private let memoryCache = NSCache<NSNumber, UgoiraAnimationBox>()

    init(
        pixivRepository: PixivRepository,
        settings: AppSettings,
        networkSettings: NetworkSettings,
        sessionProvider: NetworkSessionProvider
    ) {
        self.pixivRepository = pixivRepository
        self.settings = settings
        self.networkSettings = networkSettings
        self.sessionProvider = sessionProvider
        diskCache = DiskCacheStore(
            directoryName: "UgoiraCache",
            capacityBytes: settings.ugoiraCacheCapacityBytes
        )
        configureMemoryCache()
    }

    func animation(
        for illustrationID: Int,
        progress: (UgoiraLoadingStage) -> Void
    ) async throws -> UgoiraAnimation {
        if let cached = memoryCache.object(forKey: NSNumber(value: illustrationID))?.animation {
            return cached
        }

        progress(.metadata)
        let metadata = try await pixivRepository.ugoiraMetadata(id: illustrationID)
        guard let archiveURL = metadata.zipURLs.medium else {
            throw UgoiraError.missingArchiveURL
        }

        let cacheKey = archiveURL.absoluteString
        if let cachedArchive = await diskCache.data(forKey: cacheKey) {
            progress(.extracting)
            do {
                let animation = try await decode(
                    cachedArchive,
                    metadata: metadata,
                    illustrationID: illustrationID,
                    archiveURL: archiveURL
                )
                storeInMemory(animation)
                return animation
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await diskCache.removeValue(forKey: cacheKey)
            }
        }

        progress(.downloading)
        let archiveData = try await downloadArchive(from: archiveURL)
        progress(.extracting)
        let animation = try await decode(
            archiveData,
            metadata: metadata,
            illustrationID: illustrationID,
            archiveURL: archiveURL
        )
        await diskCache.store(archiveData, forKey: cacheKey)
        storeInMemory(animation)
        return animation
    }

    func clear() async {
        memoryCache.removeAllObjects()
        await diskCache.clear()
    }

    func cacheUsage() async -> CacheUsage {
        await diskCache.usage()
    }

    func updateCacheCapacity() async {
        configureMemoryCache()
        await diskCache.updateCapacityBytes(settings.ugoiraCacheCapacityBytes)
    }

    private func downloadArchive(from url: URL) async throws -> Data {
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
            throw NetworkError.invalidResponse
        }
        guard
            response.expectedContentLength <= 0
                || response.expectedContentLength <= Int64(Self.maximumArchiveBytes),
            data.count <= Self.maximumArchiveBytes
        else {
            throw UgoiraError.archiveTooLarge
        }
        return data
    }

    private func decode(
        _ archiveData: Data,
        metadata: UgoiraMetadata,
        illustrationID: Int,
        archiveURL: URL
    ) async throws -> UgoiraAnimation {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try UgoiraZIPDecoder.decode(
                archiveData: archiveData,
                metadata: metadata,
                illustrationID: illustrationID,
                archiveURL: archiveURL
            )
        }.value
    }

    private func storeInMemory(_ animation: UgoiraAnimation) {
        memoryCache.setObject(
            UgoiraAnimationBox(animation),
            forKey: NSNumber(value: animation.illustrationID),
            cost: animation.byteCount
        )
    }

    private func configureMemoryCache() {
        memoryCache.countLimit = 2
        memoryCache.totalCostLimit = min(
            Int(settings.ugoiraCacheCapacityBytes),
            256 * 1_024 * 1_024
        )
    }

    private static let maximumArchiveBytes = 1_024 * 1_024 * 1_024
}

private final class UgoiraAnimationBox {
    let animation: UgoiraAnimation

    init(_ animation: UgoiraAnimation) {
        self.animation = animation
    }
}

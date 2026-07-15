import Foundation

actor ArtworkDetailCache {
    private let diskStore: DiskCacheStore
    private let formatVersion = 1

    init(capacityBytes: Int64) {
        diskStore = DiskCacheStore(
            directoryName: "ArtworkDetailCache",
            capacityBytes: capacityBytes
        )
    }

    func illustration(id: Int, userID: Int?) async -> PixivIllustration? {
        let key = cacheKey(id: id, userID: userID)
        guard
            let data = await diskStore.data(forKey: key),
            let payload = try? JSONDecoder().decode(CachedArtworkDetail.self, from: data),
            payload.version == formatVersion
        else {
            await diskStore.removeValue(forKey: key)
            return nil
        }
        return payload.illustration
    }

    func store(_ illustration: PixivIllustration, userID: Int?) async {
        let payload = CachedArtworkDetail(
            version: formatVersion,
            cachedAt: Date(),
            illustration: illustration
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        await diskStore.store(data, forKey: cacheKey(id: illustration.id, userID: userID))
    }

    func clear() async {
        await diskStore.clear()
    }

    func usage() async -> CacheUsage {
        await diskStore.usage()
    }

    func updateCapacityBytes(_ capacityBytes: Int64) async {
        await diskStore.updateCapacityBytes(capacityBytes)
    }

    private func cacheKey(id: Int, userID: Int?) -> String {
        "\(userID ?? 0)|\(id)"
    }
}

private nonisolated struct CachedArtworkDetail: Codable, Sendable {
    let version: Int
    let cachedAt: Date
    let illustration: PixivIllustration
}

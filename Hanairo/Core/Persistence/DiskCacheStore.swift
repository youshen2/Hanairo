import CryptoKit
import Foundation

actor DiskCacheStore {
    private let directoryURL: URL
    private var capacityBytes: Int64
    private let fileManager = FileManager.default

    init(directoryName: String, capacityBytes: Int64) {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directoryURL = baseURL.appendingPathComponent(directoryName, isDirectory: true)
        self.capacityBytes = max(capacityBytes, 1)
    }

    func data(forKey key: String) -> Data? {
        prepareDirectory()
        let url = fileURL(forKey: key)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        touch(url)
        return data
    }

    func store(_ data: Data, forKey key: String) {
        guard !data.isEmpty else { return }
        prepareDirectory()
        let url = fileURL(forKey: key)
        try? data.write(to: url, options: .atomic)
        touch(url)
        trimIfNeeded()
    }

    func removeValue(forKey key: String) {
        try? fileManager.removeItem(at: fileURL(forKey: key))
    }

    func clear() {
        try? fileManager.removeItem(at: directoryURL)
        prepareDirectory()
    }

    func updateCapacityBytes(_ capacityBytes: Int64) {
        self.capacityBytes = max(capacityBytes, 1)
        prepareDirectory()
        trimIfNeeded()
    }

    func usage() -> CacheUsage {
        prepareDirectory()
        let files = cacheFiles()
        return CacheUsage(
            byteCount: files.reduce(Int64(0)) { $0 + $1.size },
            itemCount: files.count,
            capacityBytes: capacityBytes
        )
    }

    private func fileURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directoryURL.appendingPathComponent(digest, isDirectory: false)
    }

    private func prepareDirectory() {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func touch(_ url: URL) {
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }

    private func trimIfNeeded() {
        var files = cacheFiles()
        var totalBytes = files.reduce(Int64(0)) { $0 + $1.size }
        guard totalBytes > capacityBytes else { return }

        files.sort { $0.modificationDate < $1.modificationDate }
        for file in files {
            try? fileManager.removeItem(at: file.url)
            totalBytes -= file.size
            if totalBytes <= capacityBytes {
                break
            }
        }
    }

    private func cacheFiles() -> [CacheFile] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let urls = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        )) ?? []

        return urls.compactMap { url in
            guard
                let values = try? url.resourceValues(forKeys: keys),
                values.isRegularFile == true
            else {
                return nil
            }
            return CacheFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modificationDate: values.contentModificationDate ?? .distantPast
            )
        }
    }
}

private nonisolated struct CacheFile {
    let url: URL
    let size: Int64
    let modificationDate: Date
}

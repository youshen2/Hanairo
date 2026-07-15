import Foundation
import Observation

@MainActor
@Observable
final class BrowsingHistoryStore {
    private(set) var entries: [BrowsingHistoryEntry] = []

    private let settings: AppSettings
    private let fileManager: FileManager
    private let fileURL: URL

    init(
        settings: AppSettings,
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.settings = settings
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        load()
        trimToLimit()
    }

    func record(_ illustration: PixivIllustration) {
        guard settings.recordsBrowsingHistory else { return }
        entries.removeAll { $0.id == illustration.id }
        entries.insert(
            BrowsingHistoryEntry(illustration: illustration, viewedAt: Date()),
            at: 0
        )
        trimToLimit()
        persist()
    }

    func updateBookmark(id: Int, isBookmarked: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].illustration.isBookmarked = isBookmarked
        persist()
    }

    func remove(id: Int) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        entries = []
        try? fileManager.removeItem(at: fileURL)
    }

    func applyCurrentLimit() {
        let previousCount = entries.count
        trimToLimit()
        if entries.count != previousCount {
            persist()
        }
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([BrowsingHistoryEntry].self, from: data)
        else {
            return
        }
        var seen = Set<Int>()
        entries = decoded
            .sorted { $0.viewedAt > $1.viewedAt }
            .filter { seen.insert($0.id).inserted }
    }

    private func trimToLimit() {
        entries = Array(entries.prefix(settings.browsingHistoryLimit))
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return root
            .appending(path: "Hanairo", directoryHint: .isDirectory)
            .appending(path: "BrowsingHistory.json", directoryHint: .notDirectory)
    }
}

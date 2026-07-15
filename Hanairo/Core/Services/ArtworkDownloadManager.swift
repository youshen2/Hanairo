import Foundation
import Observation

@MainActor
@Observable
final class ArtworkDownloadManager {
    private(set) var tasks: [ArtworkDownloadTask]
    private(set) var records: [ArtworkDownloadRecord]

    @ObservationIgnored private let imageRepository: ImageRepository
    @ObservationIgnored private let repository: PixivRepository
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private var workerTask: Task<Void, Never>?

    init(
        imageRepository: ImageRepository,
        repository: PixivRepository,
        settings: AppSettings,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.imageRepository = imageRepository
        self.repository = repository
        self.settings = settings
        self.defaults = defaults
        self.fileManager = fileManager
        tasks = Self.loadTasks(defaults: defaults)
        records = Self.loadRecords(defaults: defaults)
        Task { [weak self] in
            self?.startIfNeeded()
        }
    }

    func enqueue(
        illustration: PixivIllustration,
        pageIndices: [Int]
    ) -> ArtworkDownloadEnqueueResult {
        let destination = settings.downloadDestination
        if tasks.contains(where: {
            $0.illustrationID == illustration.id && $0.destination == destination
        }) {
            return .alreadyQueued
        }

        let allURLs = illustration.originalPageURLs
        let downloadedIndexes = Set(
            records.first(where: {
                $0.illustrationID == illustration.id && $0.destination == destination
            })?.pages.map(\.pageIndex) ?? []
        )
        let pages = Array(Set(pageIndices))
            .sorted()
            .compactMap { index -> ArtworkDownloadPage? in
                guard allURLs.indices.contains(index),
                      !downloadedIndexes.contains(index),
                      let url = allURLs[index] else {
                    return nil
                }
                return ArtworkDownloadPage(pageIndex: index, url: url)
            }

        guard !pages.isEmpty else {
            let hasAvailableURL = pageIndices.contains { index in
                allURLs.indices.contains(index) && allURLs[index] != nil
            }
            return hasAvailableURL ? .alreadyDownloaded : .noAvailablePages
        }

        tasks.append(
            ArtworkDownloadTask(
                id: UUID(),
                illustrationID: illustration.id,
                title: illustration.title,
                artistName: illustration.user.name,
                previewURL: illustration.previewURL,
                pages: pages,
                totalArtworkPageCount: illustration.pages.count,
                destination: destination,
                status: .queued,
                createdAt: Date(),
                startedAt: nil,
                completedPageIndexes: [],
                currentPageIndex: nil,
                downloadedBytes: 0,
                errorMessage: nil
            )
        )
        saveTasks()
        bookmarkIfNeeded(illustration)
        startIfNeeded()
        return .queued(pages.count)
    }

    func pause(_ task: ArtworkDownloadTask) {
        updateTask(task.id) { value in
            guard value.status == .queued || value.status == .downloading else { return }
            value.status = .paused
            value.errorMessage = nil
        }
        saveTasks()
    }

    func resume(_ task: ArtworkDownloadTask) {
        updateTask(task.id) { value in
            guard value.status == .paused else { return }
            value.status = .queued
            value.currentPageIndex = nil
            value.errorMessage = nil
        }
        saveTasks()
        startIfNeeded()
    }

    func retry(_ task: ArtworkDownloadTask) {
        updateTask(task.id) { value in
            guard value.status == .failed else { return }
            value.status = .queued
            value.currentPageIndex = nil
            value.errorMessage = nil
        }
        saveTasks()
        startIfNeeded()
    }

    func prioritize(_ task: ArtworkDownloadTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var value = tasks.remove(at: index)
        if value.status != .downloading {
            value.status = .queued
            value.errorMessage = nil
        }
        tasks.insert(value, at: 0)
        saveTasks()
        startIfNeeded()
    }

    func removeTask(_ task: ArtworkDownloadTask) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }

    func clearTasks() {
        tasks.removeAll()
        saveTasks()
    }

    func removeRecord(_ record: ArtworkDownloadRecord) {
        records.removeAll { $0.id == record.id }
        if record.destination == .files,
           let directory = artworkDirectoryIfAvailable(record: record) {
            try? fileManager.removeItem(at: directory)
        }
        saveRecords()
    }

    func clearRecords() {
        let directories = records.compactMap { record in
            record.destination == .files ? artworkDirectoryIfAvailable(record: record) : nil
        }
        records.removeAll()
        directories.forEach { try? fileManager.removeItem(at: $0) }
        saveRecords()
    }

    func localURL(for record: ArtworkDownloadRecord, page: DownloadedArtworkPage) -> URL? {
        guard let fileName = page.fileName,
              let directory = artworkDirectoryIfAvailable(record: record) else {
            return nil
        }
        let url = directory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func storageUsage() async -> ArtworkDownloadStorageUsage {
        let filesBytes = Self.directorySize(at: downloadsRootIfAvailable())
        let metadataBytes = Int64(
            (defaults.data(forKey: Keys.tasks)?.count ?? 0)
                + (defaults.data(forKey: Keys.records)?.count ?? 0)
        )
        return ArtworkDownloadStorageUsage(filesBytes: filesBytes, metadataBytes: metadataBytes)
    }

    private func startIfNeeded() {
        guard workerTask == nil,
              tasks.contains(where: { $0.status.canRun }) else {
            return
        }
        workerTask = Task { [weak self] in
            await self?.processQueue()
        }
    }

    private func bookmarkIfNeeded(_ illustration: PixivIllustration) {
        guard settings.bookmarksOnDownload,
              !repository.bookmarkState(for: illustration) else {
            return
        }
        let visibility = settings.defaultBookmarkVisibility
        Task { @MainActor [weak repository] in
            try? await repository?.updateBookmark(
                id: illustration.id,
                visibility: visibility,
                tags: []
            )
        }
    }

    private func processQueue() async {
        defer {
            workerTask = nil
            if tasks.contains(where: { $0.status.canRun }) {
                startIfNeeded()
            }
        }

        await withTaskGroup(of: UUID.self) { group in
            var activeIDs = Set<UUID>()

            while activeIDs.count < settings.downloadConcurrentTaskCount,
                  let id = nextQueuedTaskID(excluding: activeIDs) {
                activeIDs.insert(id)
                group.addTask { @MainActor [weak self] in
                    await self?.runTask(id: id)
                    return id
                }
            }

            while let completedID = await group.next() {
                activeIDs.remove(completedID)
                while activeIDs.count < settings.downloadConcurrentTaskCount,
                      let id = nextQueuedTaskID(excluding: activeIDs) {
                    activeIDs.insert(id)
                    group.addTask { @MainActor [weak self] in
                        await self?.runTask(id: id)
                        return id
                    }
                }
            }
        }
    }

    private func nextQueuedTaskID(excluding activeIDs: Set<UUID>) -> UUID? {
        tasks.first { $0.status.canRun && !activeIDs.contains($0.id) }?.id
    }

    private func runTask(id: UUID) async {
        guard let task = tasks.first(where: { $0.id == id }), task.status.canRun else { return }
        updateTask(id) { value in
            value.status = .downloading
            value.startedAt = Date()
            value.errorMessage = nil
        }
        saveTasks()

        do {
            for page in task.pages where !task.completedPageIndexes.contains(page.pageIndex) {
                try checkTaskCanContinue(id)
                updateTask(id) { $0.currentPageIndex = page.pageIndex }
                saveTasks()

                let data = try await loadPageData(page.url, taskID: id)
                try checkTaskCanContinue(id)
                let fileName = try await save(
                    data: data,
                    page: page,
                    task: task
                )
                try checkTaskCanContinue(id)
                appendRecordPage(
                    task: task,
                    page: DownloadedArtworkPage(
                        pageIndex: page.pageIndex,
                        fileName: fileName,
                        byteCount: Int64(data.count)
                    )
                )
                updateTask(id) { value in
                    value.completedPageIndexes.insert(page.pageIndex)
                    value.downloadedBytes += Int64(data.count)
                }
                saveTasks()
            }

            tasks.removeAll { $0.id == id }
            saveTasks()
        } catch DownloadControlError.stopped {
            saveTasks()
        } catch is CancellationError {
            updateTask(id) { value in
                if value.status == .downloading {
                    value.status = .queued
                    value.currentPageIndex = nil
                }
            }
            saveTasks()
        } catch {
            updateTask(id) { value in
                value.status = .failed
                value.errorMessage = error.localizedDescription
            }
            saveTasks()
        }
    }

    private func loadPageData(_ url: URL, taskID: UUID) async throws -> Data {
        var lastError: Error?
        for attempt in 0...settings.downloadRetryCount {
            try checkTaskCanContinue(taskID)
            do {
                return try await imageRepository.data(
                    for: url,
                    bypassingCache: !settings.downloadReadsImageCache
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                guard attempt < settings.downloadRetryCount else { break }
                try await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
            }
        }
        throw lastError ?? NetworkError.invalidImage
    }

    private func save(
        data: Data,
        page: ArtworkDownloadPage,
        task: ArtworkDownloadTask
    ) async throws -> String? {
        switch task.destination {
        case .photoLibrary:
            try await PhotoLibrarySaver.save(data)
            return nil
        case .files:
            let directory = try artworkDirectory(task: task)
            let fileExtension = Self.safeExtension(page.url.pathExtension)
            let fileName = "\(task.illustrationID)_p\(page.pageIndex + 1).\(fileExtension)"
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            return fileName
        }
    }

    private func appendRecordPage(task: ArtworkDownloadTask, page: DownloadedArtworkPage) {
        var record = records.first(where: {
            $0.illustrationID == task.illustrationID && $0.destination == task.destination
        }) ?? ArtworkDownloadRecord(
            illustrationID: task.illustrationID,
            title: task.title,
            artistName: task.artistName,
            previewURL: task.previewURL,
            destination: task.destination,
            pages: [],
            totalArtworkPageCount: task.totalArtworkPageCount,
            totalBytes: 0,
            updatedAt: Date()
        )

        if let existing = record.pages.firstIndex(where: { $0.pageIndex == page.pageIndex }) {
            record.totalBytes -= record.pages[existing].byteCount
            record.pages[existing] = page
        } else {
            record.pages.append(page)
        }
        record.pages.sort { $0.pageIndex < $1.pageIndex }
        record.totalBytes += page.byteCount
        record.updatedAt = Date()
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        saveRecords()
    }

    private func checkTaskCanContinue(_ id: UUID) throws {
        guard let task = tasks.first(where: { $0.id == id }),
              task.status == .downloading else {
            throw DownloadControlError.stopped
        }
    }

    private func updateTask(_ id: UUID, update: (inout ArtworkDownloadTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        update(&tasks[index])
    }

    private func saveTasks() {
        let persisted = tasks.map { task -> ArtworkDownloadTask in
            var value = task
            if value.status == .downloading {
                value.status = .queued
                value.currentPageIndex = nil
            }
            return value
        }
        guard let data = try? encoder.encode(persisted) else { return }
        defaults.set(data, forKey: Keys.tasks)
    }

    private func saveRecords() {
        guard let data = try? encoder.encode(records) else { return }
        defaults.set(data, forKey: Keys.records)
    }

    private func artworkDirectory(task: ArtworkDownloadTask) throws -> URL {
        let directory = try downloadsRoot()
            .appendingPathComponent(
                Self.safeFileName("\(task.illustrationID)-\(task.title)"),
                isDirectory: true
            )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func artworkDirectoryIfAvailable(record: ArtworkDownloadRecord) -> URL? {
        downloadsRootIfAvailable()?.appendingPathComponent(
            Self.safeFileName("\(record.illustrationID)-\(record.title)"),
            isDirectory: true
        )
    }

    private func downloadsRoot() throws -> URL {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = documents.appendingPathComponent("Hanairo Downloads", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func downloadsRootIfAvailable() -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Hanairo Downloads", isDirectory: true)
    }

    private static func loadTasks(defaults: UserDefaults) -> [ArtworkDownloadTask] {
        guard let data = defaults.data(forKey: Keys.tasks),
              let values = try? JSONDecoder().decode([ArtworkDownloadTask].self, from: data) else {
            return []
        }
        return values.map { task in
            var value = task
            if value.status == .downloading {
                value.status = .queued
                value.currentPageIndex = nil
            }
            return value
        }
    }

    private static func loadRecords(defaults: UserDefaults) -> [ArtworkDownloadRecord] {
        guard let data = defaults.data(forKey: Keys.records),
              let values = try? JSONDecoder().decode([ArtworkDownloadRecord].self, from: data) else {
            return []
        }
        return values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private static func safeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let components = value.components(separatedBy: invalid)
        let result = components.joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        return String((result.isEmpty ? "未命名作品" : result).prefix(100))
    }

    private static func safeExtension(_ value: String) -> String {
        let normalized = value.lowercased()
        let allowed = ["jpg", "jpeg", "png", "gif", "webp"]
        return allowed.contains(normalized) ? normalized : "jpg"
    }

    private static func directorySize(at url: URL?) -> Int64 {
        guard let url,
              let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
            total += Int64(size ?? 0)
        }
        return total
    }

    private enum Keys {
        static let tasks = "downloads.tasks"
        static let records = "downloads.records"
    }

    private enum DownloadControlError: Error {
        case stopped
    }
}

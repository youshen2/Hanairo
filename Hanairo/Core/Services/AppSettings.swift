import Observation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ArtworkImageQuality: String, CaseIterable, Identifiable {
    case medium
    case large
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .medium: "标准"
        case .large: "高清"
        case .original: "原图"
        }
    }
}

enum ArtworkDownloadDestination: String, CaseIterable, Identifiable, Codable, Sendable {
    case files
    case photoLibrary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: "文件（Hanairo Downloads）"
        case .photoLibrary: "相册"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let defaultImageCacheLimitMB = 400
    static let imageCacheLimitRange = 50...2_000
    static let defaultDetailCacheLimitMB = 50
    static let detailCacheLimitRange = 5...500
    static let defaultUgoiraCacheLimitMB = 500
    static let ugoiraCacheLimitRange = 50...2_000
    static let downloadConcurrentTaskRange = 1...4
    static let downloadRetryRange = 0...8
    static let browsingHistoryLimitRange = 50...1_000
    static let defaultProfileBackgroundScreenRatio = 0.56
    static let profileBackgroundScreenRatioRange = 0.45...1.0

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var imageQuality: ArtworkImageQuality {
        didSet { defaults.set(imageQuality.rawValue, forKey: Keys.imageQuality) }
    }
    var artworkParallaxEnabled: Bool {
        didSet { defaults.set(artworkParallaxEnabled, forKey: Keys.artworkParallaxEnabled) }
    }
    var checksUpdatesOnLaunch: Bool {
        didSet { defaults.set(checksUpdatesOnLaunch, forKey: Keys.checksUpdatesOnLaunch) }
    }
    var profileBackgroundScreenRatio: Double {
        didSet {
            defaults.set(profileBackgroundScreenRatio, forKey: Keys.profileBackgroundScreenRatio)
        }
    }
    var downloadDestination: ArtworkDownloadDestination {
        didSet { defaults.set(downloadDestination.rawValue, forKey: Keys.downloadDestination) }
    }
    var defaultBookmarkVisibility: PixivVisibility {
        didSet { defaults.set(defaultBookmarkVisibility.rawValue, forKey: Keys.defaultBookmarkVisibility) }
    }
    var defaultFollowVisibility: PixivVisibility {
        didSet { defaults.set(defaultFollowVisibility.rawValue, forKey: Keys.defaultFollowVisibility) }
    }
    var downloadConcurrentTaskCount: Int {
        didSet { defaults.set(downloadConcurrentTaskCount, forKey: Keys.downloadConcurrentTaskCount) }
    }
    var downloadRetryCount: Int {
        didSet { defaults.set(downloadRetryCount, forKey: Keys.downloadRetryCount) }
    }
    var downloadReadsImageCache: Bool {
        didSet { defaults.set(downloadReadsImageCache, forKey: Keys.downloadReadsImageCache) }
    }
    var bookmarksOnDownload: Bool {
        didSet { defaults.set(bookmarksOnDownload, forKey: Keys.bookmarksOnDownload) }
    }
    var showsAIArtwork: Bool {
        didSet { defaults.set(showsAIArtwork, forKey: Keys.showsAIArtwork) }
    }
    var showsMatureArtwork: Bool {
        didSet { defaults.set(showsMatureArtwork, forKey: Keys.showsMatureArtwork) }
    }
    var recordsBrowsingHistory: Bool {
        didSet { defaults.set(recordsBrowsingHistory, forKey: Keys.recordsBrowsingHistory) }
    }
    var browsingHistoryLimit: Int {
        didSet { defaults.set(browsingHistoryLimit, forKey: Keys.browsingHistoryLimit) }
    }
    var imageCacheLimitMB: Int {
        didSet { defaults.set(imageCacheLimitMB, forKey: Keys.imageCacheLimitMB) }
    }
    var detailCacheEnabled: Bool {
        didSet { defaults.set(detailCacheEnabled, forKey: Keys.detailCacheEnabled) }
    }
    var detailCacheLimitMB: Int {
        didSet { defaults.set(detailCacheLimitMB, forKey: Keys.detailCacheLimitMB) }
    }
    var ugoiraCacheLimitMB: Int {
        didSet { defaults.set(ugoiraCacheLimitMB, forKey: Keys.ugoiraCacheLimitMB) }
    }

    var imageCacheCapacityBytes: Int64 {
        Int64(imageCacheLimitMB) * 1_024 * 1_024
    }

    var detailCacheCapacityBytes: Int64 {
        Int64(detailCacheLimitMB) * 1_024 * 1_024
    }

    var ugoiraCacheCapacityBytes: Int64 {
        Int64(ugoiraCacheLimitMB) * 1_024 * 1_024
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        imageQuality = ArtworkImageQuality(rawValue: defaults.string(forKey: Keys.imageQuality) ?? "") ?? .large
        artworkParallaxEnabled = defaults.object(forKey: Keys.artworkParallaxEnabled) as? Bool ?? true
        checksUpdatesOnLaunch = defaults.object(forKey: Keys.checksUpdatesOnLaunch) as? Bool ?? true
        profileBackgroundScreenRatio = Self.storedValue(
            defaults.object(forKey: Keys.profileBackgroundScreenRatio).map { _ in
                defaults.double(forKey: Keys.profileBackgroundScreenRatio)
            },
            defaultValue: Self.defaultProfileBackgroundScreenRatio,
            range: Self.profileBackgroundScreenRatioRange
        )
        downloadDestination = ArtworkDownloadDestination(
            rawValue: defaults.string(forKey: Keys.downloadDestination) ?? ""
        ) ?? .files
        defaultBookmarkVisibility = PixivVisibility(
            rawValue: defaults.string(forKey: Keys.defaultBookmarkVisibility) ?? ""
        ) ?? .public
        defaultFollowVisibility = PixivVisibility(
            rawValue: defaults.string(forKey: Keys.defaultFollowVisibility) ?? ""
        ) ?? .public
        downloadConcurrentTaskCount = Self.storedCacheLimit(
            defaults.integer(forKey: Keys.downloadConcurrentTaskCount),
            defaultValue: 2,
            range: Self.downloadConcurrentTaskRange
        )
        downloadRetryCount = Self.storedValue(
            defaults.object(forKey: Keys.downloadRetryCount) as? Int,
            defaultValue: 2,
            range: Self.downloadRetryRange
        )
        downloadReadsImageCache = defaults.object(forKey: Keys.downloadReadsImageCache) as? Bool ?? true
        bookmarksOnDownload = defaults.object(forKey: Keys.bookmarksOnDownload) as? Bool ?? false
        showsAIArtwork = defaults.object(forKey: Keys.showsAIArtwork) as? Bool ?? true
        showsMatureArtwork = defaults.object(forKey: Keys.showsMatureArtwork) as? Bool ?? false
        recordsBrowsingHistory = defaults.object(forKey: Keys.recordsBrowsingHistory) as? Bool ?? true
        browsingHistoryLimit = Self.storedValue(
            defaults.object(forKey: Keys.browsingHistoryLimit) as? Int,
            defaultValue: 300,
            range: Self.browsingHistoryLimitRange
        )
        imageCacheLimitMB = Self.storedCacheLimit(
            defaults.integer(forKey: Keys.imageCacheLimitMB),
            defaultValue: Self.defaultImageCacheLimitMB,
            range: Self.imageCacheLimitRange
        )
        detailCacheEnabled = defaults.object(forKey: Keys.detailCacheEnabled) as? Bool ?? true
        detailCacheLimitMB = Self.storedCacheLimit(
            defaults.integer(forKey: Keys.detailCacheLimitMB),
            defaultValue: Self.defaultDetailCacheLimitMB,
            range: Self.detailCacheLimitRange
        )
        ugoiraCacheLimitMB = Self.storedCacheLimit(
            defaults.integer(forKey: Keys.ugoiraCacheLimitMB),
            defaultValue: Self.defaultUgoiraCacheLimitMB,
            range: Self.ugoiraCacheLimitRange
        )
    }

    private static func storedCacheLimit(_ value: Int, defaultValue: Int, range: ClosedRange<Int>) -> Int {
        guard value > 0 else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func storedValue(_ value: Int?, defaultValue: Int, range: ClosedRange<Int>) -> Int {
        guard let value else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func storedValue(
        _ value: Double?,
        defaultValue: Double,
        range: ClosedRange<Double>
    ) -> Double {
        guard let value else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private enum Keys {
        static let appearance = "settings.appearance"
        static let imageQuality = "settings.imageQuality"
        static let artworkParallaxEnabled = "settings.artworkParallaxEnabled"
        static let checksUpdatesOnLaunch = "settings.appBehavior.checksUpdatesOnLaunch"
        static let profileBackgroundScreenRatio = "settings.profileBackgroundScreenRatio"
        static let downloadDestination = "settings.downloadDestination"
        static let defaultBookmarkVisibility = "settings.defaultBookmarkVisibility"
        static let defaultFollowVisibility = "settings.defaultFollowVisibility"
        static let downloadConcurrentTaskCount = "settings.downloadConcurrentTaskCount"
        static let downloadRetryCount = "settings.downloadRetryCount"
        static let downloadReadsImageCache = "settings.downloadReadsImageCache"
        static let bookmarksOnDownload = "settings.bookmarksOnDownload"
        static let showsAIArtwork = "settings.showsAIArtwork"
        static let showsMatureArtwork = "settings.showsMatureArtwork"
        static let recordsBrowsingHistory = "settings.recordsBrowsingHistory"
        static let browsingHistoryLimit = "settings.browsingHistoryLimit"
        static let imageCacheLimitMB = "settings.imageCacheLimitMB"
        static let detailCacheEnabled = "settings.detailCacheEnabled"
        static let detailCacheLimitMB = "settings.detailCacheLimitMB"
        static let ugoiraCacheLimitMB = "settings.ugoiraCacheLimitMB"
    }
}

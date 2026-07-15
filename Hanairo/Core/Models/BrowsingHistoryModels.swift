import Foundation

struct BrowsingHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    var illustration: PixivIllustration
    var viewedAt: Date

    var id: Int { illustration.id }
}

import Foundation

enum LibrarySection: String, CaseIterable, Identifiable {
    case bookmarks
    case followingFeed
    case followingUsers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookmarks: "收藏"
        case .followingFeed: "动态"
        case .followingUsers: "关注"
        }
    }
}

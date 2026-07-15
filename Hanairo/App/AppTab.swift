import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case discovery
    case ranking
    case library
    case search
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discovery: "推荐"
        case .ranking: "排行"
        case .library: "收藏"
        case .search: "搜索"
        case .more: "更多"
        }
    }

    var systemImage: String {
        switch self {
        case .discovery: "sparkles"
        case .ranking: "trophy"
        case .library: "heart"
        case .search: "magnifyingglass"
        case .more: "ellipsis.circle"
        }
    }

    @ViewBuilder
    var rootView: some View {
        switch self {
        case .discovery: DiscoveryView()
        case .ranking: RankingView()
        case .library: LibraryView()
        case .search: SearchView()
        case .more: MoreView()
        }
    }
}

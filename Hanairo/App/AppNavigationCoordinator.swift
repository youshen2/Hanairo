import Foundation
import Observation

@MainActor
@Observable
final class AppNavigationCoordinator {
    var selectedTab: AppTab = .discovery

    private var paths: [AppTab: [AppRoute]] = [:]

    func path(for tab: AppTab) -> [AppRoute] {
        paths[tab, default: []]
    }

    func setPath(_ path: [AppRoute], for tab: AppTab) {
        paths[tab] = path
    }

    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let route = DeepLinkParser.route(for: url) else { return false }
        open(route)
        return true
    }

    func open(_ route: AppRoute) {
        let tab = preferredTab(for: route)
        selectedTab = tab
        paths[tab] = [route]
    }

    func push(_ route: AppRoute) {
        paths[selectedTab, default: []].append(route)
    }

    private func preferredTab(for route: AppRoute) -> AppTab {
        switch route {
        case .search:
            .search
        case .mangaWatchlist, .browsingHistory, .downloads, .downloadRecord,
             .settings, .localDataSettings, .about:
            .more
        default:
            .discovery
        }
    }
}

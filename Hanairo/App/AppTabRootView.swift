import SwiftUI

struct AppTabRootView: View {
    let tab: AppTab
    @Environment(AppNavigationCoordinator.self) private var navigation

    var body: some View {
        NavigationStack(path: pathBinding) {
            tab.rootView
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    private var pathBinding: Binding<[AppRoute]> {
        Binding(
            get: { navigation.path(for: tab) },
            set: { navigation.setPath($0, for: tab) }
        )
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case let .illustration(id):
            IllustrationDetailView(illustrationID: id)
        case let .illustrationSeries(id):
            IllustrationSeriesView(seriesID: id)
        case .mangaWatchlist:
            MangaWatchlistView()
        case .recommendedUsers:
            RecommendedUsersView()
        case .browsingHistory:
            BrowsingHistoryView()
        case .downloads:
            DownloadsView()
        case let .downloadRecord(id):
            DownloadedArtworkDetailView(recordID: id)
        case let .user(id):
            UserDetailView(userID: id)
        case let .userConnections(userID, kind):
            UserConnectionsView(userID: userID, kind: kind)
        case let .search(query):
            SearchView(initialQuery: query)
        case .settings:
            SettingsView()
        case .localDataSettings:
            LocalDataSettingsView()
        case .about:
            AboutView()
        }
    }
}

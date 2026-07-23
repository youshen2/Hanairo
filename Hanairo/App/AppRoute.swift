import Foundation

enum AppRoute: Hashable {
    case illustration(id: Int, preview: PixivIllustration? = nil)
    case illustrationSeries(id: Int)
    case mangaWatchlist
    case recommendedUsers
    case browsingHistory
    case downloads
    case downloadRecord(id: String)
    case user(id: Int)
    case userConnections(userID: Int, kind: UserConnectionKind)
    case search(query: String)
    case settings
    case localDataSettings
    case about
}

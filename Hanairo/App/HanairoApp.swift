import SwiftUI

@main
struct HanairoApp: App {
    @State private var authentication: AuthenticationStore
    @State private var navigation: AppNavigationCoordinator
    @State private var settings: AppSettings
    @State private var networkSettings: NetworkSettings
    @State private var localBlocks: LocalBlockStore
    @State private var browsingHistory: BrowsingHistoryStore
    @State private var repository: PixivRepository
    @State private var imageRepository: ImageRepository
    @State private var theme: AppTheme
    @State private var ugoiraRepository: UgoiraRepository
    @State private var downloadManager: ArtworkDownloadManager

    init() {
        let settings = AppSettings()
        let networkSettings = NetworkSettings()
        let sessionProvider = NetworkSessionProvider(settings: networkSettings)
        let authentication = AuthenticationStore(
            api: AuthenticationAPI(
                client: NetworkClient(sessionProvider: sessionProvider),
                networkSettings: networkSettings
            ),
            credentialStore: CredentialStore()
        )
        let localBlocks = LocalBlockStore()
        let browsingHistory = BrowsingHistoryStore(settings: settings)
        let repository = PixivRepository(
            authentication: authentication,
            settings: settings,
            localBlocks: localBlocks,
            networkSettings: networkSettings,
            sessionProvider: sessionProvider
        )
        let imageRepository = ImageRepository(
            settings: settings,
            networkSettings: networkSettings,
            sessionProvider: sessionProvider
        )
        _authentication = State(initialValue: authentication)
        _navigation = State(initialValue: AppNavigationCoordinator())
        _settings = State(initialValue: settings)
        _networkSettings = State(initialValue: networkSettings)
        _localBlocks = State(initialValue: localBlocks)
        _browsingHistory = State(initialValue: browsingHistory)
        _repository = State(initialValue: repository)
        _imageRepository = State(initialValue: imageRepository)
        _theme = State(initialValue: AppTheme(imageRepository: imageRepository))
        _ugoiraRepository = State(
            initialValue: UgoiraRepository(
                pixivRepository: repository,
                settings: settings,
                networkSettings: networkSettings,
                sessionProvider: sessionProvider
            )
        )
        _downloadManager = State(
            initialValue: ArtworkDownloadManager(
                imageRepository: imageRepository,
                repository: repository,
                settings: settings
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(navigation)
                .environment(authentication)
                .environment(settings)
                .environment(networkSettings)
                .environment(localBlocks)
                .environment(browsingHistory)
                .environment(repository)
                .environment(imageRepository)
                .environment(theme)
                .environment(ugoiraRepository)
                .environment(downloadManager)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task {
                    await authentication.restore()
                }
        }
    }
}

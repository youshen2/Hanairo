import SwiftUI

@MainActor
extension View {
    func withPreviewDependencies() -> some View {
        let defaults = UserDefaults(suiteName: "moye.Hanairo.previews") ?? .standard
        let authentication = AuthenticationStore(defaults: defaults)
        let settings = AppSettings(defaults: defaults)
        let networkSettings = NetworkSettings(defaults: defaults)
        let sessionProvider = NetworkSessionProvider(settings: networkSettings)
        let localBlocks = LocalBlockStore(defaults: defaults)
        let browsingHistory = BrowsingHistoryStore(
            settings: settings,
            fileURL: FileManager.default.temporaryDirectory
                .appending(path: "Hanairo-Preview-History.json")
        )
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
        return environment(authentication)
            .environment(AppNavigationCoordinator())
            .environment(settings)
            .environment(networkSettings)
            .environment(localBlocks)
            .environment(browsingHistory)
            .environment(repository)
            .environment(imageRepository)
            .environment(AppTheme(imageRepository: imageRepository))
            .environment(
                UgoiraRepository(
                    pixivRepository: repository,
                    settings: settings,
                    networkSettings: networkSettings,
                    sessionProvider: sessionProvider
                )
            )
            .environment(
                ArtworkDownloadManager(
                    imageRepository: imageRepository,
                    repository: repository,
                    settings: settings,
                    defaults: defaults
                )
            )
    }
}

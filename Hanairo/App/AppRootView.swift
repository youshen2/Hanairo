import SwiftUI

struct AppRootView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(AppNavigationCoordinator.self) private var navigation
    @Environment(AppTheme.self) private var theme

    var body: some View {
        Group {
            switch rootState {
            case .restoring:
                LaunchView()
            case .authenticated:
                AppShellView()
            case .requiresAuthentication:
                NavigationStack {
                    LoginView()
                }
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.25), value: rootState)
        .tint(theme.accentColor)
        .task(id: accountThemeImageURL) {
            await theme.updateAccountAccent(imageURL: accountThemeImageURL)
        }
        .onOpenURL { url in
            navigation.open(url)
        }
        .withAppLaunchExperience(isReady: rootState != .restoring)
    }

    private var accountThemeImageURL: URL? {
        authentication.account?.profileImageURLs.large
            ?? authentication.account?.profileImageURLs.medium
            ?? authentication.account?.profileImageURLs.small
    }

    private var rootState: RootState {
        if authentication.isRestoring {
            return .restoring
        }
        return authentication.isAuthenticated ? .authenticated : .requiresAuthentication
    }
}

private enum RootState: Hashable {
    case restoring
    case authenticated
    case requiresAuthentication
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.pink.gradient)
                    .symbolEffect(.pulse)
                Text("Hanairo")
                    .font(.title2.weight(.semibold))
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

#Preview {
    let authentication = AuthenticationStore()
    let settings = AppSettings()
    let networkSettings = NetworkSettings()
    let sessionProvider = NetworkSessionProvider(settings: networkSettings)
    let localBlocks = LocalBlockStore()
    let browsingHistory = BrowsingHistoryStore(
        settings: settings,
        fileURL: FileManager.default.temporaryDirectory
            .appending(path: "Hanairo-AppRoot-Preview-History.json")
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
    AppRootView()
        .environment(AppNavigationCoordinator())
        .environment(authentication)
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
                settings: settings
            )
        )
}

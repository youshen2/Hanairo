import SwiftUI

struct AppShellView: View {
    @Environment(AppNavigationCoordinator.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                AppTabRootView(tab: tab)
                    .tag(tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
            }
        }
    }
}

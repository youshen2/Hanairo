import SwiftUI

private struct AppNavigationTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    fileprivate var appNavigationTransitionNamespace: Namespace.ID? {
        get { self[AppNavigationTransitionNamespaceKey.self] }
        set { self[AppNavigationTransitionNamespaceKey.self] = newValue }
    }
}

extension View {
    func appNavigationTransitionNamespace(_ namespace: Namespace.ID) -> some View {
        environment(\.appNavigationTransitionNamespace, namespace)
    }

    func appNavigationTransitionSource(for route: AppRoute) -> some View {
        modifier(AppNavigationTransitionSourceModifier(route: route))
    }

    @ViewBuilder
    func appNavigationTransitionDestination(
        for route: AppRoute,
        in namespace: Namespace.ID
    ) -> some View {
        if let transitionID = route.navigationTransitionID {
            navigationTransition(.zoom(sourceID: transitionID, in: namespace))
        } else {
            self
        }
    }
}

private struct AppNavigationTransitionSourceModifier: ViewModifier {
    @Environment(\.appNavigationTransitionNamespace) private var namespace

    let route: AppRoute

    @ViewBuilder
    func body(content: Content) -> some View {
        if
            let namespace,
            let transitionID = route.navigationTransitionID
        {
            content.matchedTransitionSource(id: transitionID, in: namespace)
        } else {
            content
        }
    }
}

private enum AppNavigationTransitionID: Hashable {
    case illustration(Int)
    case user(Int)
}

private extension AppRoute {
    var navigationTransitionID: AppNavigationTransitionID? {
        switch self {
        case let .illustration(id, _):
            .illustration(id)
        case let .user(id):
            .user(id)
        default:
            nil
        }
    }
}

import Foundation
import Observation

enum PaginationPhase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor
@Observable
final class PaginatedStore<Item: Sendable> {
    private(set) var items: [Item] = []
    private(set) var nextURL: URL?
    private(set) var phase: PaginationPhase = .idle
    private(set) var isRefreshing = false
    private(set) var isLoadingMore = false
    private(set) var refreshError: String?
    private(set) var loadMoreError: String?

    @ObservationIgnored private var activeRequestKey: String?
    @ObservationIgnored private var completedRequestKey: String?
    @ObservationIgnored private var activeReloadID = UUID()
    @ObservationIgnored private var activeReloadRequestKey: String?
    @ObservationIgnored private var activeLoadMoreID = UUID()
    @ObservationIgnored private let identity: (Item) -> AnyHashable

    init<ID: Hashable>(id: @escaping (Item) -> ID) {
        identity = { AnyHashable(id($0)) }
    }

    func prepare(for requestKey: String) {
        guard activeRequestKey != requestKey else { return }
        activeRequestKey = requestKey
        completedRequestKey = nil
        activeReloadID = UUID()
        activeReloadRequestKey = nil
        activeLoadMoreID = UUID()
        items = []
        nextURL = nil
        phase = .loading
        isRefreshing = false
        isLoadingMore = false
        refreshError = nil
        loadMoreError = nil
    }

    func loadIfNeeded(
        requestKey: String,
        loader: () async throws -> PixivPage<Item>
    ) async {
        prepare(for: requestKey)
        guard
            completedRequestKey != requestKey,
            activeReloadRequestKey != requestKey
        else {
            return
        }
        await reload(requestKey: requestKey, showsInitialLoading: true, loader: loader)
    }

    func reload(
        requestKey: String,
        showsInitialLoading: Bool,
        loader: () async throws -> PixivPage<Item>
    ) async {
        prepare(for: requestKey)
        guard activeReloadRequestKey != requestKey else { return }

        let operationID = UUID()
        activeReloadID = operationID
        activeReloadRequestKey = requestKey
        activeLoadMoreID = UUID()
        isLoadingMore = false
        loadMoreError = nil
        refreshError = nil

        if showsInitialLoading || items.isEmpty {
            phase = .loading
        } else {
            isRefreshing = true
        }

        do {
            let page = try await loader()
            guard
                activeReloadID == operationID,
                activeRequestKey == requestKey
            else {
                return
            }
            guard !Task.isCancelled else {
                phase = items.isEmpty ? .idle : .loaded
                finishReload(operationID: operationID)
                return
            }
            items = unique(page.items)
            nextURL = page.nextURL
            phase = .loaded
            completedRequestKey = requestKey
            finishReload(operationID: operationID)
        } catch is CancellationError {
            guard activeReloadID == operationID else { return }
            phase = items.isEmpty ? .idle : .loaded
            finishReload(operationID: operationID)
        } catch {
            guard
                activeReloadID == operationID,
                activeRequestKey == requestKey
            else {
                return
            }
            if items.isEmpty {
                phase = .failed(error.localizedDescription)
            } else {
                phase = .loaded
                refreshError = error.localizedDescription
            }
            finishReload(operationID: operationID)
        }
    }

    func loadMore(
        requestKey: String,
        loader: (URL) async throws -> PixivPage<Item>
    ) async {
        guard
            activeRequestKey == requestKey,
            completedRequestKey == requestKey,
            case .loaded = phase,
            !isRefreshing,
            !isLoadingMore,
            let initialURL = nextURL
        else {
            return
        }

        let operationID = UUID()
        activeLoadMoreID = operationID
        isLoadingMore = true
        loadMoreError = nil

        var requestedURL = initialURL
        var visitedURLs = Set<URL>()

        do {
            while visitedURLs.insert(requestedURL).inserted {
                let page = try await loader(requestedURL)
                guard
                    activeLoadMoreID == operationID,
                    activeRequestKey == requestKey,
                    nextURL == requestedURL
                else {
                    return
                }
                guard !Task.isCancelled else {
                    finishLoadMore(operationID: operationID)
                    return
                }

                let previousCount = items.count
                appendUnique(page.items)
                let followingURL = page.nextURL == requestedURL ? nil : page.nextURL
                nextURL = followingURL

                guard items.count == previousCount, let followingURL else {
                    finishLoadMore(operationID: operationID)
                    return
                }
                requestedURL = followingURL
            }
            nextURL = nil
            finishLoadMore(operationID: operationID)
        } catch is CancellationError {
            guard activeLoadMoreID == operationID else { return }
            finishLoadMore(operationID: operationID)
        } catch {
            guard
                activeLoadMoreID == operationID,
                activeRequestKey == requestKey
            else {
                return
            }
            loadMoreError = error.localizedDescription
            finishLoadMore(operationID: operationID)
        }
    }

    func item<ID: Hashable>(id: ID) -> Item? {
        let identifier = AnyHashable(id)
        return items.first { identity($0) == identifier }
    }

    func updateItem<ID: Hashable>(id: ID, update: (inout Item) -> Void) {
        let identifier = AnyHashable(id)
        guard let index = items.firstIndex(where: { identity($0) == identifier }) else { return }
        var updatedItems = items
        update(&updatedItems[index])
        items = updatedItems
    }

    func removeItem<ID: Hashable>(id: ID) {
        let identifier = AnyHashable(id)
        items.removeAll { identity($0) == identifier }
    }

    func clearRefreshError() {
        refreshError = nil
    }

    private func finishReload(operationID: UUID) {
        guard activeReloadID == operationID else { return }
        activeReloadRequestKey = nil
        isRefreshing = false
    }

    private func finishLoadMore(operationID: UUID) {
        guard activeLoadMoreID == operationID else { return }
        isLoadingMore = false
    }

    private func unique(_ values: [Item]) -> [Item] {
        var identifiers = Set<AnyHashable>()
        return values.filter { identifiers.insert(identity($0)).inserted }
    }

    private func appendUnique(_ values: [Item]) {
        var identifiers = Set(items.map(identity))
        items.append(contentsOf: values.filter { identifiers.insert(identity($0)).inserted })
    }
}

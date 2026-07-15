import Foundation
import Observation

@MainActor
@Observable
final class IllustrationSeriesStore {
    private(set) var detailState: LoadState<PixivIllustrationSeriesDetail> = .idle
    let works = PaginatedStore<PixivIllustration>(id: { $0.id })
    var actionError: String?

    @ObservationIgnored private var activeRequestKey: String?

    func loadIfNeeded(
        seriesID: Int,
        userID: Int?,
        repository: PixivRepository
    ) async {
        let key = requestKey(seriesID: seriesID, userID: userID)
        prepare(key: key)
        await works.loadIfNeeded(requestKey: key) { [weak self] in
            let result = try await repository.illustrationSeries(id: seriesID)
            guard let self, activeRequestKey == key, !Task.isCancelled else {
                throw CancellationError()
            }
            detailState = .loaded(result.detail)
            return result.page
        }
        synchronizeInitialError()
    }

    func refresh(
        seriesID: Int,
        userID: Int?,
        repository: PixivRepository
    ) async {
        let key = requestKey(seriesID: seriesID, userID: userID)
        prepare(key: key)
        await works.reload(requestKey: key, showsInitialLoading: false) { [weak self] in
            let result = try await repository.illustrationSeries(id: seriesID)
            guard let self, activeRequestKey == key, !Task.isCancelled else {
                throw CancellationError()
            }
            detailState = .loaded(result.detail)
            return result.page
        }
        synchronizeInitialError()
    }

    func retry(
        seriesID: Int,
        userID: Int?,
        repository: PixivRepository
    ) async {
        let key = requestKey(seriesID: seriesID, userID: userID)
        prepare(key: key)
        detailState = .loading
        await works.reload(requestKey: key, showsInitialLoading: true) { [weak self] in
            let result = try await repository.illustrationSeries(id: seriesID)
            guard let self, activeRequestKey == key, !Task.isCancelled else {
                throw CancellationError()
            }
            detailState = .loaded(result.detail)
            return result.page
        }
        synchronizeInitialError()
    }

    func loadMore(
        seriesID: Int,
        userID: Int?,
        repository: PixivRepository
    ) async {
        let key = requestKey(seriesID: seriesID, userID: userID)
        await works.loadMore(requestKey: key) { nextURL in
            try await repository.illustrationSeries(nextURL: nextURL)
        }
    }

    func toggleWatch(seriesID: Int, repository: PixivRepository) async {
        guard case .loaded(var detail) = detailState else { return }
        let newValue = !repository.seriesWatchState(
            seriesID: seriesID,
            fallback: detail.watchlistAdded
        )
        do {
            try await repository.setSeriesWatched(seriesID: seriesID, isWatching: newValue)
            detail.watchlistAdded = newValue
            detailState = .loaded(detail)
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    func toggleBookmark(id: Int, repository: PixivRepository) async {
        guard let illustration = works.item(id: id) else { return }
        do {
            let isBookmarked = try await repository.toggleBookmark(illustration)
            works.updateItem(id: id) { $0.isBookmarked = isBookmarked }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func prepare(key: String) {
        guard activeRequestKey != key else { return }
        activeRequestKey = key
        detailState = .loading
        actionError = nil
    }

    private func synchronizeInitialError() {
        guard case .loading = detailState,
              case let .failed(message) = works.phase else {
            return
        }
        detailState = .failed(message)
    }

    private func requestKey(seriesID: Int, userID: Int?) -> String {
        "\(seriesID)-\(userID ?? 0)"
    }
}

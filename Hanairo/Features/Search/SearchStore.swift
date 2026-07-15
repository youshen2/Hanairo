import Foundation
import Observation

enum SearchScope: String, CaseIterable, Identifiable {
    case illustrations
    case users

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrations: "作品"
        case .users: "用户"
        }
    }
}

struct SearchRequest: Hashable {
    let query: String
    let scope: SearchScope
    let options: PixivSearchOptions

    var key: String {
        [
            scope.rawValue,
            query,
            options.target.rawValue,
            options.sort.rawValue,
            options.mediaFilter.rawValue,
            String(options.aiFilter.rawValue),
            String(options.bookmarkThreshold.rawValue),
            String(options.usesDateRange),
            String(options.startDate.timeIntervalSinceReferenceDate),
            String(options.endDate.timeIntervalSinceReferenceDate)
        ].joined(separator: "|")
    }
}

@MainActor
@Observable
final class SearchStore {
    var query: String
    var scope: SearchScope = .illustrations
    var options: PixivSearchOptions {
        didSet { persistOptions() }
    }
    let illustrationResults = PaginatedStore<PixivIllustration>(id: { $0.id })
    let userResults = PaginatedStore<PixivUserPreview>(id: { $0.id })
    private(set) var trendingTags: [PixivTrendingTag] = []
    private(set) var suggestions: [PixivTag] = []
    private(set) var history: [String]
    private(set) var actionError: String?

    private let defaults: UserDefaults
    private static let historyKey = "search.history"
    private static let optionsKey = "search.options"

    init(initialQuery: String = "", defaults: UserDefaults = .standard) {
        query = initialQuery
        self.defaults = defaults
        history = defaults.stringArray(forKey: Self.historyKey) ?? []
        if
            let data = defaults.data(forKey: Self.optionsKey),
            let storedOptions = try? JSONDecoder().decode(PixivSearchOptions.self, from: data)
        {
            options = storedOptions
        } else {
            options = PixivSearchOptions()
        }
    }

    var request: SearchRequest {
        SearchRequest(query: normalizedQuery, scope: scope, options: options)
    }

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayedError: String? {
        actionError ?? activeRefreshError
    }

    func loadTrending(using repository: PixivRepository, force: Bool = false) async {
        guard force || trendingTags.isEmpty else { return }
        do {
            trendingTags = try await repository.trendingTags()
        } catch is CancellationError {
            return
        } catch {
            trendingTags = []
        }
    }

    func loadSuggestions(suggestionKey: String, using repository: PixivRepository) async {
        let term = normalizedQuery
        guard scope == .illustrations, !term.isEmpty else {
            suggestions = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard
            !Task.isCancelled,
            suggestionKey == suggestionRequestKey,
            term == normalizedQuery,
            scope == .illustrations
        else {
            return
        }
        do {
            let values = try await repository.searchAutocomplete(query: term)
            guard !Task.isCancelled, suggestionKey == suggestionRequestKey else { return }
            suggestions = Array(values.prefix(12))
        } catch is CancellationError {
            return
        } catch {
            suggestions = []
        }
    }

    var suggestionRequestKey: String {
        "\(scope.rawValue)|\(normalizedQuery)"
    }

    func searchIfNeeded(requestKey: String, using repository: PixivRepository) async {
        let term = normalizedQuery
        let activeScope = scope
        let activeOptions = options
        guard !term.isEmpty else { return }
        switch activeScope {
        case .illustrations:
            illustrationResults.prepare(for: requestKey)
        case .users:
            userResults.prepare(for: requestKey)
        }

        try? await Task.sleep(for: .milliseconds(400))
        guard
            !Task.isCancelled,
            term == normalizedQuery,
            activeScope == scope,
            activeOptions == options
        else {
            return
        }
        switch activeScope {
        case .illustrations:
            await illustrationResults.loadIfNeeded(requestKey: requestKey) {
                try await repository.searchIllustrations(query: term, options: activeOptions)
            }
        case .users:
            await userResults.loadIfNeeded(requestKey: requestKey) {
                try await repository.searchUsers(query: term)
            }
        }
        guard term == normalizedQuery, activeScope == scope, activeOptions == options else { return }
        let didLoad: Bool
        switch activeScope {
        case .illustrations:
            didLoad = illustrationResults.phase == .loaded
        case .users:
            didLoad = userResults.phase == .loaded
        }
        if didLoad {
            record(term)
        }
    }

    func retry(requestKey: String, using repository: PixivRepository) async {
        let term = normalizedQuery
        let activeScope = scope
        let activeOptions = options
        guard !term.isEmpty else { return }
        switch activeScope {
        case .illustrations:
            await illustrationResults.reload(requestKey: requestKey, showsInitialLoading: true) {
                try await repository.searchIllustrations(query: term, options: activeOptions)
            }
        case .users:
            await userResults.reload(requestKey: requestKey, showsInitialLoading: true) {
                try await repository.searchUsers(query: term)
            }
        }
    }

    func refresh(requestKey: String, using repository: PixivRepository) async {
        let term = normalizedQuery
        let activeScope = scope
        let activeOptions = options
        guard !term.isEmpty else {
            await loadTrending(using: repository, force: true)
            return
        }
        switch activeScope {
        case .illustrations:
            await illustrationResults.reload(requestKey: requestKey, showsInitialLoading: false) {
                try await repository.searchIllustrations(query: term, options: activeOptions)
            }
        case .users:
            await userResults.reload(requestKey: requestKey, showsInitialLoading: false) {
                try await repository.searchUsers(query: term)
            }
        }
    }

    func loadMore(requestKey: String, using repository: PixivRepository) async {
        let activeOptions = options
        switch scope {
        case .illustrations:
            await illustrationResults.loadMore(requestKey: requestKey) { nextURL in
                try await repository.searchIllustrations(nextURL: nextURL, options: activeOptions)
            }
        case .users:
            await userResults.loadMore(requestKey: requestKey) { nextURL in
                try await repository.users(nextURL: nextURL)
            }
        }
    }

    func toggleBookmark(id: Int, using repository: PixivRepository) async {
        guard let illustration = illustrationResults.item(id: id) else { return }
        do {
            let isBookmarked = try await repository.toggleBookmark(illustration)
            illustrationResults.updateItem(id: id) { $0.isBookmarked = isBookmarked }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    func removeHistory(_ term: String) {
        history.removeAll { $0 == term }
        defaults.set(history, forKey: Self.historyKey)
    }

    func clearHistory() {
        history = []
        defaults.removeObject(forKey: Self.historyKey)
    }

    func resetOptions() {
        options = PixivSearchOptions()
    }

    func clearDisplayedError() {
        actionError = nil
        illustrationResults.clearRefreshError()
        userResults.clearRefreshError()
    }

    private func record(_ term: String) {
        history.removeAll { $0 == term }
        history.insert(term, at: 0)
        history = Array(history.prefix(8))
        defaults.set(history, forKey: Self.historyKey)
    }

    private func persistOptions() {
        guard let data = try? JSONEncoder().encode(options) else { return }
        defaults.set(data, forKey: Self.optionsKey)
    }

    private var activeRefreshError: String? {
        switch scope {
        case .illustrations: illustrationResults.refreshError
        case .users: userResults.refreshError
        }
    }

}

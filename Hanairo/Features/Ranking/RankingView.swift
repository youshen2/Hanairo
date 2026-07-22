import SwiftUI
#if os(iOS)
import UIKit
#endif

struct RankingView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(AppSettings.self) private var settings

    @State private var mode: RankingMode = .daily
    @State private var selectedDate = Date()
    @State private var usesCustomDate = false
    @State private var feed = PaginatedStore<PixivIllustration>(id: { $0.id })
    @State private var actionError: String?

    var body: some View {
        GeometryReader { geometry in
            let usesExpandedFilters = prefersExpandedFilters
            let usesFourColumns = usesFourColumnLayout(for: geometry.size.width)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if usesExpandedFilters {
                        wideFilterPanel
                    } else {
                        compactFilters
                    }

                    content(columnCount: usesFourColumns ? 4 : nil)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .refreshable {
                await refresh()
            }
        }
        .navigationTitle("排行榜")
        .task(id: requestKey) {
            await loadIfNeeded()
        }
        .onChange(of: settings.showsMatureArtwork) { _, showsMatureArtwork in
            if !showsMatureArtwork, mode.isMature {
                mode = .daily
            }
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(displayedError ?? "未知错误")
        }
    }

    private var compactFilters: some View {
        Group {
            HStack(spacing: 12) {
                Menu {
                    rankingModePicker
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                        .font(.headline)
                }
                .buttonStyle(.bordered)

                Spacer()

                if mode.isMature {
                    matureBadge
                }
            }

            Text(mode.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DisclosureGroup("指定日期", isExpanded: $usesCustomDate) {
                DatePicker(
                    "排行日期",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .padding(.top, 8)
            }
        }
    }

    private var wideFilterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Menu {
                    rankingModePicker
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: mode.systemImage)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("排行类型")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(mode.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(
                        .background.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Toggle(isOn: $usesCustomDate) {
                    Label("指定日期", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)

                if usesCustomDate {
                    DatePicker(
                        "排行日期",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .fixedSize()
                }

                Spacer(minLength: 0)

                if mode.isMature {
                    matureBadge
                }
            }

            Divider()

            Text(mode.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.primary.opacity(0.06))
        }
    }

    private var rankingModePicker: some View {
        Picker("排行榜", selection: $mode) {
            ForEach(availableModes) { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
    }

    private var matureBadge: some View {
        Text("R-18")
            .font(.caption.bold())
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.red.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func content(columnCount: Int?) -> some View {
        switch feed.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if feed.items.isEmpty {
                ContentUnavailableView("暂无排行数据", systemImage: "trophy")
                    .frame(minHeight: 360)
            } else {
                ArtworkMasonryGrid(
                    illustrations: feed.items,
                    showsRanking: true,
                    columnCount: columnCount,
                    onLoadMore: loadMore
                ) { id in
                    await toggleBookmark(id: id)
                }
                PaginationStatusView(
                    isLoading: feed.isLoadingMore,
                    errorMessage: feed.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    private var requestKey: String {
        "\(mode.rawValue)-\(usesCustomDate)-\(selectedDate.timeIntervalSinceReferenceDate)-\(authentication.userID ?? 0)"
    }

    private var availableModes: [RankingMode] {
        RankingMode.allCases.filter { settings.showsMatureArtwork || !$0.isMature }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { displayedError != nil },
            set: {
                if !$0 {
                    actionError = nil
                    feed.clearRefreshError()
                }
            }
        )
    }

    private var displayedError: String? {
        actionError ?? feed.refreshError
    }

    private func loadIfNeeded() async {
        let activeRequestKey = requestKey
        let activeMode = mode.rawValue
        let activeDate = usesCustomDate ? selectedDate : nil
        await feed.loadIfNeeded(requestKey: activeRequestKey) {
            try await repository.ranking(mode: activeMode, date: activeDate)
        }
    }

    private func refresh() async {
        let activeRequestKey = requestKey
        let activeMode = mode.rawValue
        let activeDate = usesCustomDate ? selectedDate : nil
        await feed.reload(requestKey: activeRequestKey, showsInitialLoading: false) {
            try await repository.ranking(mode: activeMode, date: activeDate)
        }
    }

    private func retry() async {
        let activeRequestKey = requestKey
        let activeMode = mode.rawValue
        let activeDate = usesCustomDate ? selectedDate : nil
        await feed.reload(requestKey: activeRequestKey, showsInitialLoading: true) {
            try await repository.ranking(mode: activeMode, date: activeDate)
        }
    }

    private func loadMore() async {
        let activeRequestKey = requestKey
        await feed.loadMore(requestKey: activeRequestKey) { nextURL in
            try await repository.illustrations(nextURL: nextURL)
        }
    }

    private func toggleBookmark(id: Int) async {
        guard let illustration = feed.item(id: id) else { return }
        do {
            let isBookmarked = try await repository.toggleBookmark(illustration)
            feed.updateItem(id: id) { $0.isBookmarked = isBookmarked }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    private var prefersExpandedFilters: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone
#else
        true
#endif
    }

    private func usesFourColumnLayout(for width: CGFloat) -> Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone && width >= 700
#else
        width >= 900
#endif
    }
}

private enum RankingMode: String, CaseIterable, Identifiable {
    case daily = "day"
    case male = "day_male"
    case female = "day_female"
    case original = "week_original"
    case rookie = "week_rookie"
    case weekly = "week"
    case monthly = "month"
    case ai = "day_ai"
    case matureAI = "day_r18_ai"
    case matureDaily = "day_r18"
    case matureWeekly = "week_r18"
    case matureG = "week_r18g"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "日榜"
        case .male: "男性热门"
        case .female: "女性热门"
        case .original: "原创榜"
        case .rookie: "新人榜"
        case .weekly: "周榜"
        case .monthly: "月榜"
        case .ai: "AI 日榜"
        case .matureAI: "AI R-18 日榜"
        case .matureDaily: "R-18 日榜"
        case .matureWeekly: "R-18 周榜"
        case .matureG: "R-18G 周榜"
        }
    }

    var description: String {
        switch self {
        case .daily: "Pixiv 全站每日综合排名"
        case .male: "男性用户关注度较高的每日作品"
        case .female: "女性用户关注度较高的每日作品"
        case .original: "最近一周的原创作品排名"
        case .rookie: "最近一周的新锐作者作品排名"
        case .weekly: "最近一周的综合排名"
        case .monthly: "最近一个月的综合排名"
        case .ai: "AI 生成作品每日排名"
        case .matureAI: "成人向 AI 生成作品每日排名"
        case .matureDaily: "成人向作品每日排名"
        case .matureWeekly: "成人向作品每周排名"
        case .matureG: "高限制级作品每周排名"
        }
    }

    var systemImage: String {
        switch self {
        case .original: "paintbrush"
        case .rookie: "leaf"
        case .ai, .matureAI: "wand.and.stars"
        case .male, .female: "person.2"
        default: "trophy"
        }
    }

    var isMature: Bool {
        switch self {
        case .matureAI, .matureDaily, .matureWeekly, .matureG: true
        default: false
        }
    }
}

#Preview("排行榜预览") {
    NavigationStack {
        RankingView()
    }
    .withPreviewDependencies()
}

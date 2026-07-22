import SwiftUI
import UniformTypeIdentifiers

struct IllustrationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(ImageRepository.self) private var imageRepository
    @Environment(AppSettings.self) private var settings
    @Environment(ArtworkDownloadManager.self) private var downloadManager
    @Environment(BrowsingHistoryStore.self) private var browsingHistory
    @Environment(AppTheme.self) private var theme

    let illustrationID: Int

    @State private var state: LoadState<PixivIllustration> = .idle
    @State private var related = PaginatedStore<PixivIllustration>(id: { $0.id })
    @State private var isChangingBookmark = false
    @State private var actionError: String?
    @State private var actionNotice: String?
    @State private var commentSheet: CommentSheetContext?
    @State private var bookmarkEditor: PixivIllustration?
    @State private var blockEditor: PixivIllustration?
    @State private var informationArtwork: PixivIllustration?
    @State private var didRecordHistory = false
    @State private var artworkAccentColor: Color?
    @State private var isPreparingExport = false
    @State private var preparedExport: PreparedArtworkExport?
    @State private var isFileExporterPresented = false

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )
    }

    private var actionNoticeBinding: Binding<Bool> {
        Binding(
            get: { actionNotice != nil },
            set: { if !$0 { actionNotice = nil } }
        )
    }

    private var requestKey: String {
        "\(illustrationID)-\(authentication.userID ?? 0)"
    }

    private var exportContentTypes: [UTType] {
        preparedExport.map { [$0.format.contentType] }
            ?? ArtworkExportDocument.writableContentTypes
    }

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView("正在加载作品…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                ErrorStateView(message: message) {
                    Task { await load() }
                }
            case let .loaded(illustration):
                detailContent(illustration)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .tint(artworkAccentColor ?? theme.accentColor)
        .toolbar {
            if case let .loaded(illustration) = state {
                ArtworkToolbarActions(
                    isBookmarked: repository.bookmarkState(for: illustration),
                    isChangingBookmark: isChangingBookmark,
                    isPreparingExport: isPreparingExport,
                    pageCount: illustration.originalPageURLs.count,
                    shareURL: PixivWebLinks.artwork(id: illustration.id),
                    onBookmark: startBookmarkToggle,
                    onDownloadAll: {
                        enqueueDownload(
                            pageIndices: Array(illustration.originalPageURLs.indices),
                            illustration: illustration
                        )
                    },
                    onExportZIP: {
                        startExport(.zip, illustration: illustration)
                    },
                    onExportPDF: {
                        startExport(.pdf, illustration: illustration)
                    }
                )

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("作品信息", systemImage: "info.circle") {
                            informationArtwork = illustration
                        }
                        Button("编辑收藏", systemImage: "tag") {
                            bookmarkEditor = illustration
                        }
                        Link(destination: PixivWebLinks.artwork(id: illustration.id)) {
                            Label("在 Pixiv 打开", systemImage: "safari")
                        }
                        if
                            let imageURL = illustration.originalPageURLs.compactMap({ $0 }).first,
                            let sauceURL = PixivWebLinks.sauceNAO(imageURL: imageURL)
                        {
                            Link(destination: sauceURL) {
                                Label("使用 SauceNAO 搜图", systemImage: "photo.badge.magnifyingglass")
                            }
                        }
                        Divider()
                        Button("本地屏蔽…", systemImage: "hand.raised") {
                            blockEditor = illustration
                        }
                        Link(destination: PixivWebLinks.artwork(id: illustration.id)) {
                            Label("前往 Pixiv 举报", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多操作")
                }
            }
        }
        .task(id: requestKey) {
            await load()
        }
        .task(id: requestKey) {
            await loadRelatedIfNeeded()
        }
        .task(id: artworkThemeImageURL) {
            await updateArtworkAccent()
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(actionError ?? "未知错误")
        }
        .alert("下载任务", isPresented: actionNoticeBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(actionNotice ?? "图片已保存")
        }
        .sheet(item: $commentSheet, onDismiss: refreshDetailAfterComments) { context in
            IllustrationCommentsSheet(
                illustrationID: context.illustrationID,
                allowsPosting: context.allowsPosting
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $bookmarkEditor) { illustration in
            BookmarkEditorSheet(illustration: illustration) { isBookmarked in
                updateBookmarkState(isBookmarked)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $blockEditor) { illustration in
            LocalBlockActionsSheet(illustration: illustration) { _ in
                dismiss()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $informationArtwork) { illustration in
            ArtworkInformationSheet(illustration: illustration)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: preparedExport?.document,
            contentTypes: exportContentTypes,
            onCompletion: handleExportCompletion,
            onCancellation: discardPreparedExport
        )
        .fileDialogBrowserOptions(.displayFileExtensions)
    }

    private func detailContent(_ illustration: PixivIllustration) -> some View {
        let displayURLs = illustration.pageURLs(for: settings.imageQuality)
        let fullSizeURLs = illustration.originalPageURLs

        return ArtworkParallaxDetailLayout(
            illustration: illustration,
            displayURLs: displayURLs,
            fullSizeURLs: fullSizeURLs,
            isParallaxEnabled: settings.artworkParallaxEnabled
        ) {
            IllustrationMetadataView(illustration: illustration) {
                commentSheet = CommentSheetContext(
                    illustrationID: illustration.id,
                    allowsPosting: illustration.commentAccessControl == 0
                )
            }
        } footer: {
            RelatedArtworkSection(
                store: related,
                onRetry: retryRelated,
                onLoadMore: loadMoreRelated,
                onBookmark: toggleRelatedBookmark
            )
        }
    }

    private var navigationTitle: String {
        if case .loaded = state {
            return ""
        }
        return "作品详情"
    }

    private var artworkThemeImageURL: URL? {
        guard case let .loaded(illustration) = state else { return nil }
        return illustration.previewURL
    }

    private func updateArtworkAccent() async {
        let activeURL = artworkThemeImageURL
        guard let activeURL else {
            artworkAccentColor = nil
            return
        }
        let color = await theme.accentColor(for: activeURL)
        guard !Task.isCancelled, activeURL == artworkThemeImageURL else { return }
        artworkAccentColor = color
    }

    private func startBookmarkToggle() {
        Task { await toggleBookmark() }
    }

    private func updateBookmarkState(_ isBookmarked: Bool) {
        guard case .loaded(var illustration) = state else { return }
        illustration.isBookmarked = isBookmarked
        state = .loaded(illustration)
        browsingHistory.updateBookmark(id: illustration.id, isBookmarked: isBookmarked)
    }

    private func enqueueDownload(pageIndices: [Int], illustration: PixivIllustration) {
        actionNotice = downloadManager.enqueue(
            illustration: illustration,
            pageIndices: pageIndices
        ).message
    }

    private func startExport(
        _ format: ArtworkExportFormat,
        illustration: PixivIllustration
    ) {
        guard !isPreparingExport else { return }
        discardPreparedExport()
        isPreparingExport = true
        Task {
            defer { isPreparingExport = false }
            do {
                let export = try await ArtworkExportService.prepare(
                    illustration: illustration,
                    format: format,
                    imageRepository: imageRepository,
                    onProgress: { _, _ in }
                )
                guard !Task.isCancelled else {
                    ArtworkExportService.removeTemporaryFile(for: export)
                    return
                }
                downloadManager.applyAutomaticBookmark(to: illustration)
                preparedExport = export
                isFileExporterPresented = true
            } catch is CancellationError {
                return
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func handleExportCompletion(_ result: Result<URL, any Error>) {
        if case let .failure(error) = result {
            actionError = error.localizedDescription
        }
        discardPreparedExport()
    }

    private func discardPreparedExport() {
        let export = preparedExport
        isFileExporterPresented = false
        guard let export else { return }
        Task { @MainActor in
            await Task.yield()
            ArtworkExportService.removeTemporaryFile(for: export)
            guard preparedExport?.fileURL == export.fileURL else { return }
            preparedExport = nil
        }
    }

    private func load() async {
        let cachedIllustration = await repository.cachedIllustration(id: illustrationID)
        if let cachedIllustration {
            state = .loaded(cachedIllustration)
            recordHistoryIfNeeded(cachedIllustration)
        } else {
            state = .loading
        }

        do {
            let illustration = try await repository.refreshIllustration(id: illustrationID)
            state = .loaded(illustration)
            recordHistoryIfNeeded(illustration)
        } catch is CancellationError {
            return
        } catch {
            if cachedIllustration == nil {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func recordHistoryIfNeeded(_ illustration: PixivIllustration) {
        guard !didRecordHistory else { return }
        didRecordHistory = true
        browsingHistory.record(illustration)
    }

    private func toggleBookmark() async {
        guard case .loaded(var illustration) = state else { return }
        isChangingBookmark = true
        defer { isChangingBookmark = false }
        do {
            illustration.isBookmarked = try await repository.toggleBookmark(illustration)
            state = .loaded(illustration)
            browsingHistory.updateBookmark(
                id: illustration.id,
                isBookmarked: illustration.isBookmarked
            )
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func toggleRelatedBookmark(id: Int) async {
        guard let illustration = related.item(id: id) else { return }
        do {
            let isBookmarked = try await repository.toggleBookmark(illustration)
            related.updateItem(id: id) { $0.isBookmarked = isBookmarked }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func loadRelatedIfNeeded() async {
        let activeRequestKey = requestKey
        let activeIllustrationID = illustrationID
        await related.loadIfNeeded(requestKey: activeRequestKey) {
            try await repository.related(to: activeIllustrationID)
        }
    }

    private func retryRelated() async {
        let activeRequestKey = requestKey
        let activeIllustrationID = illustrationID
        await related.reload(requestKey: activeRequestKey, showsInitialLoading: true) {
            try await repository.related(to: activeIllustrationID)
        }
    }

    private func loadMoreRelated() async {
        let activeRequestKey = requestKey
        await related.loadMore(requestKey: activeRequestKey) { nextURL in
            try await repository.illustrations(nextURL: nextURL)
        }
    }

    private func refreshDetailAfterComments() {
        Task {
            guard let illustration = try? await repository.refreshIllustration(id: illustrationID) else {
                return
            }
            state = .loaded(illustration)
        }
    }
}

private struct CommentSheetContext: Identifiable {
    let illustrationID: Int
    let allowsPosting: Bool

    var id: Int { illustrationID }
}

private struct RelatedArtworkSection: View {
    @Environment(\.artworkRelatedFlowConfiguration) private var flowConfiguration
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(LocalBlockStore.self) private var localBlocks

    let store: PaginatedStore<PixivIllustration>
    let onRetry: () async -> Void
    let onLoadMore: () async -> Void
    let onBookmark: (Int) async -> Void

    @State private var flowingSidebarHeight: CGFloat = 0

    @ViewBuilder
    var body: some View {
        if store.phase != .loaded || !store.items.isEmpty {
            if let flowConfiguration {
                flowingContent(configuration: flowConfiguration)
            } else {
                standardContent
            }
        }
    }

    @ViewBuilder
    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            phaseContent(illustrations: store.items, onLoadMore: onLoadMore)
        }
    }

    @ViewBuilder
    private func flowingContent(
        configuration: ArtworkRelatedFlowConfiguration
    ) -> some View {
        switch store.phase {
        case .idle, .loading, .failed:
            standardContent
                .environment(\.horizontalSizeClass, .compact)
                .frame(width: configuration.sidebarWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
        case .loaded:
            let splitIndex = sidebarItemCount(for: configuration)
            let sidebarItems = Array(visibleIllustrations.prefix(splitIndex))
            let fullWidthItems = Array(visibleIllustrations.dropFirst(splitIndex))

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if !sidebarItems.isEmpty {
                        sidebarArtworkGrid(
                            illustrations: sidebarItems,
                            loadsMore: fullWidthItems.isEmpty
                        )
                    }
                }
                .frame(width: configuration.sidebarWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { newHeight in
                    guard abs(flowingSidebarHeight - newHeight) > 0.5 else { return }
                    flowingSidebarHeight = newHeight
                }

                if !fullWidthItems.isEmpty {
                    Color.clear
                        .frame(
                            height: max(
                                configuration.availableSidebarHeight
                                    - flowingSidebarHeight,
                                0
                            )
                        )

                    ArtworkMasonryGrid(
                        illustrations: fullWidthItems,
                        columnCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4,
                        onLoadMore: onLoadMore,
                        onBookmark: onBookmark
                    )
                    .padding(.top, 24)
                }

                PaginationStatusView(
                    isLoading: store.isLoadingMore,
                    errorMessage: store.loadMoreError,
                    onRetry: onLoadMore
                )
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }

    @ViewBuilder
    private func sidebarArtworkGrid(
        illustrations: [PixivIllustration],
        loadsMore: Bool
    ) -> some View {
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 2

        if loadsMore {
            ArtworkMasonryGrid(
                illustrations: illustrations,
                columnCount: columnCount,
                onLoadMore: onLoadMore,
                onBookmark: onBookmark
            )
        } else {
            ArtworkMasonryGrid(
                illustrations: illustrations,
                columnCount: columnCount,
                onLoadMore: nil,
                onBookmark: onBookmark
            )
        }
    }

    private var header: some View {
        HStack {
            Text("相关作品")
                .font(.title2.weight(.bold))
            Spacer()
            if !store.items.isEmpty {
                Text(store.items.count, format: .number)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func phaseContent(
        illustrations: [PixivIllustration],
        onLoadMore: (() async -> Void)?
    ) -> some View {
        switch store.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await onRetry() }
            }
            .frame(minHeight: 220)
        case .loaded:
            ArtworkGrid(
                illustrations: illustrations,
                onLoadMore: onLoadMore,
                onBookmark: onBookmark
            )
            PaginationStatusView(
                isLoading: store.isLoadingMore,
                errorMessage: store.loadMoreError,
                onRetry: self.onLoadMore
            )
        }
    }

    private var visibleIllustrations: [PixivIllustration] {
        store.items.filter { !localBlocks.isBlocked($0) }
    }

    private func sidebarItemCount(
        for configuration: ArtworkRelatedFlowConfiguration
    ) -> Int {
        let spacing: CGFloat = 12
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let availableGridHeight = max(
            configuration.availableSidebarHeight - 50,
            0
        )
        guard availableGridHeight > 0 else { return 0 }

        let totalSpacing = spacing * CGFloat(columnCount - 1)
        let cardWidth = max(
            (configuration.sidebarWidth - totalSpacing) / CGFloat(columnCount),
            1
        )
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var count = 0

        for illustration in visibleIllustrations {
            let targetColumn = columnHeights.indices.min {
                columnHeights[$0] < columnHeights[$1]
            } ?? 0
            let itemSpacing = columnHeights[targetColumn] == 0 ? 0 : spacing
            let aspectRatio = illustration.aspectRatio > 0
                ? illustration.aspectRatio
                : 0.75
            let estimatedHeight = cardWidth * (1 / aspectRatio + 0.34)
            let nextHeight = columnHeights[targetColumn]
                + itemSpacing
                + estimatedHeight

            guard nextHeight <= availableGridHeight else { break }

            columnHeights[targetColumn] = nextHeight
            count += 1
        }

        return count
    }
}

#Preview("作品详情") {
    NavigationStack {
        IllustrationDetailView(illustrationID: 1004)
    }
    .withPreviewDependencies()
}

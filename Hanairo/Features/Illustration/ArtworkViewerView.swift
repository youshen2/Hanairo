import SwiftUI

struct ArtworkViewerView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let urls: [URL?]
    let onDownload: ((Int) async -> String)?

    @State private var selectedPage: Int
    @State private var showsChrome = true
    @State private var isCurrentPageZoomed = false
    @State private var zoomResetToken = 0
    @State private var downloadNotice: String?
    @State private var isPreparingDownload = false

    init(
        title: String,
        urls: [URL?],
        initialPage: Int,
        onDownload: ((Int) async -> String)? = nil
    ) {
        self.title = title
        self.urls = urls.isEmpty ? [nil] : urls
        self.onDownload = onDownload
        _selectedPage = State(initialValue: min(max(initialPage, 0), max(urls.count - 1, 0)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                pages

                if showsChrome {
                    ArtworkViewerChrome(
                        currentPage: selectedPage,
                        pageCount: urls.count,
                        isZoomed: isCurrentPageZoomed,
                        onSelectPage: selectPage
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .navigationTitle(title.isEmpty ? "查看大图" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("关闭大图")
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if let onDownload {
                        Button {
                            let page = selectedPage
                            isPreparingDownload = true
                            Task {
                                downloadNotice = await onDownload(page)
                                isPreparingDownload = false
                            }
                        } label: {
                            if isPreparingDownload {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.to.line")
                            }
                        }
                        .disabled(urls[selectedPage] == nil || isPreparingDownload)
                        .accessibilityLabel(isPreparingDownload ? "正在准备下载" : "下载当前图片")
                    }
                    shareAction
                }
            }
            .toolbar(showsChrome ? .visible : .hidden, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .background(Color.black)
        .presentationBackground(.black)
        .environment(\.colorScheme, .dark)
        .alert("下载任务", isPresented: downloadNoticeBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(downloadNotice ?? "未知状态")
        }
        .onChange(of: selectedPage) {
            isCurrentPageZoomed = false
            zoomResetToken += 1
        }
        .animation(.easeOut(duration: 0.18), value: showsChrome)
    }

    @ViewBuilder
    private var shareAction: some View {
        if let currentURL = urls[selectedPage] {
            ShareLink(item: currentURL) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享当前图片")
        } else {
            Button("图片不可用", systemImage: "square.and.arrow.up") {}
                .labelStyle(.iconOnly)
                .disabled(true)
        }
    }

    private var pages: some View {
        TabView(selection: $selectedPage) {
            ForEach(urls.indices, id: \.self) { page in
                ZoomableMediaView(
                    resetToken: zoomResetToken,
                    onSingleTap: toggleChrome,
                    onZoomChange: { isZoomed in
                        guard page == selectedPage else { return }
                        isCurrentPageZoomed = isZoomed
                        if isZoomed {
                            showsChrome = false
                        }
                    }
                ) {
                    RemoteImageView(url: urls[page], contentMode: .fit)
                }
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .scrollDisabled(isCurrentPageZoomed)
    }

    private var downloadNoticeBinding: Binding<Bool> {
        Binding(
            get: { downloadNotice != nil },
            set: { if !$0 { downloadNotice = nil } }
        )
    }

    private func toggleChrome() {
        withAnimation(.easeOut(duration: 0.18)) {
            showsChrome.toggle()
        }
    }

    private func selectPage(_ page: Int) {
        guard urls.indices.contains(page), page != selectedPage else { return }
        withAnimation(.snappy(duration: 0.25)) {
            selectedPage = page
        }
    }
}

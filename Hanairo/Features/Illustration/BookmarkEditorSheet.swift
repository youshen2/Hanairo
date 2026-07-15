import SwiftUI

struct BookmarkEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PixivRepository.self) private var repository

    let illustration: PixivIllustration
    let onSaved: (Bool) -> Void

    @State private var phase: LoadState<PixivBookmarkDetail> = .idle
    @State private var visibility: PixivVisibility = .public
    @State private var tags: [PixivBookmarkDetailTag] = []
    @State private var selectedTags = Set<String>()
    @State private var newTag = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("编辑收藏")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { save() }
                            .disabled(!isLoaded || isSaving)
                    }
                }
        }
        .interactiveDismissDisabled(isSaving)
        .task(id: illustration.id) {
            await load()
        }
        .alert("操作失败", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            ProgressView("正在加载收藏信息…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await load() }
            }
        case let .loaded(detail):
            Form {
                Section("可见范围") {
                    Picker("收藏范围", selection: $visibility) {
                        ForEach(PixivVisibility.allCases) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        TextField("新增标签", text: $newTag)
                            .submitLabel(.done)
                            .onSubmit(addTag)
                        Button("添加", action: addTag)
                            .disabled(normalizedNewTag.isEmpty)
                    }
                } header: {
                    HStack {
                        Text("标签")
                        Spacer()
                        Button(selectedTags.count == tags.count ? "取消全选" : "全选") {
                            toggleAllTags()
                        }
                        .textCase(nil)
                    }
                }

                Section {
                    if tags.isEmpty {
                        ContentUnavailableView("暂无标签", systemImage: "tag")
                    } else {
                        ForEach(tags, id: \.name) { tag in
                            Button {
                                toggleTag(tag.name)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTags.contains(tag.name) {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text("已选择 \(selectedTags.count) 个标签")
                }

                if detail.isBookmarked {
                    Section {
                        Button("取消收藏", role: .destructive) {
                            removeBookmark()
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
    }

    private var isLoaded: Bool {
        if case .loaded = phase { return true }
        return false
    }

    private var normalizedNewTag: String {
        newTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func load() async {
        phase = .loading
        do {
            let detail = try await repository.bookmarkDetail(id: illustration.id)
            guard !Task.isCancelled else { return }
            visibility = detail.visibility
            tags = uniqueTags(detail.tags)
            selectedTags = Set(detail.tags.filter(\.isRegistered).map(\.name))
            phase = .loaded(detail)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func addTag() {
        let value = normalizedNewTag
        guard !value.isEmpty else { return }
        if !tags.contains(where: { $0.name == value }) {
            tags.insert(PixivBookmarkDetailTag(name: value, isRegistered: true), at: 0)
        }
        selectedTags.insert(value)
        newTag = ""
    }

    private func toggleTag(_ name: String) {
        if selectedTags.contains(name) {
            selectedTags.remove(name)
        } else {
            selectedTags.insert(name)
        }
    }

    private func toggleAllTags() {
        if selectedTags.count == tags.count {
            selectedTags.removeAll()
        } else {
            selectedTags = Set(tags.map(\.name))
        }
    }

    private func save() {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try await repository.updateBookmark(
                    id: illustration.id,
                    visibility: visibility,
                    tags: selectedTags.sorted()
                )
                onSaved(true)
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeBookmark() {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try await repository.removeBookmark(id: illustration.id)
                onSaved(false)
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func uniqueTags(_ values: [PixivBookmarkDetailTag]) -> [PixivBookmarkDetailTag] {
        var names = Set<String>()
        return values.filter { names.insert($0.name).inserted }
    }
}

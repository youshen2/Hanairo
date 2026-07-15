import SwiftUI

struct SearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    let isPremium: Bool
    let onApply: (PixivSearchOptions) -> Void

    @State private var draft: PixivSearchOptions

    init(
        options: PixivSearchOptions,
        isPremium: Bool,
        onApply: @escaping (PixivSearchOptions) -> Void
    ) {
        _draft = State(initialValue: options)
        self.isPremium = isPremium
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("匹配") {
                    Picker("搜索范围", selection: $draft.target) {
                        ForEach(PixivSearchTarget.allCases) { target in
                            Text(target.title).tag(target)
                        }
                    }
                    Picker("作品类型", selection: $draft.mediaFilter) {
                        ForEach(PixivSearchMediaFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    Picker("AI 作品", selection: $draft.aiFilter) {
                        ForEach(PixivSearchAIFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                }

                Section {
                    Picker("排序", selection: $draft.sort) {
                        ForEach(availableSorts) { sort in
                            Text(sortTitle(sort)).tag(sort)
                        }
                    }
                    Picker("收藏数", selection: $draft.bookmarkThreshold) {
                        ForEach(PixivBookmarkThreshold.allCases) { threshold in
                            Text(threshold.title).tag(threshold)
                        }
                    }
                } header: {
                    Text("排序与热度")
                } footer: {
                    if !isPremium {
                        Text("非高级会员选择热门优先时使用 Pixiv 的热门预览结果。按用户性别排序仅对高级会员开放。")
                    }
                }

                Section("发布日期") {
                    Toggle("限定日期范围", isOn: $draft.usesDateRange)
                    if draft.usesDateRange {
                        DatePicker(
                            "开始日期",
                            selection: $draft.startDate,
                            in: ...draft.endDate,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "结束日期",
                            selection: $draft.endDate,
                            in: draft.startDate...Date(),
                            displayedComponents: .date
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("搜索筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("重置") { draft = PixivSearchOptions() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        onApply(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var availableSorts: [PixivSearchSort] {
        if isPremium {
            return PixivSearchSort.allCases
        }
        return [.newest, .oldest, .popular]
    }

    private func sortTitle(_ sort: PixivSearchSort) -> String {
        if !isPremium, sort == .popular {
            return "热门预览"
        }
        return sort.title
    }
}

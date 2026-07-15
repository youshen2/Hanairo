import SwiftUI

struct MasonryGrid<Item: Identifiable, Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let items: [Item]
    var spacing: CGFloat = 12
    let estimatedHeight: (Item) -> CGFloat
    let content: (Item) -> Content

    init(
        items: [Item],
        spacing: CGFloat = 12,
        estimatedHeight: @escaping (Item) -> CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.estimatedHeight = estimatedHeight
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                LazyVStack(spacing: spacing) {
                    ForEach(column) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize {
            return 1
        }
        return horizontalSizeClass == .compact ? 2 : 3
    }

    private var columns: [[Item]] {
        var result = Array(repeating: [Item](), count: columnCount)
        var heights = Array(repeating: CGFloat.zero, count: columnCount)

        for item in items {
            let targetColumn = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            result[targetColumn].append(item)
            heights[targetColumn] += max(estimatedHeight(item), 0)
        }
        return result
    }
}

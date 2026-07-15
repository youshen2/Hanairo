import SwiftUI

struct PixivCommentText: View {
    let content: String
    var font: Font = .body

    var body: some View {
        Text(PixivCommentTextFormatter.displayText(from: content))
            .font(font)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

private enum PixivCommentTextFormatter {
    private static let emojiReplacements = [
        "(normal)": "🙂",
        "(surprise)": "😮",
        "(serious)": "😐",
        "(heaven)": "😇",
        "(happy)": "😊",
        "(excited)": "🤩",
        "(sing)": "🎶",
        "(cry)": "😢",
        "(normal2)": "🙂",
        "(shame2)": "😳",
        "(love2)": "😍",
        "(interesting2)": "🤔",
        "(blush2)": "😊",
        "(fire2)": "🔥",
        "(angry2)": "😠",
        "(shine2)": "✨",
        "(panic2)": "😱",
        "(normal3)": "🙂",
        "(satisfaction3)": "😌",
        "(surprise3)": "😮",
        "(smile3)": "😄",
        "(shock3)": "😨",
        "(gaze3)": "👀",
        "(wink3)": "😉",
        "(happy3)": "😊",
        "(excited3)": "🤩",
        "(love3)": "😍",
        "(normal4)": "🙂",
        "(surprise4)": "😮",
        "(serious4)": "😐",
        "(love4)": "😍",
        "(shine4)": "✨",
        "(sweat4)": "😅",
        "(shame4)": "😳",
        "(sleep4)": "😴",
        "(heart)": "❤️",
        "(teardrop)": "💧",
        "(star)": "⭐️"
    ]

    static func displayText(from content: String) -> String {
        emojiReplacements.reduce(content) { result, replacement in
            result.replacingOccurrences(of: replacement.key, with: replacement.value)
        }
    }
}

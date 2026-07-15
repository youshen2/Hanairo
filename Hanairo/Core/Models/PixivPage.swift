import Foundation

struct PixivPage<Element: Sendable>: Sendable {
    let items: [Element]
    let nextURL: URL?
}

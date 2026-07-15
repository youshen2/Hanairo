import Foundation
import Observation

@MainActor
@Observable
final class LocalBlockStore {
    private(set) var users: [LocalBlockedUser]
    private(set) var artworks: [LocalBlockedArtwork]
    private(set) var tags: [LocalBlockedTag]
    private(set) var comments: [LocalBlockedComment]

    private let defaults: UserDefaults
    private static let archiveKey = "localBlocks.archive"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: Self.archiveKey),
            let archive = try? JSONDecoder().decode(LocalBlockArchive.self, from: data)
        {
            users = archive.users
            artworks = archive.artworks
            tags = archive.tags
            comments = archive.comments
        } else {
            users = []
            artworks = []
            tags = []
            comments = []
        }
        sortEntries()
    }

    var totalCount: Int { users.count + artworks.count + tags.count + comments.count }

    func isBlocked(_ illustration: PixivIllustration) -> Bool {
        artworks.contains { $0.id == illustration.id }
            || users.contains { $0.id == illustration.user.id }
            || illustration.tags.contains { isTagBlocked($0.name) }
    }

    func isBlocked(_ user: PixivUser) -> Bool {
        users.contains { $0.id == user.id }
    }

    func isBlocked(_ comment: PixivComment) -> Bool {
        comments.contains { $0.id == comment.id }
            || users.contains { $0.id == comment.user.id }
    }

    func isTagBlocked(_ name: String) -> Bool {
        let normalizedName = LocalBlockArchive.normalizedTag(name)
        return tags.contains { $0.id == normalizedName }
    }

    func block(user: PixivUser) {
        blockUser(id: user.id, name: user.name)
    }

    func block(user: PixivCommentUser) {
        blockUser(id: user.id, name: user.name)
    }

    func block(artwork: PixivIllustration) {
        artworks.removeAll { $0.id == artwork.id }
        artworks.insert(
            LocalBlockedArtwork(id: artwork.id, title: artwork.title, createdAt: Date()),
            at: 0
        )
        persist()
    }

    func block(tag: PixivTag) {
        blockTag(name: tag.name, translatedName: tag.translatedName)
    }

    func block(comment: PixivComment) {
        comments.removeAll { $0.id == comment.id }
        let preview = comment.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        comments.insert(
            LocalBlockedComment(
                id: comment.id,
                authorID: comment.user.id,
                authorName: comment.user.name,
                preview: preview.isEmpty ? "表情评论" : String(preview.prefix(48)),
                createdAt: Date()
            ),
            at: 0
        )
        persist()
    }

    func blockTag(name: String, translatedName: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let normalizedName = LocalBlockArchive.normalizedTag(trimmedName)
        tags.removeAll { $0.id == normalizedName }
        tags.insert(
            LocalBlockedTag(
                name: trimmedName,
                translatedName: translatedName,
                createdAt: Date()
            ),
            at: 0
        )
        persist()
    }

    func removeUser(id: Int) {
        users.removeAll { $0.id == id }
        persist()
    }

    func removeArtwork(id: Int) {
        artworks.removeAll { $0.id == id }
        persist()
    }

    func removeTag(id: String) {
        tags.removeAll { $0.id == id }
        persist()
    }

    func removeComment(id: Int) {
        comments.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        users = []
        artworks = []
        tags = []
        comments = []
        defaults.removeObject(forKey: Self.archiveKey)
    }

    private func sortEntries() {
        users.sort { $0.createdAt > $1.createdAt }
        artworks.sort { $0.createdAt > $1.createdAt }
        tags.sort { $0.createdAt > $1.createdAt }
        comments.sort { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        let archive = LocalBlockArchive(
            users: users,
            artworks: artworks,
            tags: tags,
            comments: comments
        )
        guard let data = try? JSONEncoder().encode(archive) else { return }
        defaults.set(data, forKey: Self.archiveKey)
    }

    private func blockUser(id: Int, name: String) {
        users.removeAll { $0.id == id }
        users.insert(LocalBlockedUser(id: id, name: name, createdAt: Date()), at: 0)
        persist()
    }
}

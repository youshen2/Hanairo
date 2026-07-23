import SwiftUI

struct UserRow: View {
    @Environment(LocalBlockStore.self) private var localBlocks

    let preview: PixivUserPreview
    var showsFollowButton = false
    var onFollowChanged: ((Bool) -> Void)?

    var body: some View {
        if !localBlocks.isBlocked(preview.user) {
            HStack(spacing: 12) {
                NavigationLink(
                    value: AppRoute.user(id: preview.user.id, preview: preview.user)
                ) {
                    HStack(spacing: 12) {
                        RemoteImageView(url: preview.user.profileImageURLs.medium)
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                            .clipped()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preview.user.name)
                                .font(.headline)
                            Text("@\(preview.user.account)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let work = preview.illustrations.first {
                                Text(work.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if !showsFollowButton {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                    .appNavigationTransitionSource(for: .user(id: preview.user.id))
                }
                .buttonStyle(.plain)

                if showsFollowButton {
                    FollowButton(
                        user: preview.user,
                        compact: true,
                        onChanged: onFollowChanged
                    )
                }
            }
            .contextMenu {
                Button(
                    "屏蔽作者",
                    systemImage: "person.crop.circle.badge.minus",
                    role: .destructive
                ) {
                    localBlocks.block(user: preview.user)
                }
            }
        }
    }
}

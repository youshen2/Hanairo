import SwiftUI

struct UserProfileHeaderView: View {
    let detail: PixivUserDetail
    let isCurrentUser: Bool

    @State private var isNameExpanded = false

    @ViewBuilder
    var body: some View {
#if os(visionOS)
        foreground
            .overlay(alignment: .top) {
                avatar
                    .padding(.top, avatarTopPadding)
            }
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                foreground
            }
            .overlay(alignment: .top) {
                avatar
                    .padding(.top, avatarTopPadding)
            }
        } else {
            foreground
                .overlay(alignment: .top) {
                    avatar
                        .padding(.top, avatarTopPadding)
                }
        }
#endif
    }

    private var foreground: some View {
        VStack(spacing: 14) {
            identity
            statistics
        }
        .padding(.horizontal, 20)
        .padding(.top, foregroundTopPadding)
    }

    private var identity: some View {
        VStack(spacing: 12) {
            profileNameControl
                .padding(.top, 80)

            if !isCurrentUser {
                FollowButton(user: detail.user, usesGlass: true)
                    .frame(height: 38)
                    .padding(.top, 58)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatar: some View {
        RemoteImageView(url: detail.user.profileImageURLs.medium)
            .frame(width: 78, height: 78)
            .clipShape(Circle())
            .clipped()
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 4))
            .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
            .accessibilityLabel("\(detail.user.name)的头像")
    }

    @ViewBuilder
    private var profileNameControl: some View {
        if isNameExpanded {
            ProfileNameGlassSurface(isInteractive: true) {
                disclosureNameButton
            }
        } else {
            ViewThatFits(in: .horizontal) {
                ProfileNameGlassSurface(isInteractive: false) {
                    compactNameLabel
                }

                ProfileNameGlassSurface(isInteractive: true) {
                    disclosureNameButton
                }
            }
        }
    }

    private var compactNameLabel: some View {
        Text(detail.user.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(minWidth: 104, minHeight: 34)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(detail.user.name)
            .accessibilityValue("@\(detail.user.account)")
    }

    private var disclosureNameButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.24)) {
                isNameExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(detail.user.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(isNameExpanded ? nil : 1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isNameExpanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .frame(minWidth: 104, minHeight: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(detail.user.name)
        .accessibilityValue("@\(detail.user.account)")
        .accessibilityHint(isNameExpanded ? "轻点收起昵称" : "轻点展开完整昵称")
    }

    @ViewBuilder
    private var statistics: some View {
        FloatingGlassCard {
            statisticsContent
        }
    }

    private var statisticsContent: some View {
        HStack(spacing: 0) {
            StatLabel(value: detail.profile.totalIllusts, title: "插画")
            Divider().frame(height: 42)
            StatLabel(value: detail.profile.totalManga, title: "漫画")
            Divider().frame(height: 42)
            ProfileConnectionStatLink(
                value: detail.profile.totalFollowUsers,
                title: "关注",
                route: .userConnections(userID: detail.user.id, kind: .following)
            )
            Divider().frame(height: 42)
            ProfileConnectionStatLink(
                value: nil,
                title: "粉丝",
                route: .userConnections(userID: detail.user.id, kind: .followers)
            )
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
    }

    private var foregroundTopPadding: CGFloat {
        160
    }

    private var avatarTopPadding: CGFloat {
        foregroundTopPadding + 8
    }
}

private struct ProfileNameGlassSurface<Content: View>: View {
    let isInteractive: Bool
    @ViewBuilder let content: Content

    init(isInteractive: Bool, @ViewBuilder content: () -> Content) {
        self.isInteractive = isInteractive
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
#if os(visionOS)
        fallback
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            if isInteractive {
                content
                    .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                content
                    .glassEffect(.regular, in: .capsule)
            }
        } else {
            fallback
        }
#endif
    }

    private var fallback: some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            }
    }
}

private struct ProfileConnectionStatLink: View {
    let value: Int?
    let title: String
    let route: AppRoute

    var body: some View {
        NavigationLink(value: route) {
            VStack(spacing: 3) {
                if let value {
                    Text(value, format: .number.notation(.compactName))
                        .font(.headline)
                } else {
                    Text("查看")
                        .font(.headline)
                }

                HStack(spacing: 3) {
                    Text(title)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("查看\(title)列表")
    }
}

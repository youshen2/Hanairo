import SwiftUI

struct IllustrationMetadataView: View {
    let illustration: PixivIllustration
    let onComments: () -> Void

    @ViewBuilder
    var body: some View {
        let caption = TextSanitizer.plainText(from: illustration.caption)

#if os(visionOS)
        metadataContent(caption: caption)
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                metadataContent(caption: caption)
            }
        } else {
            metadataContent(caption: caption)
        }
#endif
    }

    private func metadataContent(caption: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            FloatingGlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    IllustrationTitleSection(illustration: illustration)
                    IllustrationArtistLink(user: illustration.user)
                    Divider()
                    IllustrationStatisticsView(illustration: illustration, onComments: onComments)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !caption.isEmpty {
                FloatingGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("作品简介")
                            .font(.headline)
                        Text(caption)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !illustration.tags.isEmpty {
                FloatingGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("标签")
                            .font(.headline)
                        IllustrationTagsView(tags: illustration.tags)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        }
    }
}

private struct IllustrationTitleSection: View {
    let illustration: PixivIllustration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(illustration.title)
                .font(.title.weight(.bold))
                .textSelection(.enabled)

            if let series = illustration.series {
                NavigationLink(value: AppRoute.illustrationSeries(id: series.id)) {
                    Label(series.title ?? "查看所属系列", systemImage: "books.vertical")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metadataLabels
                }
                VStack(alignment: .leading, spacing: 6) {
                    metadataLabels
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var metadataLabels: some View {
        if !illustration.createDate.isEmpty {
            Label(String(illustration.createDate.prefix(10)), systemImage: "calendar")
        }
        Text("ID \(illustration.id)")
        if illustration.pageCount > 1 {
            Label("\(illustration.pageCount) 页", systemImage: "rectangle.stack")
        }
        if illustration.aiType == 2 {
            Label("AI", systemImage: "wand.and.stars")
        }
    }
}

private struct IllustrationArtistLink: View {
    let user: PixivUser

    var body: some View {
        NavigationLink(value: AppRoute.user(id: user.id)) {
            HStack(spacing: 12) {
                RemoteImageView(url: user.profileImageURLs.medium)
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
                    .clipped()
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("@\(user.account)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct IllustrationTagsView: View {
    @Environment(LocalBlockStore.self) private var localBlocks

    let tags: [PixivTag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(tags) { tag in
                    NavigationLink(value: AppRoute.search(query: tag.name)) {
                        Text("#\(tag.displayName)")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(.tint)
                            .background(.tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("屏蔽此标签", systemImage: "number", role: .destructive) {
                            localBlocks.block(tag: tag)
                        }
                    }
                }
            }
        }
    }
}

private struct IllustrationStatisticsView: View {
    let illustration: PixivIllustration
    let onComments: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            StatLabel(value: illustration.totalViews, title: "浏览")
            Divider().frame(height: 32)
            StatLabel(value: illustration.totalBookmarks, title: "收藏")
            Divider().frame(height: 32)
            Button(action: onComments) {
                StatLabel(value: illustration.totalComments, title: "评论")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityHint("打开评论区")
        }
        .padding(.vertical, 14)
    }
}

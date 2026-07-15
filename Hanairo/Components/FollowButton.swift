import SwiftUI

struct FollowButton: View {
    @Environment(PixivRepository.self) private var repository

    let user: PixivUser
    var compact = false
    var usesGlass = false
    var onChanged: ((Bool) -> Void)?

    @State private var currentVisibility: PixivVisibility?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if usesGlass {
                glassFollowMenu
            } else if compact {
                followMenu
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
            } else {
                followMenu
                    .buttonStyle(.borderedProminent)
                    .tint(isFollowed ? .gray : .accentColor)
            }
        }
        .disabled(isWorking)
        .task(id: detailRequestKey) {
            await loadFollowDetail()
        }
        .alert("关注操作失败", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    @ViewBuilder
    private var glassFollowMenu: some View {
#if os(visionOS)
        fallbackGlassFollowMenu
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            if isFollowed {
                followMenu
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
            } else {
                followMenu
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
            }
        } else {
            fallbackGlassFollowMenu
        }
#endif
    }

    private var fallbackGlassFollowMenu: some View {
        followMenu
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(isFollowed ? .gray : .accentColor)
    }

    private var followMenu: some View {
        Menu {
            if isFollowed {
                visibilityButton(.public)
                visibilityButton(.private)
                Divider()
                Button("取消关注", systemImage: "person.fill.xmark", role: .destructive) {
                    update(isFollowed: false, visibility: currentVisibility ?? .public)
                }
            } else {
                Button("公开关注", systemImage: "person.badge.plus") {
                    update(isFollowed: true, visibility: .public)
                }
                Button("非公开关注", systemImage: "eye.slash") {
                    update(isFollowed: true, visibility: .private)
                }
            }
        } label: {
            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .frame(minWidth: compact ? 18 : 86)
            } else {
                Label(
                    isFollowed ? "已关注" : "关注",
                    systemImage: isFollowed ? "person.fill.checkmark" : "person.badge.plus"
                )
                .frame(minWidth: compact ? nil : 86)
            }
        }
        .accessibilityLabel(isFollowed ? "管理关注" : "关注作者")
    }

    private func visibilityButton(_ visibility: PixivVisibility) -> some View {
        Button {
            update(isFollowed: true, visibility: visibility)
        } label: {
            if currentVisibility == visibility {
                Label(visibility.title, systemImage: "checkmark")
            } else {
                Text(visibility.title)
            }
        }
    }

    private var isFollowed: Bool {
        repository.followState(for: user)
    }

    private var detailRequestKey: String {
        "\(user.id)-\(isFollowed)"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func update(isFollowed: Bool, visibility: PixivVisibility) {
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                try await repository.setFollow(
                    userID: user.id,
                    isFollowed: isFollowed,
                    visibility: visibility
                )
                currentVisibility = isFollowed ? visibility : nil
                onChanged?(isFollowed)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadFollowDetail() async {
        guard isFollowed else {
            currentVisibility = nil
            return
        }
        do {
            let detail = try await repository.followDetail(userID: user.id)
            guard !Task.isCancelled else { return }
            currentVisibility = detail.visibility
        } catch is CancellationError {
            return
        } catch {
            currentVisibility = nil
        }
    }
}

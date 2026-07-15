import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(AuthenticationStore.self) private var authentication

    @State private var activeFlow: PixivAuthorizationFlow?
    @State private var browserErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)
                identity
                authorizationActions

                if let errorMessage {
                    AuthenticationErrorView(message: errorMessage)
                }

                privacyNote
                Spacer(minLength: 24)
            }
            .padding(24)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("登录")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }

                NavigationLink {
                    AboutView()
                } label: {
                    Label("关于", systemImage: "info.circle")
                }
            }
        }
    }

    private var identity: some View {
        VStack(spacing: 14) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 68, weight: .semibold))
                .foregroundStyle(.pink.gradient)
                .accessibilityHidden(true)
            Text("Hanairo")
                .font(.largeTitle.bold())
            Text("登录 Pixiv 后即可浏览推荐、排行榜、收藏与关注内容。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var authorizationActions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await authorize(using: .login) }
            } label: {
                actionLabel(
                    title: "登录 Pixiv",
                    systemImage: "person.crop.circle.badge.checkmark",
                    isActive: activeFlow == .login
                )
            }
            .buttonStyle(.borderedProminent)

            Button {
                Task { await authorize(using: .accountCreation) }
            } label: {
                actionLabel(
                    title: "注册 Pixiv 账户",
                    systemImage: "person.badge.plus",
                    isActive: activeFlow == .accountCreation
                )
            }
            .buttonStyle(.bordered)

            NavigationLink {
                TokenLoginView()
            } label: {
                Text("使用 Refresh Token 登录")
                    .font(.callout)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .controlSize(.large)
        .disabled(isWorking)
    }

    private var privacyNote: some View {
        VStack(spacing: 8) {
            Text("登录页由 Apple 系统安全浏览会话打开。Hanairo 不会接触你的 Pixiv 密码，令牌只保存在系统钥匙串中。")
                .multilineTextAlignment(.center)
            Link("Pixiv 服务条款", destination: URL(string: "https://www.pixiv.net/terms/?page=term")!)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var errorMessage: String? {
        authentication.errorMessage ?? browserErrorMessage
    }

    private var isWorking: Bool {
        activeFlow != nil || authentication.isAuthenticating
    }

    private func actionLabel(title: String, systemImage: String, isActive: Bool) -> some View {
        HStack {
            if isActive {
                ProgressView()
            } else {
                Image(systemName: systemImage)
            }
            Text(isActive ? "正在等待 Pixiv…" : title)
        }
        .frame(maxWidth: .infinity)
    }

    private func authorize(using flow: PixivAuthorizationFlow) async {
        guard !isWorking else { return }
        activeFlow = flow
        browserErrorMessage = nil
        authentication.clearError()
        defer { activeFlow = nil }

        do {
            let preparation = authentication.prepareAuthorization(for: flow)
            let callbackURL = try await webAuthenticationSession.authenticate(
                using: preparation.url,
                callback: .customScheme(APIConfiguration.oauthCallbackScheme),
                preferredBrowserSession: .shared,
                additionalHeaderFields: [:]
            )
            let code = try OAuthCallback.authorizationCode(from: callbackURL)
            try await authentication.signIn(code: code, verifier: preparation.verifier)
        } catch {
            guard !isCancellation(error), authentication.errorMessage == nil else { return }
            browserErrorMessage = error.localizedDescription
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == ASWebAuthenticationSessionError.errorDomain
            && error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
    }
}

#Preview("登录") {
    NavigationStack {
        LoginView()
    }
    .withPreviewDependencies()
}

import SwiftUI

struct TokenLoginView: View {
    @Environment(AuthenticationStore.self) private var authentication

    @State private var refreshToken = ""
    @State private var revealsToken = false
    @FocusState private var isTokenFieldFocused: Bool

    var body: some View {
        Form {
            tokenSection

            if let errorMessage = authentication.errorMessage {
                Section {
                    AuthenticationErrorView(message: errorMessage)
                }
            }

            submitSection
        }
        .formStyle(.grouped)
        .navigationTitle("令牌登录")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PasteButton(payloadType: String.self) { values in
                    guard let value = values.first else { return }
                    refreshToken = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .accessibilityLabel("粘贴令牌")
                .help("粘贴令牌")
            }
        }
        .onAppear {
            authentication.clearError()
            isTokenFieldFocused = true
        }
    }

    private var tokenSection: some View {
        Section {
            Group {
                if revealsToken {
                    TextField("粘贴 Refresh Token", text: $refreshToken)
                } else {
                    SecureField("粘贴 Refresh Token", text: $refreshToken)
                }
            }
            .focused($isTokenFieldFocused)
            .onSubmit {
                guard canSubmit else { return }
                Task { await signIn() }
            }

            Toggle("显示令牌", isOn: $revealsToken)

            if !normalizedToken.isEmpty {
                LabeledContent("字符数", value: normalizedToken.count.formatted())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Refresh Token")
        } footer: {
            Text("令牌只会保存在系统钥匙串中，请勿与他人分享。")
        }
    }

    private var submitSection: some View {
        Section {
            Button {
                Task { await signIn() }
            } label: {
                HStack {
                    Spacer()
                    if authentication.isAuthenticating {
                        ProgressView()
                        Text("正在验证…")
                    } else {
                        Label("登录", systemImage: "arrow.right.circle.fill")
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)
        }
    }

    private var normalizedToken: String {
        refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !normalizedToken.isEmpty && !authentication.isAuthenticating
    }

    private func signIn() async {
        guard canSubmit else { return }
        isTokenFieldFocused = false
        do {
            try await authentication.signIn(refreshToken: normalizedToken)
        } catch {
            return
        }
    }
}

#Preview("令牌登录") {
    NavigationStack {
        TokenLoginView()
    }
    .withPreviewDependencies()
}

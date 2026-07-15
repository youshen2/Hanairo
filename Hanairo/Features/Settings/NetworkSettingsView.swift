import SwiftUI

struct NetworkSettingsView: View {
    @Environment(NetworkSettings.self) private var settings

    @State private var apiState: NetworkDiagnosticState = .idle
    @State private var imageState: NetworkDiagnosticState = .idle
    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("连接模式", selection: $settings.mode) {
                    ForEach(AppNetworkMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(settings.mode.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("允许使用蜂窝网络", isOn: $settings.allowsCellularAccess)
                Stepper(
                    "请求超时 \(settings.requestTimeout) 秒",
                    value: $settings.requestTimeout,
                    in: NetworkSettings.timeoutRange,
                    step: 5
                )
            } header: {
                Text("连接")
            } footer: {
                Text("网络配置会在下一次请求时生效。切换配置会取消旧连接，但不会清除缓存或登录状态。")
            }

            if settings.mode == .httpProxy {
                Section {
                    TextField("代理主机", text: $settings.proxyHost)
                    TextField("代理端口", value: $settings.proxyPort, format: .number)
                    validationRow(title: "代理配置", isValid: settings.hasValidProxy)
                } header: {
                    Text("HTTP 代理")
                } footer: {
                    Text("HTTP 与 HTTPS 请求会通过同一代理发送。Hanairo 不会绕过 TLS 证书校验。")
                }
            }

            Section {
                TextField("API 基础地址", text: $settings.apiBaseURLString)
                validationRow(title: "API 地址", isValid: settings.hasValidAPIBaseURL)
                TextField("OAuth 基础地址", text: $settings.oauthBaseURLString)
                validationRow(title: "OAuth 地址", isValid: settings.hasValidOAuthBaseURL)
                TextField("图片域名（可选）", text: $settings.imageHostOverride)
                validationRow(title: "图片域名", isValid: settings.hasValidImageHost)
            } header: {
                Text("服务地址")
            } footer: {
                Text("服务地址必须使用 HTTPS。图片域名只替换 i.pximg.net 与 s.pximg.net，不改变图片路径。留空即使用 Pixiv 原地址。")
            }

            Section("连通性检测") {
                diagnosticRow(title: "Pixiv API", state: apiState) {
                    apiState = .testing
                    apiState = await NetworkDiagnosticsService(settings: settings).testAPI()
                }
                diagnosticRow(title: "Pixiv 图片", state: imageState) {
                    imageState = .testing
                    imageState = await NetworkDiagnosticsService(settings: settings).testImage()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("网络")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("恢复默认", systemImage: "arrow.counterclockwise") {
                    showsResetConfirmation = true
                }
                .labelStyle(.iconOnly)
            }
        }
        .confirmationDialog(
            "恢复默认网络设置？",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复默认", role: .destructive) {
                settings.reset()
                apiState = .idle
                imageState = .idle
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func validationRow(title: String, isValid: Bool) -> some View {
        Label(isValid ? "\(title)有效" : "\(title)无效，将回退到默认值", systemImage: isValid ? "checkmark.circle" : "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(isValid ? Color.secondary : Color.red)
    }

    private func diagnosticRow(
        title: String,
        state: NetworkDiagnosticState,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            guard state != .testing else { return }
            Task { await action() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(state.title)
                        .font(.caption)
                        .foregroundStyle(diagnosticColor(state))
                        .lineLimit(2)
                }
                Spacer()
                if state == .testing {
                    ProgressView()
                } else {
                    Image(systemName: state.systemImage)
                        .foregroundStyle(diagnosticColor(state))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func diagnosticColor(_ state: NetworkDiagnosticState) -> Color {
        switch state {
        case .succeeded: .green
        case .failed: .red
        default: .secondary
        }
    }
}

#Preview("网络设置") {
    NavigationStack {
        NetworkSettingsView()
    }
    .withPreviewDependencies()
}

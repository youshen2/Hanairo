import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(Color.accentColor.gradient)
                    Text("Hanairo")
                        .font(.title.weight(.bold))
                    Text("版本 \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }

            Section("说明") {
                Text("Hanairo 使用 SwiftUI 与系统框架构建，是面向 Pixiv 的第三方客户端。")
                Text("Pixiv、pixiv 及相关标志归 pixiv Inc. 所有。")
            }

            Section("开源许可") {
                Text("Hanairo 依据 Mozilla Public License 2.0（MPL-2.0）发布。")
                Link(destination: URL(string: "https://www.mozilla.org/MPL/2.0/")!) {
                    Label("查看 MPL 2.0", systemImage: "doc.text")
                }
            }

            Section("致谢") {
                Text("功能结构参考了 PixEz Flutter 项目。")
                Link(destination: URL(string: "https://github.com/Notsfsssf/pixez-flutter")!) {
                    Label("PixEz Flutter", systemImage: "arrow.up.right.square")
                }
            }
        }
        .navigationTitle("关于")
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

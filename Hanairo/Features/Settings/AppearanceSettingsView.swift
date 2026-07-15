import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("显示") {
                Picker("显示模式", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
            }

            Section {
                LabeledContent("渐隐位置") {
                    Text(
                        settings.profileBackgroundScreenRatio,
                        format: .percent.precision(.fractionLength(0))
                    )
                    .foregroundStyle(.secondary)
                }

                Slider(
                    value: $settings.profileBackgroundScreenRatio,
                    in: AppSettings.profileBackgroundScreenRatioRange,
                    step: 0.05
                ) {
                    Text("背景显示区域")
                } minimumValueLabel: {
                    Text("短")
                } maximumValueLabel: {
                    Text("长")
                }
            } header: {
                Text("作者主页背景")
            } footer: {
                Text("设置背景图在屏幕高度的哪个位置完全渐隐。")
            }

            Section {
                Picker("详情画质", selection: $settings.imageQuality) {
                    ForEach(ArtworkImageQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
            } header: {
                Text("图片")
            } footer: {
                Text("画质设置会应用到之后加载的作品图片，已缓存内容不会重复下载。")
            }

            Section {
                Toggle("视差滚动", isOn: $settings.artworkParallaxEnabled)
            } header: {
                Text("作品详情")
            } footer: {
                Text("开启后，信息卡片出现时图片会产生视差并渐隐到页面背景；关闭后图片按普通顺序排列。")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("外观与图片")
    }
}

#Preview("外观与图片") {
    NavigationStack {
        AppearanceSettingsView()
    }
    .withPreviewDependencies()
}

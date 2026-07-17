# Hanairo

Hanairo 是使用 SwiftUI 与 Apple 系统框架实现的第三方 Pixiv 客户端，遵守液态玻璃设计风格。

## 应用截图

<p align="center">
  <img src="docs/screenshots/01.png" alt="Hanairo 应用截图 1" width="20%">
  <img src="docs/screenshots/02.png" alt="Hanairo 应用截图 2" width="20%">
  <img src="docs/screenshots/03.png" alt="Hanairo 应用截图 3" width="20%">
  <br>
  <img src="docs/screenshots/04.png" alt="Hanairo 应用截图 4" width="20%">
  <img src="docs/screenshots/05.png" alt="Hanairo 应用截图 5" width="20%">
  <img src="docs/screenshots/06.png" alt="Hanairo 应用截图 6" width="20%">
</p>

## 当前功能

- 推荐插画与漫画
- 日榜、周榜、月榜和历史日期排行
- 公开收藏与关注动态
- 热门标签、作品搜索和用户搜索
- 多页作品详情、标签、作者、统计和相关作品
- 原图大图查看、双击与手势缩放、多页切换
- 浮动收藏、分享与原图下载操作栏
- 作者资料、关注与作品列表
- 收藏、关注、分享和内容过滤
- 强制登录根路由，未认证时无法进入主界面
- PKCE 系统浏览器授权、自动回调与 Refresh Token 登录
- 钥匙串保存令牌、自动刷新令牌和 401 重试

## 目录结构

```text
Hanairo/
├── App/          应用入口、标签栏与路由
├── Components/   可复用的纯 SwiftUI 组件
├── Core/
│   ├── Models/       Pixiv 与认证数据模型
│   ├── Networking/   HTTP、OAuth 与 Pixiv API
│   ├── Persistence/  钥匙串持久化
│   ├── Services/     会话、设置、图片与仓储服务
│   └── Support/      加载状态、预览依赖与文本工具
└── Features/     按产品功能拆分的页面
```

视图只负责展示和局部交互，网络请求集中在 `PixivAPI`，登录状态集中在 `AuthenticationStore`，业务入口集中在 `PixivRepository`。

## 登录说明

应用启动时会先从钥匙串恢复会话；没有有效账户时只显示登录界面。点击登录后，Hanairo 通过 SwiftUI 的系统 Web Authentication Session 打开 Pixiv 授权页，自动接收 `pixiv://account` 回调、提取授权码并换取令牌，不需要复制粘贴。已有 Refresh Token 的用户可以进入独立的高级登录页面。令牌只保存在系统钥匙串中。

## 构建

使用 Xcode 打开 `Hanairo.xcodeproj` 后运行 `Hanairo` Scheme。项目当前可编译到 iOS、macOS 与 visionOS；macOS 沙盒仅申请了网络客户端权限。

运行 `bash build_ios_unsigned.sh` 可以在 `build/` 目录生成 iOS 未签名 IPA。GitHub Actions 会在 main 分支、Pull Request、`v*` 标签和手动触发时执行同一构建；标签构建完成后会自动创建 GitHub Release。

### Telegram CI 发布

每次 CI 成功生成 IPA 后，GitHub Actions 会通过 Telegram Bot 将 `Hanairo-iOS-unsigned.ipa` 直接发送到频道。外部 Fork 发起的 Pull Request 不会读取仓库 Secrets，因此只构建和保存产物，不会发送到频道。

配置方式：

1. 通过 Telegram 的 `@BotFather` 创建机器人并取得 Bot Token。
2. 将机器人添加为目标频道管理员，并授予发布消息权限。
3. 在 GitHub 仓库的 `Settings > Secrets and variables > Actions` 中添加以下 Repository secrets：
   - `TELEGRAM_BOT_TOKEN`：机器人 Token。
   - `TELEGRAM_CHAT_ID`：频道标识；公开频道可填写 `@频道用户名`，私有频道可填写 `-100` 开头的数字 ID。

如果任一 Secret 缺失、机器人没有频道发布权限或 Telegram 上传失败，`Send IPA to Telegram channel` 任务会失败并显示原因。

## 说明

Pixiv 的移动端接口并非公开稳定 API，接口或授权流程变化时需要同步调整网络层。功能结构参考了 [PixEz Flutter](https://github.com/Notsfsssf/pixez-flutter)。Hanairo 与 pixiv Inc. 没有隶属关系。

## 许可证

Hanairo 依据 [Mozilla Public License 2.0](LICENSE) 发布，SPDX 标识为 `MPL-2.0`。

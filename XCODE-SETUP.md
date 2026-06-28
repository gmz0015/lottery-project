# Xcode App 工程说明

仓库现在采用「**本地 SwiftPM 包 + Xcode App 工程**」结构:

```
Lottery-Claude/
├── LotteryKit/                ← 独立本地 SwiftPM 包(纯业务逻辑 + 全部单测)
│   ├── Package.swift
│   ├── Sources/LotteryKit/…
│   └── Tests/LotteryKitTests/…
└── LotteryApp/                ← 已创建好的 macOS Xcode 工程
    ├── LotteryApp.xcodeproj
    ├── LotteryApp/            ← SwiftUI App 源码与 Assets.xcassets
    ├── LotteryAppTests/
    └── LotteryAppUITests/
```

`LotteryChecker-Sources/` 只是创建 Xcode 工程前的临时源码目录；源码迁入 `LotteryApp/LotteryApp/` 后已删除。之后改界面时直接编辑 `LotteryApp/LotteryApp/`。

---

## 0. 前置:安装完整版 Xcode

需要完整 **Xcode** 才能构建 `.app`、Archive、公证或上传 App Store。仅安装 Command Line Tools 时,`LotteryKit` 里使用的 SwiftData 宏插件也可能无法加载。

安装后执行一次切换:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   xcodebuild -version   # 能打印版本号即 OK
   ```

---

## 1. 运行现有 App 工程

用 Xcode 打开:

```bash
open LotteryApp/LotteryApp.xcodeproj
```

当前工程:

- App target: `LotteryApp`
- Bundle ID: `org.ultimate.LotteryApp`
- 本地包依赖: `../LotteryKit`
- App 入口: `LotteryApp/LotteryApp/LotteryCheckerApp.swift`

命令行构建/运行脚本:

```bash
script/build_and_run.sh
script/build_and_run.sh --verify
script/build_and_run.sh --logs
```

逻辑层单测仍可独立运行:

```bash
cd LotteryKit
swift test
```

Xcode 的 Product ▸ Test 也会发现 `LotteryKit` 包测试。

---

## 2. 配置为可上架(签名 + 沙盒)

选中工程 ▸ **LotteryApp** target:

### Signing & Capabilities
- **Automatically manage signing** 打勾,Team 选你的账号。
- 点 **+ Capability** 添加 **App Sandbox**(App Store 强制),并按本 App 需要勾选:
  - **Network ▸ Outgoing Connections (Client)** —— `DrawFetchService` 要联网拉开奖数据。
  - **File Access ▸ User Selected File** = Read/Write —— 选取彩票图片、保存数据。
- 视需要添加 **Hardened Runtime**(App Store 外分发/公证需要)。

### General
- 确认 **Bundle Identifier**、**Version**、**Build**、**Deployment Target = macOS 14.0**(与包一致)。
- 在 **Assets.xcassets** 里放置 **AppIcon**(上架必需,需 1024×1024 等尺寸)。

---

## 3. 构建与验证

- **⌘R** 运行 App。
- **⌘U** 跑测试(`LotteryKit` 包的单测会随工程一起被发现)。

---

## 4. 上架 / 分发

- **App Store**:**Product ▸ Archive** → Organizer 里 **Distribute App ▸ App Store Connect**。
  需要先在 [App Store Connect](https://appstoreconnect.apple.com) 建好 App 记录(需付费的 Apple Developer Program)。
- **App Store 外(直接给人用)**:Archive → **Distribute App ▸ Developer ID** → 自动公证(notarize)→ 导出 `.app`/`.dmg`。
  需要 **Developer ID Application** 证书(同样属于付费开发者账号)。

> 当前签名身份是 `Apple Development`(只能本机调试)。正式上架/分发需要加入 **Apple Developer Program**($99/年)以获得 `Apple Distribution` / `Developer ID` 证书。

---

## 之后的日常

- **改业务逻辑 / 加单测** → 编辑 `LotteryKit/`,可在终端 `cd LotteryKit && swift test` 独立验证,也可在 Xcode ⌘U。
- **改界面** → 编辑 `LotteryApp/LotteryApp/` 里的 SwiftUI 文件。
- 工程文件 `*.xcodeproj` 可以提交进 git(用户数据已被 `.gitignore` 排除)。

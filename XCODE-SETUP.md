# 用 Xcode 搭建可上架的 App 工程(方案 A)

仓库已重构为「**本地 SwiftPM 包 + App 源码**」两部分:

```
Lottery-Claude/
├── LotteryKit/                ← 独立本地 SwiftPM 包(纯业务逻辑 + 全部单测)
│   ├── Package.swift
│   ├── Sources/LotteryKit/…
│   └── Tests/LotteryKitTests/…
└── LotteryChecker-Sources/    ← App 源码(SwiftUI),待加入下面新建的工程
    ├── LotteryCheckerApp.swift
    ├── AppModel.swift
    ├── Aliases.swift
    └── Views/…
```

下面把它们组装成一个可构建、可上架的 Xcode 工程。

---

## 0. 前置:安装完整版 Xcode

当前机器只有 **Command Line Tools**,无法构建 `.app`、Archive、公证或上传 App Store。

1. App Store 搜索安装 **Xcode**(免费,数 GB)。
2. 安装后执行一次切换:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   xcodebuild -version   # 能打印版本号即 OK
   ```

> 装好 Xcode 后,`LotteryKit` 包就能独立跑测试了:
> ```bash
> cd LotteryKit && swift test
> ```
> (现在用 Command Line Tools 跑会因缺少 SwiftData 宏插件而失败,这是工具链限制,不是代码问题。)

---

## 1. 新建 macOS App 工程

1. Xcode → **File ▸ New ▸ Project…**
2. 选 **macOS ▸ App**,Next。
3. 填写:
   - **Product Name**: `LotteryChecker`
   - **Team**: 选你的 `Apple Development: yinming fu`(已有签名身份)
   - **Organization Identifier**: 例如 `com.yinmingfu`(最终 Bundle ID 会是 `com.yinmingfu.LotteryChecker`)
   - **Interface**: SwiftUI　**Language**: Swift
   - **Storage**: None(我们自己用 SwiftData)
4. 保存位置选**仓库根目录** `Lottery-Claude/`。
   Xcode 会创建 `Lottery-Claude/LotteryChecker/LotteryChecker.xcodeproj`,不会与 `LotteryChecker-Sources/` 冲突。

---

## 2. 把 LotteryKit 作为本地包加进去

1. **File ▸ Add Package Dependencies…**
2. 左下角 **Add Local…**,选仓库里的 `LotteryKit/` 文件夹,**Add Package**。
3. 在弹出的 target 选择里,把 **LotteryKit** 库勾给 **LotteryChecker** target。

完成后工程左侧会出现一个本地 `LotteryKit` 包引用。

---

## 3. 把 App 源码加入工程

1. 在 Finder 里,把 `LotteryChecker-Sources/` 内的全部内容
   (`LotteryCheckerApp.swift`、`AppModel.swift`、`Aliases.swift`、`Views/`)
   **移动**到 Xcode 新建出来的 `LotteryChecker/LotteryChecker/` 目录里。
2. **删除 Xcode 自动生成的占位文件**:`ContentView.swift`,以及它自带的 `LotteryCheckerApp.swift`
   (我们的版本会覆盖它——确保最终只保留 `LotteryChecker-Sources` 里那份 `@main`)。
3. 回到 Xcode:右键 `LotteryChecker` 组 ▸ **Add Files to "LotteryChecker"…**,
   选中刚移入的文件和 `Views` 文件夹:
   - **不要**勾 "Copy items if needed"(文件已就位)
   - "Create groups"
   - Target 勾 **LotteryChecker**
4. 删除已空的 `LotteryChecker-Sources/` 文件夹。

> App 代码里用的是 `import LotteryKit`,无需改动。

---

## 4. 配置为可上架(签名 + 沙盒)

选中工程 ▸ **LotteryChecker** target:

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

## 5. 构建与验证

- **⌘R** 运行 App。
- **⌘U** 跑测试(`LotteryKit` 包的单测会随工程一起被发现)。

---

## 6. 上架 / 分发

- **App Store**:**Product ▸ Archive** → Organizer 里 **Distribute App ▸ App Store Connect**。
  需要先在 [App Store Connect](https://appstoreconnect.apple.com) 建好 App 记录(需付费的 Apple Developer Program)。
- **App Store 外(直接给人用)**:Archive → **Distribute App ▸ Developer ID** → 自动公证(notarize)→ 导出 `.app`/`.dmg`。
  需要 **Developer ID Application** 证书(同样属于付费开发者账号)。

> 当前签名身份是 `Apple Development`(只能本机调试)。正式上架/分发需要加入 **Apple Developer Program**($99/年)以获得 `Apple Distribution` / `Developer ID` 证书。

---

## 之后的日常

- **改业务逻辑 / 加单测** → 编辑 `LotteryKit/`,可在终端 `cd LotteryKit && swift test` 独立验证,也可在 Xcode ⌘U。
- **改界面** → 编辑工程里的 SwiftUI 文件。
- 工程文件 `*.xcodeproj` 可以提交进 git(用户数据已被 `.gitignore` 排除)。

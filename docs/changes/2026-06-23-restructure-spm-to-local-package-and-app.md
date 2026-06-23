# 改动记录:拆分为本地 SwiftPM 包 + App 工程(方案 A)

- **日期**:2026-06-23
- **提交**:`refactor: 拆分为本地 SwiftPM 包 + App 源码(方案 A)`(`1f15150`)
- **范围**:Mac App 的工程结构;不涉及业务逻辑、Web 服务

## 背景与动机

原 Mac App 是单一 SwiftPM 工程(`macapp/`),用一个 `executableTarget` 跑界面:

```swift
.executableTarget(name: "LotteryChecker", dependencies: ["LotteryKit"])
```

`swift run` / `swift build` 产出的是**裸命令行可执行文件(Mach-O binary)**,不是 macOS 需要的 `.app` 应用包。要**上架 App Store / 对外分发**,必须有完整的 `.app` bundle,包含 SwiftPM 默认不提供的:`Info.plist`、应用图标、代码签名、App Sandbox/entitlements、公证。这些由 Xcode App 工程负责。

因此采用**方案 A**:把项目拆成「**业务逻辑用本地 SwiftPM 包 + 界面用 Xcode App 工程引用该包**」——这是 macOS App 的标准组织方式,逻辑可独立编译/测试/复用,工程负责打包签名。

> 工程文件 `.xcodeproj` 由用户在 Xcode GUI 中创建(本机当时仅装了 Command Line Tools,无法在命令行生成/构建工程)。

## 结构变更

### 之前

```
macapp/
├── Package.swift                 # LotteryKit 库 + LotteryChecker 可执行 + 测试
├── Sources/
│   ├── LotteryKit/               # 逻辑层
│   └── LotteryChecker/           # SwiftUI executableTarget
└── Tests/LotteryKitTests/
```

### 之后

```
LotteryKit/                       # 独立本地 SwiftPM 包(库 + 测试)
├── Package.swift                 # 仅 .library(LotteryKit) + testTarget
├── Sources/LotteryKit/…          # 符合 Sources/<target>/ 约定
└── Tests/LotteryKitTests/…

LotteryChecker-Sources/           # App 的 SwiftUI 源码,待加入 Xcode 工程
├── LotteryCheckerApp.swift / AppModel.swift / Aliases.swift
└── Views/…

XCODE-SETUP.md                    # GUI 搭建工程 + 接本地包 + 配沙盒上架的步骤
```

要点:

- 所有源码用 `git mv` 迁移,提交以 **rename(100%)** 记录,历史完整保留。
- 新 `LotteryKit/Package.swift` 去掉了 `executableTarget`,只保留库与测试 target,并显式声明 `.library` product 供工程依赖。
- 删除旧 `macapp/` 容器(含其 `.gitignore`)。
- 根 `.gitignore` 补充 SwiftPM(`.build/`、`.swiftpm/`、`Package.resolved`)与 Xcode 相关条目。

## 验证

- `swift package describe`:确认 `LotteryKit` 库 target + `LotteryKitTests`(12 个测试文件)路径解析正确,符合 SwiftPM 约定。
- `swift build`:编译正常启动,仅在 `SwiftDataMacros` 宏插件处失败——这是**仅装 Command Line Tools、缺完整 Xcode** 的工具链限制,非代码/结构问题。装好 Xcode 后 `swift test` 与 Xcode ⌘U 均可运行。

## 后续动作(用户侧)

1. App Store 安装**完整版 Xcode**,`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
2. 按 [`../../XCODE-SETUP.md`](../../XCODE-SETUP.md):新建 App 工程 → Add Local 接入 `LotteryKit/` → 加入 `LotteryChecker-Sources/` → 配 Sandbox/签名/图标 → Archive 上架。
3. 正式上架/对外分发需加入 **Apple Developer Program($99/年)** 以获得 `Apple Distribution` / `Developer ID` 证书(现有 `Apple Development` 仅本机调试)。

## 影响

- ✅ 逻辑层可独立 `cd LotteryKit && swift test`。
- ⚠️ 不再能 `swift run` 启动 App;运行/调试改用 Xcode 工程。
- ⚠️ 引用旧 `macapp/` 路径的脚本/文档需更新(README 已同步)。

# 彩票验奖 Mac App Implementation Plan

> **⚠️ 结构已重构(本文为历史存档,路径未更新):** 工程已从单一 SwiftPM 拆为「本地包 `LotteryKit/` + Xcode App 工程 `LotteryApp/`」。下文中的 `macapp/` 路径、`LotteryChecker-Sources/` 临时目录与 `swift run LotteryChecker` 已失效,以仓库根 README 与 [`../../changes/2026-06-23-restructure-spm-to-local-package-and-app.md`](../../changes/2026-06-23-restructure-spm-to-local-package-and-app.md) 为准。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 原生 SwiftUI macOS app：上传彩票照片→大模型识别→可编辑确认→选数据源拉取开奖→验奖；以彩票为中心存多条验奖记录，开奖按(彩种,期数,源)带不可变版本，含 Dashboard/验奖结果总览/统计页。

**Architecture:** 无第三方依赖的 Swift Package。逻辑层 `LotteryKit`（模型/校验/评奖/数据源/识别/持久化/统计）全部可用 `swift test` 单测；UI 在可执行 target `LotteryChecker`，用 `swift run` 手动验证。本地 SwiftData 持久化，iCloud-ready（CloudKit 默认关闭）。

**Tech Stack:** Swift 5.10 · SwiftUI · SwiftData · Swift Charts · XCTest · 仅 Apple 框架（无外部依赖，离线可构建）

## Global Constraints

- 项目根：仓库下 `macapp/`，Swift Package（`Package.swift`）。平台 `macOS(.v14)`。
- 两个彩种：`ssq`（双色球）/ `dlt`（大乐透）。号码规则：
  - `ssq`：前区/红球 6 个（1–33，互不相同）；后区/蓝球 1 个（1–16）。
  - `dlt`：前区 5 个（1–35，互不相同）；后区 2 个（1–12，互不相同）。
- 数据来源标签 `DataSourceKind`：`officialSporttery`(体彩) / `officialCWL`(福彩) / `webService` / `manual`。
- 开奖版本 `origin`：`fetched`（数据源抓取，带 `sourceURL`）/ `manual`（手动新增或修改，无 URL）。版本不可变，修改即新增。
- `Draw` 唯一性 = (category, issue, source)，由 Store 代码保证（SwiftData 无复合唯一约束）。
- 验奖记录引用具体 `DrawVersion`，并存结果快照（号码/命中/奖级/金额/合计）。
- 单式每注成本 ¥2；投入 = 注数 × 2（`Ticket.cost` 可覆盖）。仅实现单式评奖；复式/胆拖 UI 留入口标「开发中」。
- 模型协议：OpenAI 兼容 `/chat/completions`，多模态；配置 Base URL / API Key / 模型名。
- 模型识别输出严格 JSON：`{"category":"dlt|ssq","issue":"...","bets":[{"front":[...],"back":[...]}]}`。
- API JSON（Web 服务数据源）字段 camelCase：`frontNumbers, backNumbers, drawDate, prizes`。
- 所有公开类型/函数加 `public`（跨 target 可见）。`LotteryKit` 不得 `import SwiftUI`/AppKit 于纯逻辑文件（评奖/校验/统计/解析保持可单测、平台无关）。
- 测试命令：`cd macapp && swift test`。运行 app：`cd macapp && swift run LotteryChecker`。
- 每个任务结束都要 `git commit`。

## 双色球评奖表（前区命中 r∈0..6，后区命中 b∈0..1）

| 条件 | 奖级 | 金额 |
|---|---|---|
| r=6,b=1 | 一等奖 | 浮动(取开奖 prizes) |
| r=6,b=0 | 二等奖 | 浮动 |
| r=5,b=1 | 三等奖 | 3000 |
| r=5,b=0 或 r=4,b=1 | 四等奖 | 200 |
| r=4,b=0 或 r=3,b=1 | 五等奖 | 10 |
| b=1 且 r≤2 | 六等奖 | 5 |
| 其它 | 未中奖 | 0 |

## 大乐透评奖表（前区命中 f∈0..5，后区命中 k∈0..2）

| 条件 | 奖级 | 金额 |
|---|---|---|
| f=5,k=2 | 一等奖 | 浮动 |
| f=5,k=1 | 二等奖 | 浮动 |
| f=5,k=0 | 三等奖 | 10000 |
| f=4,k=2 | 四等奖 | 3000 |
| f=4,k=1 | 五等奖 | 300 |
| f=3,k=2 | 六等奖 | 200 |
| f=4,k=0 | 七等奖 | 100 |
| f=3,k=1 或 f=2,k=2 | 八等奖 | 15 |
| f=3,k=0 或 f=2,k=1 或 f=1,k=2 或 f=0,k=2 | 九等奖 | 5 |
| 其它 | 未中奖 | 0 |

---

## 文件结构

```
macapp/
  Package.swift
  Sources/
    LotteryKit/
      Models/
        Category.swift              # enum Category + 规则
        DataSourceKind.swift        # enum 来源
        Bet.swift                   # struct Bet (Codable)
        Entities.swift              # @Model Ticket/VerificationRecord/Draw/DrawVersion + 快照 struct
      Logic/
        NumberValidation.swift      # 号码校验
        PrizeEvaluator.swift        # 评奖纯函数 + PrizeTier/BetResult
        StatsService.swift          # 统计聚合纯函数
      DataSources/
        DrawResult.swift            # DrawResult + DrawDataSource 协议
        SportteryDataSource.swift   # 大乐透官方 (parse + fetch)
        CWLDataSource.swift         # 双色球官方
        WebServiceDataSource.swift  # 自建服务
        DrawFetchService.swift      # 缓存优先编排
      Recognition/
        VisionRecognizer.swift      # 协议 + RecognizedTicket + OpenAI 实现(请求构造/响应解析)
      Persistence/
        Store.swift                 # SwiftData 容器 + CRUD/版本管理
        ImageStore.swift            # 原图落盘
      Settings/
        AppSettings.swift           # 配置读写
    LotteryChecker/
      LotteryCheckerApp.swift       # @main + 侧边栏导航
      Views/
        DashboardView.swift
        VerifyView.swift
        TicketListView.swift
        TicketDetailView.swift
        ResultsOverviewView.swift
        StatsView.swift
        SettingsView.swift
        DrawVersionSheet.swift
        NumberBadges.swift          # 号码球展示小组件
      AppModel.swift                # 顶层环境对象(Store/Settings/Fetch/Recognizer 装配)
  Tests/
    LotteryKitTests/
      CategoryTests.swift
      NumberValidationTests.swift
      PrizeEvaluatorSSQTests.swift
      PrizeEvaluatorDLTTests.swift
      StoreTests.swift
      ImageStoreTests.swift
      DataSourceParsingTests.swift
      DrawFetchServiceTests.swift
      VisionRecognizerTests.swift
      AppSettingsTests.swift
      StatsServiceTests.swift
```

---

### Task 1: Swift Package 脚手架 + 冒烟测试

**Files:**
- Create: `macapp/Package.swift`
- Create: `macapp/Sources/LotteryKit/LotteryKit.swift`
- Create: `macapp/Sources/LotteryChecker/LotteryCheckerApp.swift`
- Create: `macapp/Tests/LotteryKitTests/SmokeTests.swift`

**Interfaces:**
- Produces: 三个 target（库 `LotteryKit`、可执行 `LotteryChecker`、测试 `LotteryKitTests`）；`LotteryKit.version` 常量。

- [ ] **Step 1: 写 Package.swift**

`macapp/Package.swift`：
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LotteryChecker",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "LotteryKit"),
        .executableTarget(name: "LotteryChecker", dependencies: ["LotteryKit"]),
        .testTarget(name: "LotteryKitTests", dependencies: ["LotteryKit"]),
    ]
)
```

- [ ] **Step 2: 写库占位与 app 占位**

`macapp/Sources/LotteryKit/LotteryKit.swift`：
```swift
public enum LotteryKit {
    public static let version = "1.0.0"
}
```
`macapp/Sources/LotteryChecker/LotteryCheckerApp.swift`：
```swift
import SwiftUI

@main
struct LotteryCheckerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("LotteryChecker")
        }
    }
}
```

- [ ] **Step 3: 写冒烟测试**

`macapp/Tests/LotteryKitTests/SmokeTests.swift`：
```swift
import XCTest
@testable import LotteryKit

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(LotteryKit.version, "1.0.0")
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test`
Expected: 构建成功，1 test passed。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): Swift Package 脚手架与冒烟测试"
```

---

### Task 2: 核心枚举与值类型（Category / DataSourceKind / Bet）

**Files:**
- Create: `macapp/Sources/LotteryKit/Models/Category.swift`
- Create: `macapp/Sources/LotteryKit/Models/DataSourceKind.swift`
- Create: `macapp/Sources/LotteryKit/Models/Bet.swift`
- Create: `macapp/Tests/LotteryKitTests/CategoryTests.swift`

**Interfaces:**
- Produces:
  - `enum Category: String, Codable, CaseIterable { case ssq, dlt }`，属性 `displayName`、`frontCount/frontMax/backCount/backMax`。
  - `enum DataSourceKind: String, Codable, CaseIterable { case officialSporttery, officialCWL, webService, manual }`，属性 `displayName`、`category: Category?`（官方源绑定彩种：sporttery→dlt，cwl→ssq；webService/manual→nil）。
  - `struct Bet: Codable, Equatable, Hashable { var front: [Int]; var back: [Int] }`。

- [ ] **Step 1: 写失败测试**

`macapp/Tests/LotteryKitTests/CategoryTests.swift`：
```swift
import XCTest
@testable import LotteryKit

final class CategoryTests: XCTestCase {
    func testCategoryRules() {
        XCTAssertEqual(Category.ssq.frontCount, 6)
        XCTAssertEqual(Category.ssq.frontMax, 33)
        XCTAssertEqual(Category.ssq.backCount, 1)
        XCTAssertEqual(Category.ssq.backMax, 16)
        XCTAssertEqual(Category.dlt.frontCount, 5)
        XCTAssertEqual(Category.dlt.backMax, 12)
    }

    func testSourceCategoryBinding() {
        XCTAssertEqual(DataSourceKind.officialSporttery.category, .dlt)
        XCTAssertEqual(DataSourceKind.officialCWL.category, .ssq)
        XCTAssertNil(DataSourceKind.webService.category)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter CategoryTests`
Expected: 编译失败（类型未定义）。

- [ ] **Step 3: 写 Category.swift**

```swift
public enum Category: String, Codable, CaseIterable, Sendable {
    case ssq, dlt

    public var displayName: String { self == .ssq ? "双色球" : "大乐透" }
    public var frontCount: Int { self == .ssq ? 6 : 5 }
    public var frontMax: Int { self == .ssq ? 33 : 35 }
    public var backCount: Int { self == .ssq ? 1 : 2 }
    public var backMax: Int { self == .ssq ? 16 : 12 }
}
```

- [ ] **Step 4: 写 DataSourceKind.swift**

```swift
public enum DataSourceKind: String, Codable, CaseIterable, Sendable {
    case officialSporttery, officialCWL, webService, manual

    public var displayName: String {
        switch self {
        case .officialSporttery: return "官方·体彩"
        case .officialCWL: return "官方·福彩"
        case .webService: return "Web 服务"
        case .manual: return "手动录入"
        }
    }

    public var category: Category? {
        switch self {
        case .officialSporttery: return .dlt
        case .officialCWL: return .ssq
        case .webService, .manual: return nil
        }
    }
}
```

- [ ] **Step 5: 写 Bet.swift**

```swift
public struct Bet: Codable, Equatable, Hashable, Sendable {
    public var front: [Int]
    public var back: [Int]
    public init(front: [Int], back: [Int]) {
        self.front = front
        self.back = back
    }
}
```

- [ ] **Step 6: 跑测试确认通过**

Run: `cd macapp && swift test --filter CategoryTests`
Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git add macapp
git commit -m "feat(app): 核心枚举 Category/DataSourceKind/Bet"
```

---

### Task 3: 号码校验

**Files:**
- Create: `macapp/Sources/LotteryKit/Logic/NumberValidation.swift`
- Create: `macapp/Tests/LotteryKitTests/NumberValidationTests.swift`

**Interfaces:**
- Consumes: `Category`。
- Produces: `enum NumberValidation { static func validate(category: Category, front: [Int], back: [Int]) -> String? }`（合法返回 `nil`，否则中文错误）。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

final class NumberValidationTests: XCTestCase {
    func testValid() {
        XCTAssertNil(NumberValidation.validate(category: .ssq, front: [1,2,3,4,5,6], back: [16]))
        XCTAssertNil(NumberValidation.validate(category: .dlt, front: [1,2,3,4,35], back: [1,12]))
    }
    func testWrongCount() {
        XCTAssertNotNil(NumberValidation.validate(category: .ssq, front: [1,2,3], back: [16]))
    }
    func testOutOfRange() {
        XCTAssertTrue(NumberValidation.validate(category: .ssq, front: [1,2,3,4,5,34], back: [16])!.contains("33"))
    }
    func testDuplicate() {
        XCTAssertTrue(NumberValidation.validate(category: .ssq, front: [1,2,3,4,5,5], back: [16])!.contains("重复"))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter NumberValidationTests`
Expected: 编译失败（`NumberValidation` 未定义）。

- [ ] **Step 3: 写实现**

```swift
public enum NumberValidation {
    public static func validate(category: Category, front: [Int], back: [Int]) -> String? {
        if let e = check("前区/红球", front, category.frontCount, category.frontMax) { return e }
        if let e = check("后区/蓝球", back, category.backCount, category.backMax) { return e }
        return nil
    }

    private static func check(_ name: String, _ nums: [Int], _ count: Int, _ maxV: Int) -> String? {
        if nums.count != count { return "\(name)必须为 \(count) 个号码" }
        if Set(nums).count != nums.count { return "\(name)不能重复" }
        for n in nums where n < 1 || n > maxV { return "\(name)范围应为 1-\(maxV)" }
        return nil
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test --filter NumberValidationTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): 号码校验"
```

---

### Task 4: 评奖器 — 双色球

**Files:**
- Create: `macapp/Sources/LotteryKit/Logic/PrizeEvaluator.swift`
- Create: `macapp/Tests/LotteryKitTests/PrizeEvaluatorSSQTests.swift`

**Interfaces:**
- Consumes: `Category`、`Bet`。
- Produces:
  - `struct BetResult: Equatable, Codable, Sendable { let tierName: String?; let amount: Int?; let isWin: Bool; let frontMatched: [Int]; let backMatched: [Int] }`（`tierName==nil` 表示未中奖；`amount==nil` 表示浮动奖，需取开奖 prizes）。
  - `enum PrizeEvaluator { static func evaluate(category: Category, bet: Bet, drawFront: [Int], drawBack: [Int], prizes: [String: Int]?) -> BetResult }`。
  - 浮动奖（一/二等）金额：若 `prizes` 含对应奖级名则取之，否则 `amount=nil`。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

final class PrizeEvaluatorSSQTests: XCTestCase {
    let df = [1,2,3,4,5,6]; let db = [16]

    func eval(_ f: [Int], _ b: [Int], prizes: [String:Int]? = nil) -> BetResult {
        PrizeEvaluator.evaluate(category: .ssq, bet: Bet(front: f, back: b), drawFront: df, drawBack: db, prizes: prizes)
    }

    func testFirstPrizeFloating() {
        let r = eval([1,2,3,4,5,6], [16], prizes: ["一等奖": 8000000])
        XCTAssertEqual(r.tierName, "一等奖")
        XCTAssertEqual(r.amount, 8000000)
        XCTAssertTrue(r.isWin)
    }
    func testSecondPrizeNoPrizeData() {
        let r = eval([1,2,3,4,5,6], [9])
        XCTAssertEqual(r.tierName, "二等奖")
        XCTAssertNil(r.amount)
    }
    func testThird() { XCTAssertEqual(eval([1,2,3,4,5,30], [16]).tierName, "三等奖") }
    func testFourthByFiveZero() { XCTAssertEqual(eval([1,2,3,4,5,30], [9]).amount, 200) }
    func testFourthByFourOne() { XCTAssertEqual(eval([1,2,3,4,30,31], [16]).amount, 200) }
    func testFifth() { XCTAssertEqual(eval([1,2,3,4,30,31], [9]).amount, 10) }
    func testSixthBlueOnly() {
        let r = eval([30,31,32,33,28,29], [16])
        XCTAssertEqual(r.tierName, "六等奖")
        XCTAssertEqual(r.amount, 5)
    }
    func testNoWin() {
        let r = eval([30,31,32,33,28,29], [9])
        XCTAssertFalse(r.isWin)
        XCTAssertNil(r.tierName)
    }
    func testMatchedReported() {
        let r = eval([1,2,3,4,5,30], [16])
        XCTAssertEqual(Set(r.frontMatched), Set([1,2,3,4,5]))
        XCTAssertEqual(r.backMatched, [16])
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter PrizeEvaluatorSSQTests`
Expected: 编译失败。

- [ ] **Step 3: 写实现**

```swift
public struct BetResult: Equatable, Codable, Sendable {
    public let tierName: String?
    public let amount: Int?
    public let isWin: Bool
    public let frontMatched: [Int]
    public let backMatched: [Int]
    public init(tierName: String?, amount: Int?, frontMatched: [Int], backMatched: [Int]) {
        self.tierName = tierName
        self.amount = amount
        self.isWin = tierName != nil
        self.frontMatched = frontMatched
        self.backMatched = backMatched
    }
}

public enum PrizeEvaluator {
    public static func evaluate(category: Category, bet: Bet,
                                drawFront: [Int], drawBack: [Int],
                                prizes: [String: Int]?) -> BetResult {
        let fm = bet.front.filter { drawFront.contains($0) }
        let bm = bet.back.filter { drawBack.contains($0) }
        let r = fm.count, b = bm.count
        let (tier, fixed): (String?, Int?) = category == .ssq
            ? ssqTier(r: r, b: b) : dltTier(f: r, k: b)
        let amount: Int?
        if let tier, fixed == nil {        // 浮动奖
            amount = prizes?[tier]
        } else {
            amount = fixed
        }
        return BetResult(tierName: tier, amount: amount, frontMatched: fm, backMatched: bm)
    }

    static func ssqTier(r: Int, b: Int) -> (String?, Int?) {
        switch (r, b) {
        case (6, 1): return ("一等奖", nil)
        case (6, 0): return ("二等奖", nil)
        case (5, 1): return ("三等奖", 3000)
        case (5, 0), (4, 1): return ("四等奖", 200)
        case (4, 0), (3, 1): return ("五等奖", 10)
        case (_, 1) where r <= 2: return ("六等奖", 5)
        default: return (nil, 0)
        }
    }

    static func dltTier(f: Int, k: Int) -> (String?, Int?) {
        switch (f, k) {
        case (5, 2): return ("一等奖", nil)
        case (5, 1): return ("二等奖", nil)
        case (5, 0): return ("三等奖", 10000)
        case (4, 2): return ("四等奖", 3000)
        case (4, 1): return ("五等奖", 300)
        case (3, 2): return ("六等奖", 200)
        case (4, 0): return ("七等奖", 100)
        case (3, 1), (2, 2): return ("八等奖", 15)
        case (3, 0), (2, 1), (1, 2), (0, 2): return ("九等奖", 5)
        default: return (nil, 0)
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test --filter PrizeEvaluatorSSQTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): 评奖器(双色球奖级)"
```

---

### Task 5: 评奖器 — 大乐透（验证 dlt 分支）

**Files:**
- Create: `macapp/Tests/LotteryKitTests/PrizeEvaluatorDLTTests.swift`

**Interfaces:**
- Consumes: `PrizeEvaluator`（Task 4 已实现 `dltTier`）。本任务仅补大乐透测试，确保各奖级正确。

- [ ] **Step 1: 写测试**

```swift
import XCTest
@testable import LotteryKit

final class PrizeEvaluatorDLTTests: XCTestCase {
    let df = [1,2,3,4,5]; let db = [1,2]

    func eval(_ f: [Int], _ b: [Int], prizes: [String:Int]? = nil) -> BetResult {
        PrizeEvaluator.evaluate(category: .dlt, bet: Bet(front: f, back: b), drawFront: df, drawBack: db, prizes: prizes)
    }

    func testFirstFloating() {
        XCTAssertEqual(eval([1,2,3,4,5], [1,2], prizes: ["一等奖": 10000000]).amount, 10000000)
    }
    func testSecondNoData() { XCTAssertNil(eval([1,2,3,4,5], [1,11]).amount) }
    func testThird()  { XCTAssertEqual(eval([1,2,3,4,5], [10,11]).amount, 10000) }
    func testFourth() { XCTAssertEqual(eval([1,2,3,4,30], [1,2]).amount, 3000) }
    func testFifth()  { XCTAssertEqual(eval([1,2,3,4,30], [1,11]).amount, 300) }
    func testSixth()  { XCTAssertEqual(eval([1,2,3,30,31], [1,2]).amount, 200) }
    func testSeventh(){ XCTAssertEqual(eval([1,2,3,4,30], [10,11]).amount, 100) }
    func testEighthByThreeOne() { XCTAssertEqual(eval([1,2,3,30,31], [1,11]).tierName, "八等奖") }
    func testEighthByTwoTwo()   { XCTAssertEqual(eval([1,2,30,31,32], [1,2]).tierName, "八等奖") }
    func testNinth()  { XCTAssertEqual(eval([1,2,30,31,32], [1,11]).amount, 5) }
    func testNoWin()  { XCTAssertFalse(eval([30,31,32,33,34], [10,11]).isWin) }
}
```

- [ ] **Step 2: 跑测试确认通过**

Run: `cd macapp && swift test --filter PrizeEvaluatorDLTTests`
Expected: PASS（dlt 分支已在 Task 4 实现）。

- [ ] **Step 3: 提交**

```bash
git add macapp
git commit -m "test(app): 评奖器大乐透全奖级覆盖"
```

---

### Task 6: SwiftData 模型 + Store（版本/唯一/关系）

**Files:**
- Create: `macapp/Sources/LotteryKit/Models/Entities.swift`
- Create: `macapp/Sources/LotteryKit/Persistence/Store.swift`
- Create: `macapp/Tests/LotteryKitTests/StoreTests.swift`

**Interfaces:**
- Consumes: `Category`、`DataSourceKind`、`Bet`、`BetResult`。
- Produces:
  - `@Model Ticket`（`id, category(String), issue, bets:[Bet], imageFileName:String?, cost:Double, purchaseDate:Date, createdAt; verifications:[VerificationRecord]`）。
  - `@Model VerificationRecord`（`id, createdAt, totalAmount:Int, results:[BetResultSnapshot], ticket:Ticket?, drawVersion:DrawVersion?`）。
  - `struct BetResultSnapshot: Codable`（封装 BetResult + 该注号码）。
  - `@Model Draw`（`id, category, issue, source; versions:[DrawVersion]`）。
  - `@Model DrawVersion`（`id, versionNumber:Int, frontNumbers:[Int], backNumbers:[Int], prizes:[String:Int]?, drawDate:Date?, origin:String, sourceURL:String?, createdAt; draw:Draw?`）。
  - `final class Store`（`init(inMemory: Bool = false) throws`，持 `ModelContext`）方法：
    - `createOrGetDraw(category:issue:source:) -> Draw`（按三元组唯一）。
    - `latestVersion(_ draw: Draw) -> DrawVersion?`。
    - `addVersion(to:front:back:prizes:drawDate:origin:sourceURL:) -> DrawVersion`（versionNumber 自增）。
    - `saveTicket(category:issue:bets:imageFileName:cost:purchaseDate:) -> Ticket`。
    - `addVerification(ticket:drawVersion:results:totalAmount:) -> VerificationRecord`。
    - `allTickets() -> [Ticket]`、`save()`。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

final class StoreTests: XCTestCase {
    func makeStore() throws -> Store { try Store(inMemory: true) }

    func testCreateOrGetDrawIsUniquePerTriple() throws {
        let s = try makeStore()
        let a = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        let b = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        XCTAssertEqual(a.id, b.id)
        let c = s.createOrGetDraw(category: .ssq, issue: "24001", source: .webService)
        XCTAssertNotEqual(a.id, c.id)
    }

    func testVersionNumberAutoIncrementsAndImmutable() throws {
        let s = try makeStore()
        let d = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        let v1 = s.addVersion(to: d, front: [1,2,3,4,5,6], back: [16], prizes: nil, drawDate: nil, origin: "fetched", sourceURL: "https://x")
        let v2 = s.addVersion(to: d, front: [1,2,3,4,5,7], back: [10], prizes: nil, drawDate: nil, origin: "manual", sourceURL: nil)
        XCTAssertEqual(v1.versionNumber, 1)
        XCTAssertEqual(v2.versionNumber, 2)
        XCTAssertEqual(s.latestVersion(d)?.id, v2.id)
        XCTAssertEqual(v1.backNumbers, [16])  // 旧版本不变
    }

    func testTicketAndVerificationRelation() throws {
        let s = try makeStore()
        let t = s.saveTicket(category: .ssq, issue: "24001",
                             bets: [Bet(front: [1,2,3,4,5,6], back: [16])],
                             imageFileName: "a.jpg", cost: 2, purchaseDate: Date())
        let d = s.createOrGetDraw(category: .ssq, issue: "24001", source: .officialCWL)
        let v = s.addVersion(to: d, front: [1,2,3,4,5,6], back: [16], prizes: nil, drawDate: nil, origin: "fetched", sourceURL: nil)
        let snap = BetResultSnapshot(bet: Bet(front: [1,2,3,4,5,6], back: [16]),
                                     result: BetResult(tierName: "一等奖", amount: nil, frontMatched: [1,2,3,4,5,6], backMatched: [16]))
        let rec = s.addVerification(ticket: t, drawVersion: v, results: [snap], totalAmount: 0)
        XCTAssertEqual(t.verifications.count, 1)
        XCTAssertEqual(rec.drawVersion?.id, v.id)
        XCTAssertEqual(s.allTickets().count, 1)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter StoreTests`
Expected: 编译失败。

- [ ] **Step 3: 写 Entities.swift**

```swift
import Foundation
import SwiftData

public struct BetResultSnapshot: Codable, Equatable, Sendable {
    public var bet: Bet
    public var result: BetResult
    public init(bet: Bet, result: BetResult) {
        self.bet = bet
        self.result = result
    }
}

@Model
public final class Ticket {
    @Attribute(.unique) public var id: UUID
    public var category: String
    public var issue: String
    public var bets: [Bet]
    public var imageFileName: String?
    public var cost: Double
    public var purchaseDate: Date
    public var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \VerificationRecord.ticket)
    public var verifications: [VerificationRecord]

    public init(id: UUID = UUID(), category: String, issue: String, bets: [Bet],
                imageFileName: String?, cost: Double, purchaseDate: Date, createdAt: Date = Date()) {
        self.id = id
        self.category = category
        self.issue = issue
        self.bets = bets
        self.imageFileName = imageFileName
        self.cost = cost
        self.purchaseDate = purchaseDate
        self.createdAt = createdAt
        self.verifications = []
    }
}

@Model
public final class VerificationRecord {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var totalAmount: Int
    public var results: [BetResultSnapshot]
    public var ticket: Ticket?
    public var drawVersion: DrawVersion?

    public init(id: UUID = UUID(), createdAt: Date = Date(), totalAmount: Int,
                results: [BetResultSnapshot], ticket: Ticket?, drawVersion: DrawVersion?) {
        self.id = id
        self.createdAt = createdAt
        self.totalAmount = totalAmount
        self.results = results
        self.ticket = ticket
        self.drawVersion = drawVersion
    }
}

@Model
public final class Draw {
    @Attribute(.unique) public var id: UUID
    public var category: String
    public var issue: String
    public var source: String
    @Relationship(deleteRule: .cascade, inverse: \DrawVersion.draw)
    public var versions: [DrawVersion]

    public init(id: UUID = UUID(), category: String, issue: String, source: String) {
        self.id = id
        self.category = category
        self.issue = issue
        self.source = source
        self.versions = []
    }
}

@Model
public final class DrawVersion {
    @Attribute(.unique) public var id: UUID
    public var versionNumber: Int
    public var frontNumbers: [Int]
    public var backNumbers: [Int]
    public var prizes: [String: Int]?
    public var drawDate: Date?
    public var origin: String
    public var sourceURL: String?
    public var createdAt: Date
    public var draw: Draw?

    public init(id: UUID = UUID(), versionNumber: Int, frontNumbers: [Int], backNumbers: [Int],
                prizes: [String: Int]?, drawDate: Date?, origin: String, sourceURL: String?,
                createdAt: Date = Date(), draw: Draw?) {
        self.id = id
        self.versionNumber = versionNumber
        self.frontNumbers = frontNumbers
        self.backNumbers = backNumbers
        self.prizes = prizes
        self.drawDate = drawDate
        self.origin = origin
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.draw = draw
    }
}
```

- [ ] **Step 4: 写 Store.swift**

```swift
import Foundation
import SwiftData

public final class Store {
    public let container: ModelContainer
    public var context: ModelContext { container.mainContext }

    public init(inMemory: Bool = false) throws {
        let schema = Schema([Ticket.self, VerificationRecord.self, Draw.self, DrawVersion.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: schema, configurations: [config])
    }

    public func save() { try? context.save() }

    public func createOrGetDraw(category: Category, issue: String, source: DataSourceKind) -> Draw {
        let cat = category.rawValue, src = source.rawValue
        let predicate = #Predicate<Draw> { $0.category == cat && $0.issue == issue && $0.source == src }
        if let found = try? context.fetch(FetchDescriptor<Draw>(predicate: predicate)).first {
            return found
        }
        let draw = Draw(category: cat, issue: issue, source: src)
        context.insert(draw)
        save()
        return draw
    }

    public func latestVersion(_ draw: Draw) -> DrawVersion? {
        draw.versions.max(by: { $0.versionNumber < $1.versionNumber })
    }

    @discardableResult
    public func addVersion(to draw: Draw, front: [Int], back: [Int], prizes: [String: Int]?,
                           drawDate: Date?, origin: String, sourceURL: String?) -> DrawVersion {
        let next = (latestVersion(draw)?.versionNumber ?? 0) + 1
        let v = DrawVersion(versionNumber: next, frontNumbers: front, backNumbers: back,
                            prizes: prizes, drawDate: drawDate, origin: origin, sourceURL: sourceURL, draw: draw)
        context.insert(v)
        draw.versions.append(v)
        save()
        return v
    }

    @discardableResult
    public func saveTicket(category: Category, issue: String, bets: [Bet],
                           imageFileName: String?, cost: Double, purchaseDate: Date) -> Ticket {
        let t = Ticket(category: category.rawValue, issue: issue, bets: bets,
                       imageFileName: imageFileName, cost: cost, purchaseDate: purchaseDate)
        context.insert(t)
        save()
        return t
    }

    @discardableResult
    public func addVerification(ticket: Ticket, drawVersion: DrawVersion,
                                results: [BetResultSnapshot], totalAmount: Int) -> VerificationRecord {
        let rec = VerificationRecord(totalAmount: totalAmount, results: results,
                                     ticket: ticket, drawVersion: drawVersion)
        context.insert(rec)
        ticket.verifications.append(rec)
        save()
        return rec
    }

    public func allTickets() -> [Ticket] {
        let descriptor = FetchDescriptor<Ticket>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
```

- [ ] **Step 5: 跑测试确认通过**

Run: `cd macapp && swift test --filter StoreTests`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add macapp
git commit -m "feat(app): SwiftData 实体与 Store(版本/唯一/关系)"
```

---

### Task 7: ImageStore（原图落盘）

**Files:**
- Create: `macapp/Sources/LotteryKit/Persistence/ImageStore.swift`
- Create: `macapp/Tests/LotteryKitTests/ImageStoreTests.swift`

**Interfaces:**
- Produces: `final class ImageStore`（`init(directory: URL? = nil)`，默认 Application Support 下 `LotteryChecker/images`）：
  - `func save(_ data: Data, ext: String = "jpg") throws -> String`（返回文件名）。
  - `func load(_ fileName: String) -> Data?`。
  - `func url(for fileName: String) -> URL`。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

final class ImageStoreTests: XCTestCase {
    func testSaveAndLoadRoundtrip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ImageStore(directory: tmp)
        let data = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01])
        let name = try store.save(data, ext: "jpg")
        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertEqual(store.load(name), data)
        XCTAssertNil(store.load("missing.jpg"))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter ImageStoreTests`
Expected: 编译失败。

- [ ] **Step 3: 写实现**

```swift
import Foundation

public final class ImageStore {
    private let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("LotteryChecker/images", isDirectory: true)
        }
    }

    private func ensureDir() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    public func save(_ data: Data, ext: String = "jpg") throws -> String {
        try ensureDir()
        let name = "\(UUID().uuidString).\(ext)"
        try data.write(to: url(for: name))
        return name
    }

    public func load(_ fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test --filter ImageStoreTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): ImageStore 原图落盘"
```

---

### Task 8: DrawResult + 数据源协议 + 三个解析器

**Files:**
- Create: `macapp/Sources/LotteryKit/DataSources/DrawResult.swift`
- Create: `macapp/Sources/LotteryKit/DataSources/SportteryDataSource.swift`
- Create: `macapp/Sources/LotteryKit/DataSources/CWLDataSource.swift`
- Create: `macapp/Sources/LotteryKit/DataSources/WebServiceDataSource.swift`
- Create: `macapp/Tests/LotteryKitTests/DataSourceParsingTests.swift`

**Interfaces:**
- Consumes: `Category`、`DataSourceKind`。
- Produces:
  - `struct DrawResult: Equatable, Sendable { category, issue, frontNumbers, backNumbers, drawDate:Date?, prizes:[String:Int]?, source:DataSourceKind, sourceURL:String? }`。
  - `protocol DrawDataSource { var kind: DataSourceKind { get }; func fetchDraw(category: Category, issue: String) async throws -> DrawResult }`。
  - `enum DrawSourceError: Error { case notFound, badResponse(String) }`。
  - `SportteryDataSource`（dlt）、`CWLDataSource`（ssq）、`WebServiceDataSource`（baseURL+token），每个含 `static func parse(...) throws -> DrawResult`（纯，可单测）+ `fetchDraw`（HTTP）。

> 说明：官方接口返回结构按编写时已知格式实现；线上若变动，调整对应 `parse` 即可（fetch 层手动联调）。

- [ ] **Step 1: 写解析失败测试**

```swift
import XCTest
@testable import LotteryKit

final class DataSourceParsingTests: XCTestCase {
    func testSportteryParse() throws {
        let json = """
        {"value":{"list":[{"lotteryDrawNum":"24001","lotteryDrawResult":"05 12 18 25 33 04 11","lotteryDrawTime":"2024-01-01","prizeLevelList":[{"prizeLevel":"一等奖","stakeAmount":"10000000"},{"prizeLevel":"二等奖","stakeAmount":"200000"}]}]}}
        """.data(using: .utf8)!
        let r = try SportteryDataSource.parse(json, issue: "24001")
        XCTAssertEqual(r.frontNumbers, [5,12,18,25,33])
        XCTAssertEqual(r.backNumbers, [4,11])
        XCTAssertEqual(r.prizes?["一等奖"], 10000000)
        XCTAssertEqual(r.source, .officialSporttery)
    }

    func testCWLParse() throws {
        let json = """
        {"result":[{"code":"24001","red":"01,02,03,04,05,06","blue":"16","date":"2024-01-01(日)","prizegrades":[{"type":1,"typemoney":"8000000"},{"type":2,"typemoney":"200000"}]}]}
        """.data(using: .utf8)!
        let r = try CWLDataSource.parse(json, issue: "24001")
        XCTAssertEqual(r.frontNumbers, [1,2,3,4,5,6])
        XCTAssertEqual(r.backNumbers, [16])
        XCTAssertEqual(r.prizes?["一等奖"], 8000000)
        XCTAssertEqual(r.source, .officialCWL)
    }

    func testWebServiceParse() throws {
        let json = """
        {"category":"ssq","issue":"24001","frontNumbers":[1,2,3,4,5,6],"backNumbers":[16],"drawDate":"2024-01-01","prizes":{"一等奖":5000000}}
        """.data(using: .utf8)!
        let r = try WebServiceDataSource.parse(json, baseURL: "http://h:8080")
        XCTAssertEqual(r.backNumbers, [16])
        XCTAssertEqual(r.prizes?["一等奖"], 5000000)
        XCTAssertEqual(r.source, .webService)
        XCTAssertEqual(r.sourceURL, "http://h:8080/api/v1/draws/ssq/24001")
    }

    func testSportteryNotFound() {
        let json = "{\\"value\\":{\\"list\\":[]}}".data(using: .utf8)!
        XCTAssertThrowsError(try SportteryDataSource.parse(json, issue: "x"))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter DataSourceParsingTests`
Expected: 编译失败。

- [ ] **Step 3: 写 DrawResult.swift**

```swift
import Foundation

public struct DrawResult: Equatable, Sendable {
    public let category: Category
    public let issue: String
    public let frontNumbers: [Int]
    public let backNumbers: [Int]
    public let drawDate: Date?
    public let prizes: [String: Int]?
    public let source: DataSourceKind
    public let sourceURL: String?

    public init(category: Category, issue: String, frontNumbers: [Int], backNumbers: [Int],
                drawDate: Date?, prizes: [String: Int]?, source: DataSourceKind, sourceURL: String?) {
        self.category = category
        self.issue = issue
        self.frontNumbers = frontNumbers
        self.backNumbers = backNumbers
        self.drawDate = drawDate
        self.prizes = prizes
        self.source = source
        self.sourceURL = sourceURL
    }
}

public enum DrawSourceError: Error, Equatable {
    case notFound
    case badResponse(String)
}

public protocol DrawDataSource: Sendable {
    var kind: DataSourceKind { get }
    func fetchDraw(category: Category, issue: String) async throws -> DrawResult
}

enum NumParse {
    static func ints(_ s: String, separators: CharacterSet) -> [Int] {
        s.components(separatedBy: separators).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    static func date(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }
}
```

- [ ] **Step 4: 写 SportteryDataSource.swift**

```swift
import Foundation

public struct SportteryDataSource: DrawDataSource {
    public let kind: DataSourceKind = .officialSporttery
    public init() {}

    static func endpoint(issue: String) -> URL {
        URL(string: "https://webapi.sporttery.cn/gateway/lottery/getHistoryPageListV1.qry?gameNo=85&provinceId=0&pageSize=30&isVerify=1&pageNo=1")!
    }
    static func pageURL(issue: String) -> String {
        "https://www.sporttery.cn/kj/kjgg/"
    }

    public static func parse(_ data: Data, issue: String) throws -> DrawResult {
        struct Resp: Decodable {
            struct Value: Decodable { let list: [Item] }
            struct Item: Decodable {
                let lotteryDrawNum: String
                let lotteryDrawResult: String
                let lotteryDrawTime: String?
                let prizeLevelList: [Prize]?
            }
            struct Prize: Decodable { let prizeLevel: String; let stakeAmount: String? }
            let value: Value
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let item = resp.value.list.first(where: { $0.lotteryDrawNum == issue }) ?? resp.value.list.first else {
            throw DrawSourceError.notFound
        }
        let nums = NumParse.ints(item.lotteryDrawResult, separators: .whitespaces)
        guard nums.count == 7 else { throw DrawSourceError.badResponse("号码个数异常") }
        var prizes: [String: Int] = [:]
        for p in item.prizeLevelList ?? [] {
            if let a = p.stakeAmount, let v = Int(a.replacingOccurrences(of: ",", with: "")) { prizes[p.prizeLevel] = v }
        }
        return DrawResult(category: .dlt, issue: item.lotteryDrawNum,
                          frontNumbers: Array(nums.prefix(5)), backNumbers: Array(nums.suffix(2)),
                          drawDate: item.lotteryDrawTime.flatMap(NumParse.date),
                          prizes: prizes.isEmpty ? nil : prizes,
                          source: .officialSporttery, sourceURL: pageURL(issue: issue))
    }

    public func fetchDraw(category: Category, issue: String) async throws -> DrawResult {
        var req = URLRequest(url: Self.endpoint(issue: issue))
        req.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        req.setValue("https://static.sporttery.cn/", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try Self.parse(data, issue: issue)
    }
}
```

- [ ] **Step 5: 写 CWLDataSource.swift**

```swift
import Foundation

public struct CWLDataSource: DrawDataSource {
    public let kind: DataSourceKind = .officialCWL
    public init() {}

    static let tierNames = [1: "一等奖", 2: "二等奖", 3: "三等奖", 4: "四等奖", 5: "五等奖", 6: "六等奖"]
    static func endpoint(issue: String) -> URL {
        URL(string: "http://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice?name=ssq&issueStart=\(issue)&issueEnd=\(issue)&pageNo=1&pageSize=10&systemType=PC")!
    }
    static func pageURL(issue: String) -> String { "http://www.cwl.gov.cn/kjxx/ssq/kjgg/" }

    public static func parse(_ data: Data, issue: String) throws -> DrawResult {
        struct Resp: Decodable {
            struct Item: Decodable {
                let code: String; let red: String; let blue: String
                let date: String?; let prizegrades: [Grade]?
            }
            struct Grade: Decodable { let type: Int; let typemoney: String? }
            let result: [Item]
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let item = resp.result.first(where: { $0.code == issue }) ?? resp.result.first else {
            throw DrawSourceError.notFound
        }
        let front = NumParse.ints(item.red, separators: CharacterSet(charactersIn: ", "))
        let back = NumParse.ints(item.blue, separators: CharacterSet(charactersIn: ", "))
        guard front.count == 6, back.count == 1 else { throw DrawSourceError.badResponse("号码个数异常") }
        var prizes: [String: Int] = [:]
        for g in item.prizegrades ?? [] {
            if let name = tierNames[g.type], let m = g.typemoney, let v = Int(m.replacingOccurrences(of: ",", with: "")) {
                prizes[name] = v
            }
        }
        return DrawResult(category: .ssq, issue: item.code, frontNumbers: front, backNumbers: back,
                          drawDate: item.date.flatMap(NumParse.date),
                          prizes: prizes.isEmpty ? nil : prizes,
                          source: .officialCWL, sourceURL: pageURL(issue: issue))
    }

    public func fetchDraw(category: Category, issue: String) async throws -> DrawResult {
        var req = URLRequest(url: Self.endpoint(issue: issue))
        req.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        req.setValue("http://www.cwl.gov.cn/", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try Self.parse(data, issue: issue)
    }
}
```

- [ ] **Step 6: 写 WebServiceDataSource.swift**

```swift
import Foundation

public struct WebServiceDataSource: DrawDataSource {
    public let kind: DataSourceKind = .webService
    public let baseURL: String
    public let token: String
    public init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    static func path(category: Category, issue: String) -> String {
        "/api/v1/draws/\(category.rawValue)/\(issue)"
    }

    public static func parse(_ data: Data, baseURL: String) throws -> DrawResult {
        struct Resp: Decodable {
            let category: String; let issue: String
            let frontNumbers: [Int]; let backNumbers: [Int]
            let drawDate: String?; let prizes: [String: Int]?
        }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        guard let cat = Category(rawValue: r.category) else { throw DrawSourceError.badResponse("未知彩种") }
        let url = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path(category: cat, issue: r.issue)
        return DrawResult(category: cat, issue: r.issue, frontNumbers: r.frontNumbers, backNumbers: r.backNumbers,
                          drawDate: r.drawDate.flatMap(NumParse.date), prizes: r.prizes,
                          source: .webService, sourceURL: url)
    }

    public func fetchDraw(category: Category, issue: String) async throws -> DrawResult {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + Self.path(category: category, issue: issue)) else {
            throw DrawSourceError.badResponse("无效 Base URL")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { throw DrawSourceError.notFound }
        return try Self.parse(data, baseURL: baseURL)
    }
}
```

- [ ] **Step 7: 跑测试确认通过**

Run: `cd macapp && swift test --filter DataSourceParsingTests`
Expected: PASS（注意测试调用 `WebServiceDataSource.parse(json, baseURL:)` 与 `Sporttery/CWL.parse(json, issue:)`）。

- [ ] **Step 8: 提交**

```bash
git add macapp
git commit -m "feat(app): 数据源协议与体彩/福彩/Web服务解析+抓取"
```

---

### Task 9: DrawFetchService（缓存优先编排）

**Files:**
- Create: `macapp/Sources/LotteryKit/DataSources/DrawFetchService.swift`
- Create: `macapp/Tests/LotteryKitTests/DrawFetchServiceTests.swift`

**Interfaces:**
- Consumes: `Store`、`DrawDataSource`、`DrawResult`、`DataSourceKind`、`DrawVersion`。
- Produces: `final class DrawFetchService`：
  - `init(store: Store, sources: [DataSourceKind: DrawDataSource])`。
  - `func cachedLatest(category:issue:source:) -> DrawVersion?`（仅查库，命中返回最新版本）。
  - `func fetch(category:issue:source:forceRefresh:) async throws -> DrawVersion`（缓存优先；未命中或 forceRefresh 时联网；号码与最新版本不同则新增版本，相同则返回最新版本）。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

private struct FakeSource: DrawDataSource {
    let kind: DataSourceKind
    let result: DrawResult
    func fetchDraw(category: Category, issue: String) async throws -> DrawResult { result }
}

final class DrawFetchServiceTests: XCTestCase {
    func makeResult(_ back: [Int]) -> DrawResult {
        DrawResult(category: .ssq, issue: "24001", frontNumbers: [1,2,3,4,5,6], backNumbers: back,
                   drawDate: nil, prizes: nil, source: .webService, sourceURL: "u")
    }

    func testFetchCreatesV1ThenCacheHit() async throws {
        let store = try Store(inMemory: true)
        let svc = DrawFetchService(store: store, sources: [.webService: FakeSource(kind: .webService, result: makeResult([16]))])
        let v1 = try await svc.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: false)
        XCTAssertEqual(v1.versionNumber, 1)
        XCTAssertNotNil(svc.cachedLatest(category: .ssq, issue: "24001", source: .webService))
        let again = try await svc.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: false)
        XCTAssertEqual(again.id, v1.id)  // 缓存命中, 不新增
    }

    func testForceRefreshAddsVersionWhenNumbersChange() async throws {
        let store = try Store(inMemory: true)
        let svc = DrawFetchService(store: store, sources: [.webService: FakeSource(kind: .webService, result: makeResult([16]))])
        _ = try await svc.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: false)
        let svc2 = DrawFetchService(store: store, sources: [.webService: FakeSource(kind: .webService, result: makeResult([10]))])
        let v2 = try await svc2.fetch(category: .ssq, issue: "24001", source: .webService, forceRefresh: true)
        XCTAssertEqual(v2.versionNumber, 2)
        XCTAssertEqual(v2.backNumbers, [10])
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter DrawFetchServiceTests`
Expected: 编译失败。

- [ ] **Step 3: 写实现**

```swift
import Foundation

public final class DrawFetchService {
    private let store: Store
    private let sources: [DataSourceKind: DrawDataSource]

    public init(store: Store, sources: [DataSourceKind: DrawDataSource]) {
        self.store = store
        self.sources = sources
    }

    public func cachedLatest(category: Category, issue: String, source: DataSourceKind) -> DrawVersion? {
        let cat = category.rawValue, src = source.rawValue
        let predicate = #Predicate<Draw> { $0.category == cat && $0.issue == issue && $0.source == src }
        guard let draw = try? store.context.fetch(FetchDescriptor<Draw>(predicate: predicate)).first else { return nil }
        return store.latestVersion(draw)
    }

    public func fetch(category: Category, issue: String, source: DataSourceKind,
                      forceRefresh: Bool) async throws -> DrawVersion {
        if !forceRefresh, let cached = cachedLatest(category: category, issue: issue, source: source) {
            return cached
        }
        guard let ds = sources[source] else { throw DrawSourceError.badResponse("数据源未配置: \(source.displayName)") }
        let result = try await ds.fetchDraw(category: category, issue: issue)
        let draw = store.createOrGetDraw(category: category, issue: issue, source: source)
        if let latest = store.latestVersion(draw),
           latest.frontNumbers == result.frontNumbers, latest.backNumbers == result.backNumbers {
            return latest
        }
        return store.addVersion(to: draw, front: result.frontNumbers, back: result.backNumbers,
                                prizes: result.prizes, drawDate: result.drawDate,
                                origin: "fetched", sourceURL: result.sourceURL)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test --filter DrawFetchServiceTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): DrawFetchService 缓存优先编排"
```

---

### Task 10: VisionRecognizer（OpenAI 兼容 识别）

**Files:**
- Create: `macapp/Sources/LotteryKit/Recognition/VisionRecognizer.swift`
- Create: `macapp/Tests/LotteryKitTests/VisionRecognizerTests.swift`

**Interfaces:**
- Consumes: `Category`、`Bet`。
- Produces:
  - `struct RecognizedTicket: Equatable, Sendable { let category: Category; let issue: String; let bets: [Bet] }`。
  - `protocol VisionRecognizer { func recognize(imageData: Data) async throws -> RecognizedTicket }`。
  - `enum RecognizerError: Error { case notConfigured, badOutput(String) }`。
  - `struct OpenAIVisionRecognizer: VisionRecognizer`（baseURL/apiKey/model）；含 `static func parseContent(_ content: String) throws -> RecognizedTicket`（从模型返回的 JSON 文本解析，容忍 ```json 包裹）。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

final class VisionRecognizerTests: XCTestCase {
    func testParsePlainJSON() throws {
        let content = #"{"category":"ssq","issue":"24001","bets":[{"front":[1,2,3,4,5,6],"back":[16]}]}"#
        let t = try OpenAIVisionRecognizer.parseContent(content)
        XCTAssertEqual(t.category, .ssq)
        XCTAssertEqual(t.issue, "24001")
        XCTAssertEqual(t.bets, [Bet(front: [1,2,3,4,5,6], back: [16])])
    }

    func testParseFencedJSON() throws {
        let content = "```json\n{\"category\":\"dlt\",\"issue\":\"24002\",\"bets\":[{\"front\":[1,2,3,4,5],\"back\":[1,2]}]}\n```"
        let t = try OpenAIVisionRecognizer.parseContent(content)
        XCTAssertEqual(t.category, .dlt)
        XCTAssertEqual(t.bets.first?.back, [1,2])
    }

    func testBadOutputThrows() {
        XCTAssertThrowsError(try OpenAIVisionRecognizer.parseContent("抱歉我无法识别"))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter VisionRecognizerTests`
Expected: 编译失败。

- [ ] **Step 3: 写实现**

```swift
import Foundation

public struct RecognizedTicket: Equatable, Sendable {
    public let category: Category
    public let issue: String
    public let bets: [Bet]
    public init(category: Category, issue: String, bets: [Bet]) {
        self.category = category
        self.issue = issue
        self.bets = bets
    }
}

public enum RecognizerError: Error, Equatable {
    case notConfigured
    case badOutput(String)
}

public protocol VisionRecognizer: Sendable {
    func recognize(imageData: Data) async throws -> RecognizedTicket
}

public struct OpenAIVisionRecognizer: VisionRecognizer {
    public let baseURL: String
    public let apiKey: String
    public let model: String
    public init(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    static let prompt = """
    你是彩票识别助手。识别图片中的中国福利彩票双色球(ssq)或体育彩票大乐透(dlt)。\
    只输出严格 JSON，不要任何解释或代码块标记，格式：\
    {"category":"ssq|dlt","issue":"期号","bets":[{"front":[红球/前区数字],"back":[蓝球/后区数字]}]}。\
    双色球 front 为6个红球(1-33) back 为1个蓝球(1-16)；大乐透 front 为5个前区(1-35) back 为2个后区(1-12)。
    """

    public static func parseContent(_ content: String) throws -> RecognizedTicket {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw RecognizerError.badOutput(content)
        }
        let jsonStr = String(text[start...end])
        struct Raw: Decodable {
            let category: String; let issue: String
            struct B: Decodable { let front: [Int]; let back: [Int] }
            let bets: [B]
        }
        guard let data = jsonStr.data(using: .utf8),
              let raw = try? JSONDecoder().decode(Raw.self, from: data),
              let cat = Category(rawValue: raw.category) else {
            throw RecognizerError.badOutput(content)
        }
        return RecognizedTicket(category: cat, issue: raw.issue,
                                bets: raw.bets.map { Bet(front: $0.front, back: $0.back) })
    }

    public func recognize(imageData: Data) async throws -> RecognizedTicket {
        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else { throw RecognizerError.notConfigured }
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else { throw RecognizerError.notConfigured }
        let b64 = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": Self.prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]],
                ],
            ]],
            "temperature": 0,
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        struct ChatResp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        guard let resp = try? JSONDecoder().decode(ChatResp.self, from: data),
              let content = resp.choices.first?.message.content else {
            throw RecognizerError.badOutput(String(data: data, encoding: .utf8) ?? "无响应")
        }
        return try Self.parseContent(content)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test --filter VisionRecognizerTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): OpenAI 兼容视觉识别(请求构造+JSON解析)"
```

---

### Task 11: AppSettings（配置读写）

**Files:**
- Create: `macapp/Sources/LotteryKit/Settings/AppSettings.swift`
- Create: `macapp/Tests/LotteryKitTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: `DataSourceKind`。
- Produces: `final class AppSettings`（`init(defaults: UserDefaults)`）：可读写属性 `modelBaseURL, modelAPIKey, modelName, webServiceBaseURL, webServiceToken, webServiceEnabled: Bool, sourcePriority: [DataSourceKind]`（持久化到 UserDefaults）。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

final class AppSettingsTests: XCTestCase {
    func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return d
    }

    func testRoundtrip() {
        let d = makeDefaults()
        let s = AppSettings(defaults: d)
        s.modelBaseURL = "https://api.x.com/v1"
        s.modelName = "gpt-4o"
        s.webServiceEnabled = true
        s.sourcePriority = [.webService, .officialCWL]
        let s2 = AppSettings(defaults: d)
        XCTAssertEqual(s2.modelBaseURL, "https://api.x.com/v1")
        XCTAssertEqual(s2.modelName, "gpt-4o")
        XCTAssertTrue(s2.webServiceEnabled)
        XCTAssertEqual(s2.sourcePriority, [.webService, .officialCWL])
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter AppSettingsTests`
Expected: 编译失败。

- [ ] **Step 3: 写实现**

```swift
import Foundation

public final class AppSettings {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func str(_ key: String) -> String { defaults.string(forKey: key) ?? "" }

    public var modelBaseURL: String {
        get { str("modelBaseURL") } set { defaults.set(newValue, forKey: "modelBaseURL") }
    }
    public var modelAPIKey: String {
        get { str("modelAPIKey") } set { defaults.set(newValue, forKey: "modelAPIKey") }
    }
    public var modelName: String {
        get { str("modelName") } set { defaults.set(newValue, forKey: "modelName") }
    }
    public var webServiceBaseURL: String {
        get { str("webServiceBaseURL") } set { defaults.set(newValue, forKey: "webServiceBaseURL") }
    }
    public var webServiceToken: String {
        get { str("webServiceToken") } set { defaults.set(newValue, forKey: "webServiceToken") }
    }
    public var webServiceEnabled: Bool {
        get { defaults.bool(forKey: "webServiceEnabled") } set { defaults.set(newValue, forKey: "webServiceEnabled") }
    }
    public var sourcePriority: [DataSourceKind] {
        get {
            guard let arr = defaults.array(forKey: "sourcePriority") as? [String] else {
                return [.officialSporttery, .officialCWL, .webService, .manual]
            }
            return arr.compactMap { DataSourceKind(rawValue: $0) }
        }
        set { defaults.set(newValue.map(\.rawValue), forKey: "sourcePriority") }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test --filter AppSettingsTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): AppSettings 配置读写"
```

---

### Task 12: StatsService（统计聚合）

**Files:**
- Create: `macapp/Sources/LotteryKit/Logic/StatsService.swift`
- Create: `macapp/Tests/LotteryKitTests/StatsServiceTests.swift`

**Interfaces:**
- Consumes: `Ticket`、`VerificationRecord`、`Category`。
- Produces:
  - `struct TicketStat: Sendable { let ticket: Ticket; let latest: VerificationRecord? }`。
  - `struct StatsSummary: Equatable, Sendable { let totalCost: Double; let totalWin: Int; let net: Double; let winRate: Double; let ticketCount: Int }`。
  - `enum StatsService`：
    - `static func latestVerifications(_ tickets: [Ticket]) -> [TicketStat]`（每票取 createdAt 最新的验奖记录）。
    - `static func summary(_ stats: [TicketStat]) -> StatsSummary`。
    - `static func purchasesByDay(_ tickets: [Ticket]) -> [Date: Int]`（按日历日 startOfDay 计数）。
    - `static func countByCategory(_ tickets: [Ticket]) -> [Category: Int]`。
    - `static func myNumberFrequency(_ tickets: [Ticket], category: Category) -> [Int: Int]`（前区号码计数）。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import LotteryKit

final class StatsServiceTests: XCTestCase {
    func makeTicket(_ store: Store, win: Int?, cost: Double, day: Date, cat: Category = .ssq) -> Ticket {
        let t = store.saveTicket(category: cat, issue: "x", bets: [Bet(front: [1,2,3,4,5,6], back: [16])],
                                 imageFileName: nil, cost: cost, purchaseDate: day)
        if let win {
            let d = store.createOrGetDraw(category: cat, issue: "x", source: .manual)
            let v = store.addVersion(to: d, front: [1,2,3,4,5,6], back: [16], prizes: nil, drawDate: nil, origin: "manual", sourceURL: nil)
            let tier = win > 0 ? "三等奖" : nil
            let snap = BetResultSnapshot(bet: t.bets[0], result: BetResult(tierName: tier, amount: win, frontMatched: [], backMatched: []))
            _ = store.addVerification(ticket: t, drawVersion: v, results: [snap], totalAmount: win)
        }
        return t
    }

    func testSummary() throws {
        let store = try Store(inMemory: true)
        _ = makeTicket(store, win: 3000, cost: 2, day: Date())
        _ = makeTicket(store, win: 0, cost: 2, day: Date())
        _ = makeTicket(store, win: nil, cost: 2, day: Date())
        let stats = StatsService.latestVerifications(store.allTickets())
        let sum = StatsService.summary(stats)
        XCTAssertEqual(sum.ticketCount, 3)
        XCTAssertEqual(sum.totalCost, 6)
        XCTAssertEqual(sum.totalWin, 3000)
        XCTAssertEqual(sum.net, 2994)
        XCTAssertEqual(sum.winRate, 1.0/3.0, accuracy: 0.001)
    }

    func testFrequency() throws {
        let store = try Store(inMemory: true)
        _ = makeTicket(store, win: nil, cost: 2, day: Date())
        let freq = StatsService.myNumberFrequency(store.allTickets(), category: .ssq)
        XCTAssertEqual(freq[1], 1)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd macapp && swift test --filter StatsServiceTests`
Expected: 编译失败。

- [ ] **Step 3: 写实现**

```swift
import Foundation

public struct TicketStat: Sendable {
    public let ticket: Ticket
    public let latest: VerificationRecord?
}

public struct StatsSummary: Equatable, Sendable {
    public let totalCost: Double
    public let totalWin: Int
    public let net: Double
    public let winRate: Double
    public let ticketCount: Int
}

public enum StatsService {
    public static func latestVerifications(_ tickets: [Ticket]) -> [TicketStat] {
        tickets.map { t in
            TicketStat(ticket: t, latest: t.verifications.max(by: { $0.createdAt < $1.createdAt }))
        }
    }

    public static func summary(_ stats: [TicketStat]) -> StatsSummary {
        let totalCost = stats.reduce(0.0) { $0 + $1.ticket.cost }
        let totalWin = stats.reduce(0) { $0 + ($1.latest?.totalAmount ?? 0) }
        let wins = stats.filter { ($0.latest?.totalAmount ?? 0) > 0 }.count
        let count = stats.count
        return StatsSummary(totalCost: totalCost, totalWin: totalWin,
                            net: Double(totalWin) - totalCost,
                            winRate: count == 0 ? 0 : Double(wins) / Double(count),
                            ticketCount: count)
    }

    public static func purchasesByDay(_ tickets: [Ticket]) -> [Date: Int] {
        var out: [Date: Int] = [:]
        let cal = Calendar.current
        for t in tickets {
            let day = cal.startOfDay(for: t.purchaseDate)
            out[day, default: 0] += 1
        }
        return out
    }

    public static func countByCategory(_ tickets: [Ticket]) -> [Category: Int] {
        var out: [Category: Int] = [:]
        for t in tickets {
            if let c = Category(rawValue: t.category) { out[c, default: 0] += 1 }
        }
        return out
    }

    public static func myNumberFrequency(_ tickets: [Ticket], category: Category) -> [Int: Int] {
        var out: [Int: Int] = [:]
        for t in tickets where t.category == category.rawValue {
            for bet in t.bets {
                for n in bet.front { out[n, default: 0] += 1 }
            }
        }
        return out
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd macapp && swift test --filter StatsServiceTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add macapp
git commit -m "feat(app): StatsService 统计聚合"
```

---

### Task 13: App 装配 + 侧边栏导航骨架

**Files:**
- Create: `macapp/Sources/LotteryChecker/AppModel.swift`
- Create: `macapp/Sources/LotteryChecker/Views/NumberBadges.swift`
- Modify: `macapp/Sources/LotteryChecker/LotteryCheckerApp.swift`

**Interfaces:**
- Consumes: `LotteryKit`（Store/AppSettings/DrawFetchService/各数据源/OpenAIVisionRecognizer）。
- Produces: `@MainActor final class AppModel: ObservableObject`（持有 `store, settings, fetchService, recognizer`；`rebuildServices()` 依据 settings 重建数据源字典与 recognizer）；`NumberBadges` 视图（展示一组号码，可标记命中）；`LotteryCheckerApp` 用 `NavigationSplitView` 在 6 个侧边栏项间切换（先放占位 Text，后续任务填充）。

- [ ] **Step 1: 写 AppModel.swift**

```swift
import SwiftUI
import LotteryKit

@MainActor
final class AppModel: ObservableObject {
    let store: Store
    let settings: AppSettings
    @Published private(set) var fetchService: DrawFetchService
    @Published private(set) var recognizer: VisionRecognizer

    init() {
        // 失败则用内存库兜底，保证 app 可启动
        let s = (try? Store()) ?? (try! Store(inMemory: true))
        self.store = s
        let cfg = AppSettings()
        self.settings = cfg
        self.fetchService = AppModel.makeFetch(store: s, settings: cfg)
        self.recognizer = AppModel.makeRecognizer(settings: cfg)
    }

    static func makeFetch(store: Store, settings: AppSettings) -> DrawFetchService {
        var sources: [DataSourceKind: DrawDataSource] = [
            .officialSporttery: SportteryDataSource(),
            .officialCWL: CWLDataSource(),
        ]
        if settings.webServiceEnabled, !settings.webServiceBaseURL.isEmpty {
            sources[.webService] = WebServiceDataSource(baseURL: settings.webServiceBaseURL, token: settings.webServiceToken)
        }
        return DrawFetchService(store: store, sources: sources)
    }

    static func makeRecognizer(settings: AppSettings) -> VisionRecognizer {
        OpenAIVisionRecognizer(baseURL: settings.modelBaseURL, apiKey: settings.modelAPIKey, model: settings.modelName)
    }

    func rebuildServices() {
        fetchService = AppModel.makeFetch(store: store, settings: settings)
        recognizer = AppModel.makeRecognizer(settings: settings)
    }

    /// 当前可用于验奖的数据源（含手动）。
    func availableSources(for category: Category) -> [DataSourceKind] {
        settings.sourcePriority.filter { kind in
            switch kind {
            case .officialSporttery: return category == .dlt
            case .officialCWL: return category == .ssq
            case .webService: return settings.webServiceEnabled && !settings.webServiceBaseURL.isEmpty
            case .manual: return true
            }
        }
    }
}
```

- [ ] **Step 2: 写 NumberBadges.swift**

```swift
import SwiftUI

struct NumberBadges: View {
    let numbers: [Int]
    var matched: Set<Int> = []
    var color: Color = .red

    var body: some View {
        HStack(spacing: 6) {
            ForEach(numbers, id: \.self) { n in
                Text(String(format: "%02d", n))
                    .font(.system(.body, design: .rounded)).bold()
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(matched.contains(n) ? color : Color.gray.opacity(0.25)))
                    .foregroundStyle(matched.contains(n) ? .white : .primary)
            }
        }
    }
}
```

- [ ] **Step 3: 写导航骨架（LotteryCheckerApp.swift）**

```swift
import SwiftUI
import LotteryKit

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "首页"
    case verify = "验奖"
    case tickets = "彩票列表"
    case results = "验奖结果总览"
    case stats = "统计"
    case settings = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .verify: return "doc.viewfinder"
        case .tickets: return "list.bullet.rectangle"
        case .results: return "checkmark.seal"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

@main
struct LotteryCheckerApp: App {
    @StateObject private var model = AppModel()
    @State private var selection: SidebarItem = .dashboard

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $selection) { item in
                    Label(item.rawValue, systemImage: item.icon).tag(item)
                }
                .navigationSplitViewColumnWidth(200)
            } detail: {
                NavigationStack {
                    switch selection {
                    case .dashboard: DashboardView()
                    case .verify: VerifyView()
                    case .tickets: TicketListView()
                    case .results: ResultsOverviewView()
                    case .stats: StatsView()
                    case .settings: SettingsView()
                    }
                }
            }
            .environmentObject(model)
            .frame(minWidth: 900, minHeight: 600)
        }
    }
}
```

- [ ] **Step 4: 加占位视图保证编译**

在 `macapp/Sources/LotteryChecker/Views/` 下创建占位（后续任务替换为完整实现）：
`DashboardView.swift`、`VerifyView.swift`、`TicketListView.swift`、`ResultsOverviewView.swift`、`StatsView.swift`、`SettingsView.swift`，每个内容：
```swift
import SwiftUI

struct DashboardView: View {  // 文件名对应改 VerifyView/TicketListView/ResultsOverviewView/StatsView/SettingsView
    var body: some View { Text("DashboardView").padding() }
}
```
（六个文件分别命名其结构体；`TicketDetailView`/`DrawVersionSheet` 在 Task 15 创建。）

- [ ] **Step 5: 构建确认通过**

Run: `cd macapp && swift build`
Expected: 构建成功（可执行 target 编译通过）。

- [ ] **Step 6: 提交**

```bash
git add macapp
git commit -m "feat(app): App 装配与侧边栏导航骨架"
```

---

### Task 14: 验奖流程页（上传→识别→确认→选源→验奖）

**Files:**
- Modify: `macapp/Sources/LotteryChecker/Views/VerifyView.swift`

**Interfaces:**
- Consumes: `AppModel`、`NumberValidation`、`PrizeEvaluator`、`DrawFetchService`、`OpenAIVisionRecognizer`、`ImageStore`、`NumberBadges`。
- Produces: 完整 `VerifyView`：选图（NSOpenPanel）→ 调 recognizer → 可编辑表单（彩种/期数/各注号码字符串）→ 选数据源 → 验奖：存 Ticket(含原图) + fetch DrawVersion + PrizeEvaluator + 存 VerificationRecord，并展示结果。

- [ ] **Step 1: 写完整 VerifyView**

```swift
import SwiftUI
import AppKit
import LotteryKit

struct VerifyView: View {
    @EnvironmentObject var model: AppModel
    @State private var imageData: Data?
    @State private var category: Category = .ssq
    @State private var issue = ""
    @State private var frontText = ""
    @State private var backText = ""
    @State private var selectedSource: DataSourceKind = .officialCWL
    @State private var status = ""
    @State private var busy = false
    @State private var resultRecordID: UUID?

    private let imageStore = ImageStore()

    var body: some View {
        Form {
            Section("彩票图片") {
                if let imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage).resizable().scaledToFit().frame(maxHeight: 180)
                }
                Button("选择图片…") { pickImage() }
                Button("识别") { Task { await recognize() } }
                    .disabled(imageData == nil || busy)
            }
            Section("确认（可编辑）") {
                Picker("彩种", selection: $category) {
                    ForEach(Category.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                TextField("期数", text: $issue)
                TextField("前区/红球（空格分隔）", text: $frontText)
                TextField("后区/蓝球（空格分隔）", text: $backText)
                Picker("数据源", selection: $selectedSource) {
                    ForEach(model.availableSources(for: category), id: \.self) { Text($0.displayName).tag($0) }
                }
                Button("复式/胆拖（开发中）") {}.disabled(true)
            }
            if !status.isEmpty {
                Text(status).foregroundStyle(status.hasPrefix("错误") ? .red : .secondary)
            }
            Button("验奖") { Task { await verify() } }
                .disabled(busy)
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: category) { _, newValue in
            selectedSource = model.availableSources(for: newValue).first ?? .manual
        }
    }

    private func parseNums(_ s: String) -> [Int] {
        s.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Int($0) }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            imageData = try? Data(contentsOf: url)
            status = ""
        }
    }

    private func recognize() async {
        guard let imageData else { return }
        busy = true; status = "识别中…"
        defer { busy = false }
        do {
            let t = try await model.recognizer.recognize(imageData: imageData)
            category = t.category
            issue = t.issue
            frontText = (t.bets.first?.front ?? []).map(String.init).joined(separator: " ")
            backText = (t.bets.first?.back ?? []).map(String.init).joined(separator: " ")
            selectedSource = model.availableSources(for: t.category).first ?? .manual
            status = "识别完成，请核对"
        } catch RecognizerError.notConfigured {
            status = "错误：请先在设置中配置模型"
        } catch {
            status = "错误：识别失败 \(error.localizedDescription)"
        }
    }

    private func verify() async {
        let front = parseNums(frontText), back = parseNums(backText)
        if let err = NumberValidation.validate(category: category, front: front, back: back) {
            status = "错误：\(err)"; return
        }
        guard !issue.isEmpty else { status = "错误：请填写期数"; return }
        busy = true; status = "验奖中…"
        defer { busy = false }
        do {
            var fileName: String?
            if let imageData { fileName = try? imageStore.save(imageData) }
            let bet = Bet(front: front, back: back)
            let ticket = model.store.saveTicket(category: category, issue: issue, bets: [bet],
                                                imageFileName: fileName, cost: 2, purchaseDate: Date())
            let version = try await model.fetchService.fetch(category: category, issue: issue,
                                                             source: selectedSource, forceRefresh: false)
            let r = PrizeEvaluator.evaluate(category: category, bet: bet,
                                            drawFront: version.frontNumbers, drawBack: version.backNumbers,
                                            prizes: version.prizes)
            let snap = BetResultSnapshot(bet: bet, result: r)
            _ = model.store.addVerification(ticket: ticket, drawVersion: version,
                                            results: [snap], totalAmount: r.amount ?? 0)
            status = r.isWin ? "中奖：\(r.tierName ?? "")（\(r.amount.map { "¥\($0)" } ?? "金额以官方为准")）"
                             : "未中奖"
        } catch DrawSourceError.notFound {
            status = "错误：该期未开奖或不存在"
        } catch {
            status = "错误：\(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: 构建确认通过**

Run: `cd macapp && swift build`
Expected: 构建成功。

- [ ] **Step 3: 手动运行冒烟（人工）**

Run: `cd macapp && swift run LotteryChecker`
Expected: 出现窗口，进入「验奖」页可选图、填表单、点按钮（未配模型时识别提示去设置；选「手动」源验奖会因无手动数据提示该期不存在——属预期，后续可在开奖版本浮层手动录入）。关闭窗口结束。

- [ ] **Step 4: 提交**

```bash
git add macapp
git commit -m "feat(app): 验奖流程页(识别/确认/选源/验奖)"
```

---

### Task 15: 彩票列表 + 详情 + 再次验奖 + 开奖版本浮层

**Files:**
- Modify: `macapp/Sources/LotteryChecker/Views/TicketListView.swift`
- Create: `macapp/Sources/LotteryChecker/Views/TicketDetailView.swift`
- Create: `macapp/Sources/LotteryChecker/Views/DrawVersionSheet.swift`

**Interfaces:**
- Consumes: `AppModel`、`Store`、`ImageStore`、`PrizeEvaluator`、`NumberBadges`、`NumberValidation`。
- Produces:
  - `TicketListView`：列出所有 Ticket，`NavigationLink` 进入 `TicketDetailView`。
  - `TicketDetailView`：显示原图/号码 + 全部验奖记录（来源+版本+奖级+金额+时间）；「换数据源再次验奖」「刷新某源重验」；每条记录可打开 `DrawVersionSheet`。
  - `DrawVersionSheet`：展示某 Draw 的版本历史（origin/可点击 sourceURL）；「手动新增/修改」生成新版本（origin=manual）；选某版本对该票重验。

- [ ] **Step 1: 写 TicketListView.swift**

```swift
import SwiftUI
import LotteryKit

struct TicketListView: View {
    @EnvironmentObject var model: AppModel
    @State private var tickets: [Ticket] = []

    var body: some View {
        List(tickets, id: \.id) { t in
            NavigationLink(value: t.id) {
                VStack(alignment: .leading) {
                    Text("[\(Category(rawValue: t.category)?.displayName ?? t.category)] 第 \(t.issue) 期").bold()
                    let latest = t.verifications.max(by: { $0.createdAt < $1.createdAt })
                    Text(latest.map { $0.totalAmount > 0 ? "最近：中奖 ¥\($0.totalAmount)" : "最近：未中奖/待确认" } ?? "未验奖")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("彩票列表")
        .navigationDestination(for: UUID.self) { id in
            if let t = tickets.first(where: { $0.id == id }) { TicketDetailView(ticket: t) }
        }
        .onAppear { tickets = model.store.allTickets() }
    }
}
```

- [ ] **Step 2: 写 TicketDetailView.swift**

```swift
import SwiftUI
import AppKit
import LotteryKit

struct TicketDetailView: View {
    @EnvironmentObject var model: AppModel
    let ticket: Ticket
    @State private var refreshToken = 0
    @State private var sheetDraw: Draw?
    @State private var status = ""
    private let imageStore = ImageStore()

    private var category: Category { Category(rawValue: ticket.category) ?? .ssq }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let name = ticket.imageFileName, let data = imageStore.load(name), let img = NSImage(data: data) {
                    Image(nsImage: img).resizable().scaledToFit().frame(maxHeight: 200)
                }
                ForEach(Array(ticket.bets.enumerated()), id: \.offset) { _, bet in
                    HStack { NumberBadges(numbers: bet.front, color: .red); NumberBadges(numbers: bet.back, color: .blue) }
                }
                Divider()
                HStack {
                    Text("再次验奖：").bold()
                    ForEach(model.availableSources(for: category), id: \.self) { src in
                        Button(src.displayName) { Task { await reverify(source: src, force: false) } }
                    }
                }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
                Divider()
                Text("验奖记录").font(.headline)
                ForEach(ticket.verifications.sorted(by: { $0.createdAt > $1.createdAt }), id: \.id) { rec in
                    verificationRow(rec)
                }
            }
            .padding()
            .id(refreshToken)
        }
        .navigationTitle("第 \(ticket.issue) 期")
        .sheet(item: $sheetDraw) { draw in
            DrawVersionSheet(draw: draw, ticket: ticket) { refreshToken += 1 }
                .environmentObject(model)
        }
    }

    @ViewBuilder private func verificationRow(_ rec: VerificationRecord) -> some View {
        let srcName = rec.drawVersion?.draw.map { DataSourceKind(rawValue: $0.source)?.displayName ?? $0.source } ?? "—"
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(srcName).font(.caption).padding(4).background(.quaternary).clipShape(Capsule())
                Text("v\(rec.drawVersion?.versionNumber ?? 0)").font(.caption)
                Spacer()
                Text(rec.totalAmount > 0 ? "¥\(rec.totalAmount)" : (rec.results.contains { $0.result.isWin } ? "中奖(金额以官方为准)" : "未中奖"))
                    .foregroundStyle(rec.results.contains { $0.result.isWin } ? .green : .secondary)
            }
            ForEach(Array(rec.results.enumerated()), id: \.offset) { _, snap in
                Text(snap.result.tierName.map { "\($0)" } ?? "未中奖").font(.caption2)
            }
            if let draw = rec.drawVersion?.draw {
                Button("查看/管理该期开奖版本") { sheetDraw = draw }.font(.caption)
            }
        }
        .padding(8).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func reverify(source: DataSourceKind, force: Bool) async {
        status = "验奖中…"
        do {
            let version = try await model.fetchService.fetch(category: category, issue: ticket.issue,
                                                             source: source, forceRefresh: force)
            var total = 0; var snaps: [BetResultSnapshot] = []
            for bet in ticket.bets {
                let r = PrizeEvaluator.evaluate(category: category, bet: bet,
                                                drawFront: version.frontNumbers, drawBack: version.backNumbers,
                                                prizes: version.prizes)
                total += r.amount ?? 0
                snaps.append(BetResultSnapshot(bet: bet, result: r))
            }
            _ = model.store.addVerification(ticket: ticket, drawVersion: version, results: snaps, totalAmount: total)
            refreshToken += 1
            status = "已追加验奖记录（\(source.displayName)）"
        } catch DrawSourceError.notFound {
            status = "该期未开奖或不存在"
        } catch {
            status = "错误：\(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 3: 写 DrawVersionSheet.swift**

```swift
import SwiftUI
import AppKit
import LotteryKit

struct DrawVersionSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let draw: Draw
    let ticket: Ticket
    var onChange: () -> Void

    @State private var frontText = ""
    @State private var backText = ""
    @State private var status = ""

    private var category: Category { Category(rawValue: draw.category) ?? .ssq }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("开奖版本 · \(category.displayName) 第 \(draw.issue) 期 · \(DataSourceKind(rawValue: draw.source)?.displayName ?? draw.source)")
                .font(.headline)
            List(draw.versions.sorted(by: { $0.versionNumber > $1.versionNumber }), id: \.id) { v in
                VStack(alignment: .leading) {
                    HStack {
                        Text("v\(v.versionNumber)").bold()
                        Text(v.origin == "fetched" ? "抓取" : "手动").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("用此版本重验") { Task { await reverify(with: v) } }.font(.caption)
                    }
                    HStack { NumberBadges(numbers: v.frontNumbers, color: .red); NumberBadges(numbers: v.backNumbers, color: .blue) }
                    if let urlStr = v.sourceURL, let url = URL(string: urlStr) {
                        Link("来源页", destination: url).font(.caption)
                    }
                }
            }
            .frame(minHeight: 180)
            Divider()
            Text("手动新增/修改版本").font(.subheadline)
            TextField("前区/红球（空格分隔）", text: $frontText)
            TextField("后区/蓝球（空格分隔）", text: $backText)
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("保存为新版本") { addManualVersion() }
                Spacer()
                Button("关闭") { dismiss() }
            }
        }
        .padding()
        .frame(width: 460)
    }

    private func parseNums(_ s: String) -> [Int] {
        s.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Int($0) }
    }

    private func addManualVersion() {
        let front = parseNums(frontText), back = parseNums(backText)
        if let err = NumberValidation.validate(category: category, front: front, back: back) {
            status = err; return
        }
        _ = model.store.addVersion(to: draw, front: front, back: back, prizes: nil,
                                   drawDate: nil, origin: "manual", sourceURL: nil)
        frontText = ""; backText = ""; status = ""
        onChange()
    }

    private func reverify(with v: DrawVersion) async {
        var total = 0; var snaps: [BetResultSnapshot] = []
        for bet in ticket.bets {
            let r = PrizeEvaluator.evaluate(category: category, bet: bet,
                                            drawFront: v.frontNumbers, drawBack: v.backNumbers, prizes: v.prizes)
            total += r.amount ?? 0
            snaps.append(BetResultSnapshot(bet: bet, result: r))
        }
        _ = model.store.addVerification(ticket: ticket, drawVersion: v, results: snaps, totalAmount: total)
        onChange()
        dismiss()
    }
}
```

- [ ] **Step 4: 让 Draw 可用于 sheet(item:)**

`Draw` 是 `@Model`（`PersistentModel` 已 `Identifiable`，`id` 为持久化 `id` 字段），可直接用于 `.sheet(item:)`。构建确认：

Run: `cd macapp && swift build`
Expected: 构建成功。

- [ ] **Step 5: 手动运行冒烟（人工）**

Run: `cd macapp && swift run LotteryChecker`
Expected: 「彩票列表」显示已验奖票；点进详情见原图/号码/验奖记录；打开开奖版本浮层可手动新增版本并「用此版本重验」，详情页验奖记录随之增加。关闭窗口结束。

- [ ] **Step 6: 提交**

```bash
git add macapp
git commit -m "feat(app): 彩票列表/详情/再次验奖/开奖版本浮层"
```

---

### Task 16: 验奖结果总览 + 统计页（Swift Charts）+ 首页 Dashboard

**Files:**
- Modify: `macapp/Sources/LotteryChecker/Views/ResultsOverviewView.swift`
- Modify: `macapp/Sources/LotteryChecker/Views/StatsView.swift`
- Modify: `macapp/Sources/LotteryChecker/Views/DashboardView.swift`

**Interfaces:**
- Consumes: `AppModel`、`StatsService`、`Charts`。
- Produces:
  - `ResultsOverviewView`：每票一行展示最新验奖结果（中奖状态/金额/来源/时间），可按彩种筛选。
  - `StatsView`：关键数字 + 彩种占比饼图 + 按日购买柱状图 + 我的号码频率柱状图（Swift Charts）。
  - `DashboardView`：关键数字卡片 + 最近彩票 + 快捷入口说明。

- [ ] **Step 1: 写 ResultsOverviewView.swift**

```swift
import SwiftUI
import LotteryKit

struct ResultsOverviewView: View {
    @EnvironmentObject var model: AppModel
    @State private var stats: [TicketStat] = []
    @State private var filter: String = "all"

    var filtered: [TicketStat] {
        filter == "all" ? stats : stats.filter { $0.ticket.category == filter }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Picker("彩种", selection: $filter) {
                Text("全部").tag("all")
                Text("双色球").tag("ssq")
                Text("大乐透").tag("dlt")
            }.pickerStyle(.segmented).frame(maxWidth: 300)
            Table(filtered, columns: {
                TableColumn("彩种") { s in Text(Category(rawValue: s.ticket.category)?.displayName ?? "") }
                TableColumn("期数") { s in Text(s.ticket.issue) }
                TableColumn("最新结果") { s in
                    let amt = s.latest?.totalAmount ?? 0
                    let win = s.latest?.results.contains { $0.result.isWin } ?? false
                    Text(s.latest == nil ? "未验奖" : (amt > 0 ? "中奖 ¥\(amt)" : (win ? "中奖(待定金额)" : "未中奖")))
                        .foregroundStyle(win ? .green : .secondary)
                }
                TableColumn("来源") { s in
                    Text(s.latest?.drawVersion?.draw.map { DataSourceKind(rawValue: $0.source)?.displayName ?? "" } ?? "—")
                }
            })
        }
        .padding()
        .navigationTitle("验奖结果总览")
        .onAppear { stats = StatsService.latestVerifications(model.store.allTickets()) }
    }
}
```

- [ ] **Step 2: 写 StatsView.swift**

```swift
import SwiftUI
import Charts
import LotteryKit

struct StatsView: View {
    @EnvironmentObject var model: AppModel
    @State private var tickets: [Ticket] = []

    private var summary: StatsSummary { StatsService.summary(StatsService.latestVerifications(tickets)) }
    private var byCategory: [(String, Int)] {
        StatsService.countByCategory(tickets).map { ($0.key.displayName, $0.value) }
    }
    private var byDay: [(Date, Int)] {
        StatsService.purchasesByDay(tickets).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    private var freq: [(Int, Int)] {
        StatsService.myNumberFrequency(tickets, category: .ssq).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    statCard("累计投入", String(format: "¥%.0f", summary.totalCost))
                    statCard("累计中奖", "¥\(summary.totalWin)")
                    statCard("净盈亏", String(format: "¥%.0f", summary.net))
                    statCard("中奖率", String(format: "%.0f%%", summary.winRate * 100))
                }
                groupBox("彩种占比") {
                    Chart(byCategory, id: \.0) { item in
                        SectorMark(angle: .value("数量", item.1), innerRadius: .ratio(0.5))
                            .foregroundStyle(by: .value("彩种", item.0))
                    }.frame(height: 200)
                }
                groupBox("按日购买量") {
                    Chart(byDay, id: \.0) { item in
                        BarMark(x: .value("日期", item.0, unit: .day), y: .value("张数", item.1))
                    }.frame(height: 200)
                }
                groupBox("我的常选红球频率（双色球）") {
                    Chart(freq, id: \.0) { item in
                        BarMark(x: .value("号码", String(item.0)), y: .value("次数", item.1))
                    }.frame(height: 200)
                }
            }.padding()
        }
        .navigationTitle("统计")
        .onAppear { tickets = model.store.allTickets() }
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2).bold() }
            .frame(maxWidth: .infinity).padding().background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func groupBox<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading) { Text(title).font(.headline); content() }
    }
}
```

- [ ] **Step 3: 写 DashboardView.swift**

```swift
import SwiftUI
import LotteryKit

struct DashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var tickets: [Ticket] = []
    private var summary: StatsSummary { StatsService.summary(StatsService.latestVerifications(tickets)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("概览").font(.title2).bold()
                HStack(spacing: 16) {
                    card("累计投入", String(format: "¥%.0f", summary.totalCost))
                    card("累计中奖", "¥\(summary.totalWin)")
                    card("净盈亏", String(format: "¥%.0f", summary.net))
                    card("中奖率", String(format: "%.0f%%", summary.winRate * 100))
                }
                Text("最近彩票").font(.headline)
                ForEach(tickets.prefix(5), id: \.id) { t in
                    HStack {
                        Text("[\(Category(rawValue: t.category)?.displayName ?? "")] 第 \(t.issue) 期")
                        Spacer()
                        let amt = t.verifications.max(by: { $0.createdAt < $1.createdAt })?.totalAmount ?? 0
                        Text(amt > 0 ? "¥\(amt)" : "—").foregroundStyle(.secondary)
                    }.padding(8).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text("快捷操作：左侧「验奖」上传识别；「统计」查看图表；在彩票详情可换源再验或手动改开奖。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        .navigationTitle("首页")
        .onAppear { tickets = model.store.allTickets() }
    }

    private func card(_ title: String, _ value: String) -> some View {
        VStack { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3).bold() }
            .frame(maxWidth: .infinity).padding().background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 4: 构建确认通过**

Run: `cd macapp && swift build`
Expected: 构建成功。

- [ ] **Step 5: 手动运行冒烟（人工）**

Run: `cd macapp && swift run LotteryChecker`
Expected: 首页见数字卡片与最近彩票；总览页表格显示每票最新结果；统计页渲染饼图/柱状图（无数据时图为空但不崩）。关闭窗口结束。

- [ ] **Step 6: 提交**

```bash
git add macapp
git commit -m "feat(app): 验奖结果总览/统计页(Swift Charts)/首页Dashboard"
```

---

### Task 17: 设置页

**Files:**
- Modify: `macapp/Sources/LotteryChecker/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `AppModel`、`AppSettings`。
- Produces: `SettingsView`：编辑模型 Base URL / API Key / 模型名；Web 服务 Base URL / Token / 启用开关；保存后调用 `model.rebuildServices()` 使配置生效。

- [ ] **Step 1: 写 SettingsView.swift**

```swift
import SwiftUI
import LotteryKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var modelBaseURL = ""
    @State private var modelAPIKey = ""
    @State private var modelName = ""
    @State private var wsBaseURL = ""
    @State private var wsToken = ""
    @State private var wsEnabled = false
    @State private var saved = false

    var body: some View {
        Form {
            Section("视觉模型（OpenAI 兼容）") {
                TextField("Base URL（如 https://api.openai.com/v1）", text: $modelBaseURL)
                SecureField("API Key", text: $modelAPIKey)
                TextField("模型名（如 gpt-4o）", text: $modelName)
            }
            Section("Web 服务数据源") {
                Toggle("启用 Web 服务数据源", isOn: $wsEnabled)
                TextField("Base URL（如 http://host:8080）", text: $wsBaseURL)
                SecureField("共享 Token", text: $wsToken)
            }
            Button("保存") { save() }
            if saved { Text("已保存").foregroundStyle(.green) }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("设置")
        .onAppear { load() }
    }

    private func load() {
        let s = model.settings
        modelBaseURL = s.modelBaseURL; modelAPIKey = s.modelAPIKey; modelName = s.modelName
        wsBaseURL = s.webServiceBaseURL; wsToken = s.webServiceToken; wsEnabled = s.webServiceEnabled
    }

    private func save() {
        let s = model.settings
        s.modelBaseURL = modelBaseURL; s.modelAPIKey = modelAPIKey; s.modelName = modelName
        s.webServiceBaseURL = wsBaseURL; s.webServiceToken = wsToken; s.webServiceEnabled = wsEnabled
        model.rebuildServices()
        saved = true
    }
}
```

- [ ] **Step 2: 构建 + 全量测试确认通过**

Run: `cd macapp && swift build && swift test`
Expected: 构建成功；全部单测 PASS。

- [ ] **Step 3: 手动运行冒烟（人工）**

Run: `cd macapp && swift run LotteryChecker`
Expected: 设置页可填模型与 Web 服务配置，保存后「验奖」页识别与 Web 数据源可用。关闭窗口结束。

- [ ] **Step 4: 提交**

```bash
git add macapp
git commit -m "feat(app): 设置页(模型/Web服务配置)"
```

---

## Self-Review

**1. Spec coverage（对照 `2026-06-23-lottery-checker-design.md`）**
- 原生 SwiftUI + 本地 SwiftData/iCloud-ready（ModelConfiguration，CloudKit 默认关闭）→ Task 1/6 ✓
- OpenAI 兼容识别 + 严格 JSON 解析 + 可编辑确认 → Task 10/14 ✓
- 单式评奖（双色球/大乐透全奖级，浮动取 prizes）→ Task 4/5；复式/胆拖入口标「开发中」→ Task 14 ✓
- 以彩票为中心、一票多验奖、Draw 按(彩种+期数+源)唯一、DrawVersion 不可变版本、origin fetched/manual、sourceURL 可点击 → Task 6/8/9/15 ✓
- 验奖记录引用具体版本 + 结果快照 → Task 6/14/15 ✓
- 数据源：体彩/福彩/Web 服务，可插拔、缓存优先、可刷新新增版本、优先级可配 → Task 8/9/11/13 ✓
- 原图入库（文件落盘，DB 存文件名）→ Task 7/14/15 ✓
- 首页 Dashboard / 验奖结果总览 / 统计页（日历→按日购买柱状图 + 盈亏/购买/中奖/号码，Swift Charts）→ Task 16 ✓
- 成本 注数×¥2、cost 字段 → Task 6/14 ✓
- 设置页（模型 + Web 服务 + 启用 + 重建服务）→ Task 17；数据源优先级存储 → Task 11（UI 完整编辑可后续增强，优先级已有默认与持久化）✓
- 导航：侧边栏 6 项 + 彩票详情为 push 目的页 + 开奖版本浮层 → Task 13/15 ✓
- 测试：评奖/校验/Store 版本与关系/数据源解析/缓存编排/识别解析/统计/设置 → Task 2-12 单测 ✓
- 错误处理：模型未配置、识别失败、号码非法、未开奖、网络失败 → Task 14/15 提示 ✓

**2. Placeholder scan**：除 Task 13 Step 4 明确的「占位视图，后续任务替换」（属脚手架，后续任务给出完整实现）外，无 TBD/TODO；逻辑任务均含完整代码、命令与预期。

**3. Type consistency**：
- `Category`/`DataSourceKind`/`Bet`（Task 2）贯穿全程；`BetResult`（Task 4）被 Store 快照（Task 6）、评奖（Task 4/5）、UI（14/15）一致使用。
- `DrawResult`/`DrawDataSource`（Task 8）被 `DrawFetchService`（Task 9）与 `AppModel`（Task 13）一致消费；各 `parse` 签名与测试一致（`Sporttery/CWL.parse(_:issue:)`、`WebService.parse(_:baseURL:)`）。
- `Store` 方法签名（Task 6）被 14/15/16 调用一致：`saveTicket/createOrGetDraw/addVersion/latestVersion/addVerification/allTickets`。
- `RecognizedTicket`/`VisionRecognizer`（Task 10）被 14 消费；`OpenAIVisionRecognizer.parseContent` 测试与实现一致。
- `AppSettings` 属性（Task 11）被 `AppModel`（13）与 `SettingsView`（17）一致读写。
- `StatsService` API（Task 12）被 16 消费一致（`latestVerifications/summary/purchasesByDay/countByCategory/myNumberFrequency`）。

**已知风险（spec 已记录）**：官方接口（体彩 567 反爬 / 福彩 403 WAF + 地域）线上结构或可达性可能与样例不同——解析器有单测保障结构，`fetchDraw` 需在用户本机联网联调，必要时按真实响应微调对应 `parse`。

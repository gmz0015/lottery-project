# 彩票验奖 Mac App（LotteryChecker）设计文档

日期：2026-06-23
状态：已与用户确认，待进入实现计划
相关：配套 Web 服务见 `2026-06-23-lottery-webservice-design.md`（含共享 API 契约）

## 1. 目标

一个原生 macOS app：用户上传/拖入彩票照片 → 用视觉大模型识别彩种与号码 →
用户在可编辑表单核对 → 自动从官方网站拉取对应期开奖号码 → 验奖并展示结果。
已查询过的期数缓存进本地数据库，可浏览历史、支持「立即查询」，命中缓存则不再爬取。
上传的彩票（含原图）入库成列表，每张票可用多个数据源多次验奖、保存多条验奖记录；
开奖记录按数据源带版本（首版抓取、后续手动修改），验奖记录精确引用所用版本。

## 2. 关键决策（已确认）

- **技术栈**：原生 SwiftUI macOS app（Xcode / Swift）。
- **模型协议**：OpenAI 兼容 `/chat/completions`（多模态）。用户在设置中填 Base URL / API Key / 模型名，模型自行配置。
- **玩法范围**：先实现**单式**验奖；复式、胆拖在 UI 留入口，点击提示「开发中」。
- **识别确认**：识别后填入**可编辑确认表单**，用户核对/修改后再验奖（防误读）。
- **数据存储**：**本地 SwiftData，iCloud-ready**。代码按可升级 CloudKit 的方式写，
  日后配置付费开发者账号 + CloudKit 容器即可开启每用户私有 iCloud 同步，无需改业务逻辑。
- **以彩票为中心**：上传并确认后即保存为一张 `Ticket`，并立即选一种数据源做首次验奖。
  彩票列表展示所有上传的票；点进可看其全部验奖记录，并可选不同数据源**再次验奖**（一张票多条验奖记录），
  避免单一数据源不准导致结论错误。
- **开奖记录带版本**：`Draw` 按 **(彩种, 期数, 数据源)** 唯一，其下挂多个 **`DrawVersion`**：
  每个版本带 `origin`（`fetched` 数据源抓取 / `manual` 手动新增或修改）。
  v1 通常由数据源抓取得到（origin=fetched）；若是你手动新增的开奖（source=manual），v1 即手动录入（origin=manual）。
  **版本不可变，修改即新增版本**，保留完整历史。
- **抓取版本记录来源 URL**：`fetched` 版本同步保存 `sourceURL`（优先人类可读结果页，否则请求 URL），
  在 UI 中可点击，调用系统默认浏览器打开对应页面；`manual` 版本无 URL。
- **验奖记录引用具体版本**：每条验奖记录精确指向所用的 `DrawVersion`，
  因而记录了「用哪个数据源的哪个版本」+ 号码快照 + 结果。手动改源后旧记录仍指旧版本，重验才生成对新版本的新记录。
- **数据来源标识**：`source` 字段：`officialSporttery`(体彩) / `officialCWL`(福彩) / `webService`(自建 Web 服务) / `manual`(手动录入)。
- **新增数据源**：除官方接口外，新增可配置的 **Web 服务数据源**（见配套 Web 服务 spec）。
- **首页 Dashboard**：进入即见快捷操作 + 关键数字卡片 + 近期动态 + 迷你图表。
- **验奖结果总览页**：平铺所有彩票，每张默认展示其**最新一条验奖记录**，可按中奖状态/彩种/时间筛选排序。
- **统计页**：日历视图（哪天买了什么）+ 四组统计（盈亏 / 购买习惯 / 中奖 / 号码），用原生 **Swift Charts** 可视化。
- **成本口径**：单式每注 ¥2；`Ticket` 存可覆盖的 `cost` 字段，投入 = 注数 × ¥2 默认算出。

## 3. 总体架构

```
UI 层 (SwiftUI Views)
  侧边栏导航项：
  ├─ 首页 Dashboard：快捷操作 + 关键数字卡片 + 近期动态 + 迷你图表
  ├─ 验奖流程：拖拽/选择图片 → 识别中 → 可编辑确认表单 → 选数据源 → 验奖结果
  ├─ 彩票列表页：所有上传彩票
  ├─ 验奖结果总览页：所有彩票的最新验奖结果速览（筛选/排序）
  ├─ 统计页：日历视图 + 盈亏/购买/中奖/号码 四组图表（Swift Charts）
  └─ 设置页
  导航目的页/浮层（不在侧边栏）：
  ├─ 彩票详情页：从彩票列表点击进入（NavigationStack push），带返回/面包屑；原图/号码 + 多条验奖记录 + 再次验奖
  └─ 开奖版本浮层(sheet)：版本历史 + 手动新增/修改，从彩票详情或「立即查询」打开
应用层 (ViewModels / 状态机)
组件层（互不依赖，各有明确接口，可独立测试）：
  ├─ VisionRecognizer   识别彩票图片 → 结构化结果
  ├─ DrawDataSource     按彩种+期数+源拉取开奖数据（可插拔，缓存优先，多源）
  ├─ PrizeEvaluator     纯函数：投注号码 + 开奖号码 → 中奖等级/金额
  ├─ StatsService       纯函数：聚合 Ticket/验奖/开奖 → Dashboard 与统计页所需指标
  ├─ Store              SwiftData 持久层（Ticket / VerificationRecord / Draw / DrawVersion / 图片）
  └─ SettingsStore      模型配置 + Web 服务数据源配置 持久化
```

## 4. 组件设计

### 4.1 VisionRecognizer（识别）
- 协议 OpenAI 兼容 `/chat/completions`，消息含图片（base64 data URL）+ 提示词。
- 提示词要求模型**只输出严格 JSON**：
  ```json
  { "category": "dlt|ssq", "issue": "24001",
    "bets": [ { "front": [1,2,3,4,5], "back": [10,11] } ] }
  ```
  - 双色球(ssq)：front = 红球 6 个（1–33），back = 蓝球 1 个（1–16）。
  - 大乐透(dlt)：front = 前区 5 个（1–35），back = 后区 2 个（1–12）。
- 解析 JSON，做范围/个数基础校验；解析失败给清晰错误信息（含模型原始返回，便于排查）。
- 接口：`func recognize(imageData: Data) async throws -> RecognizedTicket`

### 4.2 DrawDataSource（开奖数据，可插拔 + 缓存优先）
- 接口：`func fetchDraw(category:, issue:) async throws -> DrawResult`
  返回开奖号码 + 各奖级奖金（一/二等奖浮动金额直接取官方返回值）+ 开奖日期 + source + **sourceURL**。
  - 每个实现给出 `sourceURL`：优先该期人类可读结果页（如官方开奖公告页/Web 服务详情页），否则用实际请求 URL。
- **缓存优先策略（按数据源隔离）**：验奖时针对**选定的数据源**先查 `Draw(category, issue, source)`，
  命中则用其**最新版本**（不再联网）；未命中才联网抓取，成功后建 `Draw` + `DrawVersion` v1(origin=fetched)。
  - 列表/详情可手动「刷新」强制重新抓取该源 → 若号码与最新版本不同则记为新版本。
  - 验奖始终基于具体 `DrawVersion`，验奖记录保存该版本引用。
- 内置实现（按设置中选定的优先级尝试）：
  - `SportteryDataSource`（大乐透官方）：`webapi.sporttery.cn`，带 User-Agent / Referer。
  - `CWLDataSource`（双色球官方）：`www.cwl.gov.cn`，带 UA / Referer，
    先 GET 首页预热拿 Cookie，失败重试。
  - `WebServiceDataSource`（自建 Web 服务）：调用配套 Web 服务 API
    `GET /api/v1/draws/{category}/{issue}`，带共享 Token。
    Base URL 与 Token 在设置中配置；命中后 `source = webService`。
- 每个实现返回的 `DrawResult` 带 `source` 标签，写库时一并保存。
- **数据源优先级可在设置中调整**（如：先 Web 服务，未命中再官方；或反之）。
- **endpoint 与请求头在设置中可覆盖**（应对官方封锁/改址，无需改代码）。
- **风险记录**：官方站点有 WAF / 反爬 / 地域限制（开发沙箱中 cwl 返回 403、
  sporttery 返回 567 反爬挑战页）。在用户本地中国大陆网络中通常可用；
  设计以「可配置 endpoint + 预热 + 重试 + 明确错误提示」缓解，并保留接口便于将来加备用源。

### 4.3 PrizeEvaluator（核心，纯函数）
- 输入投注号码与开奖号码，比对前区/后区命中数 → 按官方奖级表判定等级。
- **仅实现单式**逻辑。复式/胆拖留 UI 入口提示「开发中」。
- 输出：每注命中详情（命中哪些号）、奖级、金额、合计。
- 奖级表：
  - 双色球：一等(6+1)/二等(6+0)/三等(5+1)/四等(5+0或4+1)/五等(4+0或3+1)/六等(2+1或1+1或0+1)。
    三等及以下为固定金额；一、二等为浮动金额（取官方该期返回值）。
  - 大乐透：一等(5+2)/二等(5+1)/三等(5+0)/四等(4+2)/五等(4+1)/六等(3+2)/
    七等(4+0)/八等(3+1或2+2)/九等(3+0或1+2或2+1或0+2)。
    一、二等浮动；其余固定。

### 4.4 Store（SwiftData 持久层）

四个模型，关系如下：

```
Ticket 1 ── * VerificationRecord * ── 1 DrawVersion * ── 1 Draw
```

- **`Ticket`（彩票）**：id, category, issue, bets（确认后的投注号码）,
  **imageFileName**（原图文件名）, **cost**（投入金额，默认=注数×¥2，可覆盖）,
  **purchaseDate**（购买日期，识别/录入；用于日历与统计）, createdAt。一张票 → 多条 `VerificationRecord`。
- **`VerificationRecord`（验奖记录）**：id, ticket(关系), **drawVersion(关系)**,
  result（每注命中/奖级/金额/合计的快照）, createdAt。
  - 通过 drawVersion 可溯源到「数据源 + 版本号 + 开奖号码」。结果做快照，版本不可变保证可复现。
- **`Draw`（开奖记录组）**：id, category, issue, **source**（来源标签）。
  - 唯一键：category + issue + source。一个 Draw → 多个 `DrawVersion`。
- **`DrawVersion`（开奖版本，不可变）**：id, draw(关系), **versionNumber**(1,2,3…),
  frontNumbers, backNumbers, prizes（各奖级金额，可空）, drawDate,
  **origin**（`fetched` 数据源抓取 / `manual` 手动新增或修改）,
  **sourceURL**（仅 fetched：来源/查看链接，可空）, createdAt。
  - origin 与版本号无关：抓取来的版本 fetched，手动新增/修改的版本 manual。
  - 手动新增/修改 = 新增一个 versionNumber+1 的版本；已存在版本永不变更（验奖记录依赖其稳定）。

**图片存储**：原图写入沙箱 Application Support 目录，DB 仅存文件名/相对路径
（避免大 blob 撑大数据库）。iCloud 升级时图片改用 CKAsset，路径策略已隔离。

**提供能力**：Ticket 写/列/详情/删；VerificationRecord 写/按票列；
Draw 按(彩种+期数+源)查、列；DrawVersion 取最新/取指定/新增（手动修改）。

iCloud-ready：ModelContainer 配置预留 CloudKit 选项，默认关闭（本地）。

### 4.5 SettingsStore
- 模型：Base URL / API Key / 模型名。
- Web 服务数据源：Base URL / 共享 Token / 是否启用 / 数据源优先级。
- 存 UserDefaults（API Key、Token 可选存 Keychain）。

### 4.6 StatsService（统计聚合，纯函数·易测）
- 输入：Ticket 列表 + 各票最新 VerificationRecord + 相关 DrawVersion。每张票取最新验奖记录参与统计。
- 输出供 Dashboard 与统计页使用的聚合指标：
  - **盈亏**：累计投入(Σcost)、累计中奖(Σ最新验奖金额)、净盈亏、ROI；按时间分桶的盈亏趋势序列。
  - **购买习惯**：按日购买计数（日历热力）、彩种占比、按月/周购买量。
  - **中奖分析**：中奖率（中奖票/总票）、中奖等级分布、最高单次中奖、中奖金额趋势。
  - **号码分析**：我的常选号码频次；开奖热号/冷号（统计 DrawVersion 历史）；我的选号命中分布。
- 纯函数、与 SwiftUI 解耦，便于单元测试；视图层用 Swift Charts 渲染。

## 5. 数据流

**首次验奖**：拖入图片 → VisionRecognizer 识别 → 可编辑确认表单（彩种、期数、号码格子）→
保存为 `Ticket` → **选数据源** → DrawDataSource（按源缓存优先）取该期 `DrawVersion` →
PrizeEvaluator 比对 → 结果页（每注命中高亮 + 奖级 + 金额 + 合计 + 数据源/版本标注）→
保存为该票的一条 `VerificationRecord`。

**再次验奖**：彩票详情页 → 选另一数据源（或刷新某源）→ 取/建对应 `DrawVersion` →
比对 → 追加一条 `VerificationRecord`（同票多条并存，便于跨源对比）。

**手动修改开奖**：开奖版本浮层（从彩票详情或立即查询打开）选某 `Draw(彩种+期数+源)` →
编辑号码/奖金 → 新增一个 `DrawVersion`(origin=manual)；旧版本与依赖它的旧验奖记录不受影响。

**立即查询**：首页「立即查询」输入彩种 + 期数 + 选源 → DrawDataSource（缓存优先）→
开奖版本浮层展示结果并入库（可就地手动修改）。

## 6. UI 页面

### 侧边栏导航页

1. **首页 Dashboard**：快捷操作（上传验奖 / 立即查询 / 新增手动开奖）；关键数字卡片
   （累计投入 / 累计中奖 / 净盈亏 / 中奖率）；近期动态（最近上传票及最新验奖结果、近期开奖期）；
   迷你图表（盈亏趋势小图 + 本月购买日历缩略）。
2. **主验奖页**：图片拖拽区 / 选择按钮 → 识别进度 → 可编辑确认表单 → 保存彩票 →
   选数据源 → 「验奖」→ 结果（首条验奖记录自动入库）。
3. **彩票列表页**：所有上传彩票（缩略图、彩种、期数、最近验奖结果摘要），**点击某张进入彩票详情页**。
4. **验奖结果总览页**：所有彩票一行一条，展示其**最新验奖记录**（中奖状态 / 金额 / 数据源 / 时间）；
   支持按中奖状态、彩种、时间筛选与排序。
5. **统计页**：顶部**日历视图**（点某天看当天购买的彩票）；下方四组图表
   （盈亏 / 购买习惯 / 中奖 / 号码分析），Swift Charts 渲染，可切时间范围。
6. **设置页**：模型 Base URL / Key / 模型名；Web 服务 Base URL / Token / 启用开关 / 数据源优先级；
   （可选）官方数据源 endpoint 覆盖。

### 导航目的页 / 浮层（不在侧边栏）

7. **彩票详情页**：从彩票列表页点击进入（NavigationStack push），**顶部带返回按钮/面包屑可回列表**。
   内容：上传原图、确认号码；其下**全部验奖记录列表**（数据源 + 版本 + 奖级/金额 + 时间）；
   「换数据源再次验奖」「刷新某源重验」按钮，新记录追加保存；每条记录可打开**开奖版本浮层**查看/管理该期开奖。
8. **开奖版本浮层(sheet)**：针对某 `Draw(彩种+期数+源)` 展示**版本历史**
   （各版本标注 origin：抓取 / 手动；抓取版本显示**可点击来源链接**，点击在默认浏览器打开对应页面）；
   可「手动新增/修改」生成新版本、选某版本重验。从「彩票详情页」的验奖记录或「首页 立即查询」打开。

复式/胆拖入口：确认表单中以 disabled / 「开发中」标注。

## 7. 错误处理

- 模型未配置 → 引导去设置页。
- 识别失败 / 非 JSON / 号码非法 → 明确中文提示，验奖按钮在号码合法前禁用。
- 该期未开奖 / 期数不存在 → 提示。
- 网络失败 / WAF 拦截 → 提示并建议在设置中检查/覆盖 endpoint。

## 8. 测试

- **PrizeEvaluator**：单元测试覆盖全部奖级（含历史真实开奖样例）——核心正确性保障。
- **DrawDataSource**：用录制的官方样例 JSON 做解析测试；缓存优先逻辑测试。
- **Store**：Draw 按(彩种+期数+源)唯一去重；DrawVersion 版本号递增与不可变；
  手动修改新增版本而非覆盖；Ticket↔VerificationRecord 一对多；
  VerificationRecord 正确引用 DrawVersion；图片文件落盘与读取。
- **WebServiceDataSource**：用样例响应做解析 + Token 头测试。
- **StatsService**：用构造的票/验奖/开奖样本验证各指标计算（盈亏、中奖率、号码频次、热冷号、日历分桶）。
- 识别层、网络实拉、UI：手动验证。

## 9. 非目标（YAGNI）

- 复式 / 胆拖中奖金额计算（仅留入口）。
- 多用户账号体系（CloudKit 私有库天然按 Apple ID 隔离，无需自建）。
- 自动 OCR 本地识别（统一走配置的视觉大模型）。

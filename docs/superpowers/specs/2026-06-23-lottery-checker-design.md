# 彩票验奖 Mac App（LotteryChecker）设计文档

日期：2026-06-23
状态：已与用户确认，待进入实现计划
相关：配套 Web 服务见 `2026-06-23-lottery-webservice-design.md`（含共享 API 契约）

## 1. 目标

一个原生 macOS app：用户上传/拖入彩票照片 → 用视觉大模型识别彩种与号码 →
用户在可编辑表单核对 → 自动从官方网站拉取对应期开奖号码 → 验奖并展示结果。
已查询过的期数缓存进本地数据库，可浏览历史、支持「立即查询」，命中缓存则不再爬取。
已验奖的记录（含上传原图）也入库，可查看列表与详情。开奖记录标注数据来源。

## 2. 关键决策（已确认）

- **技术栈**：原生 SwiftUI macOS app（Xcode / Swift）。
- **模型协议**：OpenAI 兼容 `/chat/completions`（多模态）。用户在设置中填 Base URL / API Key / 模型名，模型自行配置。
- **玩法范围**：先实现**单式**验奖；复式、胆拖在 UI 留入口，点击提示「开发中」。
- **识别确认**：识别后填入**可编辑确认表单**，用户核对/修改后再验奖（防误读）。
- **数据存储**：**本地 SwiftData，iCloud-ready**。代码按可升级 CloudKit 的方式写，
  日后配置付费开发者账号 + CloudKit 容器即可开启每用户私有 iCloud 同步，无需改业务逻辑。
- **验奖记录入库**：每次验奖保存为 `TicketRecord`（含上传原图、确认后的号码、验奖结果、时间），可查看列表/详情/原图。
- **开奖来源标识**：`DrawRecord` 加 `source` 字段标识数据来源：`officialSporttery`(体彩) / `officialCWL`(福彩) / `webService`(自建 Web 服务) / `manual`(手动录入)。
- **新增数据源**：除官方接口外，新增可配置的 **Web 服务数据源**（见配套 Web 服务 spec）。

## 3. 总体架构

```
UI 层 (SwiftUI Views)
  ├─ 验奖流程：拖拽/选择图片 → 识别中 → 可编辑确认表单 → 验奖结果
  ├─ 开奖记录页：已查询期数列表 + 「立即查询」按钮 + 来源标签
  └─ 验奖记录页：历史验奖列表 → 详情（含原图、号码、结果）
应用层 (ViewModels / 状态机)
组件层（互不依赖，各有明确接口，可独立测试）：
  ├─ VisionRecognizer   识别彩票图片 → 结构化结果
  ├─ DrawDataSource     按彩种+期数拉取开奖数据（可插拔，缓存优先，多源）
  ├─ PrizeEvaluator     纯函数：投注号码 + 开奖号码 → 中奖等级/金额
  ├─ DrawStore          SwiftData 持久层（开奖缓存 + 验奖记录 + 图片）
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
  返回开奖号码 + 各奖级奖金（一/二等奖浮动金额直接取官方返回值）+ 开奖日期。
- **缓存优先策略**：验奖/查询时先查 `DrawStore`，命中直接返回（标注来源=缓存）；
  未命中才发起网络抓取，成功后写入 `DrawStore`。
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

### 4.4 DrawStore（SwiftData 持久层）
- 模型 `DrawRecord`：category, issue, frontNumbers, backNumbers,
  prizeTiers（各奖级金额，可空）, drawDate, fetchedAt, **source**（来源标签）。
  - 唯一键：category + issue（避免重复）；更新时刷新 source/金额/时间。
- 模型 `TicketRecord`（验奖记录）：category, issue, bets（确认后的投注号码）,
  result（每注奖级/金额/合计的快照）, **imageFileName**（原图文件名）, createdAt,
  关联的开奖号码快照。
  - **图片存储**：原图写入沙箱 Application Support 目录，DB 仅存文件名/相对路径
    （避免大 blob 撑大数据库）。iCloud 升级时图片改用 CKAsset，路径策略已隔离。
- 提供：开奖查/列/写；验奖记录写/列/详情/删。
- iCloud-ready：ModelContainer 配置预留 CloudKit 选项，默认关闭（本地）。

### 4.5 SettingsStore
- 模型：Base URL / API Key / 模型名。
- Web 服务数据源：Base URL / 共享 Token / 是否启用 / 数据源优先级。
- 存 UserDefaults（API Key、Token 可选存 Keychain）。

## 5. 数据流

**验奖流程**：拖入图片 → VisionRecognizer 识别 → 可编辑确认表单（彩种下拉、
期数、号码格子）→ 点「验奖」→ DrawDataSource（缓存优先）取该期开奖 →
PrizeEvaluator 比对 → 结果页（每注命中高亮 + 奖级 + 金额 + 合计；标注数据来源=缓存/官方）。

**立即查询**：历史页输入彩种 + 期数 → DrawDataSource（缓存优先）→ 展示开奖号码并入库。

## 6. UI 页面

1. **主验奖页**：图片拖拽区 / 选择按钮 → 识别进度 → 可编辑确认表单 → 「验奖」按钮 → 结果。
   验奖后自动保存为验奖记录。
2. **开奖记录页**：已查询期数列表（彩种、期数、开奖号码、日期、**来源标签**），点开看详情；
   顶部「立即查询」（输入彩种+期数直接抓取入库）。
3. **验奖记录页**：历史验奖列表，点开详情含**上传原图**、确认号码、每注命中与奖级/金额。
4. **设置页**：模型 Base URL / Key / 模型名；Web 服务 Base URL / Token / 启用开关 / 数据源优先级；
   （可选）官方数据源 endpoint 覆盖。
5. 复式/胆拖入口：表单中以 disabled / 「开发中」标注。

## 7. 错误处理

- 模型未配置 → 引导去设置页。
- 识别失败 / 非 JSON / 号码非法 → 明确中文提示，验奖按钮在号码合法前禁用。
- 该期未开奖 / 期数不存在 → 提示。
- 网络失败 / WAF 拦截 → 提示并建议在设置中检查/覆盖 endpoint。

## 8. 测试

- **PrizeEvaluator**：单元测试覆盖全部奖级（含历史真实开奖样例）——核心正确性保障。
- **DrawDataSource**：用录制的官方样例 JSON 做解析测试；缓存优先逻辑测试。
- **DrawStore**：开奖写入/读取/唯一键去重、source 标签持久化；验奖记录写入/读取、图片文件落盘与读取测试。
- **WebServiceDataSource**：用样例响应做解析 + Token 头测试。
- 识别层、网络实拉、UI：手动验证。

## 9. 非目标（YAGNI）

- 复式 / 胆拖中奖金额计算（仅留入口）。
- 多用户账号体系（CloudKit 私有库天然按 Apple ID 隔离，无需自建）。
- 自动 OCR 本地识别（统一走配置的视觉大模型）。

# 彩票验奖（Lottery Checker）

一套用于**大乐透**与**双色球**彩票验奖的工具，由两个相互独立、通过 HTTP API 协作的子项目组成：

| 子项目 | 目录 | 技术栈 | 说明 |
|---|---|---|---|
| **Mac App** | [`LotteryKit/`](LotteryKit/) + [`LotteryApp/`](LotteryApp/) | SwiftUI · SwiftData · Swift Charts | 上传彩票照片 → 大模型识别号码 → 可编辑确认 → 拉取官方/自建开奖数据 → 验奖、记账、统计 |
| **Web 服务** | [`webservice/`](webservice/) | React + Vite · FastAPI · SQLite/Postgres | 网页手动录入开奖号码（含可选奖金），对外提供 REST API 作为 Mac App 的一种数据源 |

> Mac App 采用「**本地 SwiftPM 包 + Xcode App 工程**」结构:业务逻辑沉淀在 `LotteryKit/`（可独立 `swift test`），界面源码与资源在 `LotteryApp/LotteryApp/`，由 `LotteryApp/LotteryApp.xcodeproj` 引用本地包并打包为可上架的 `.app`。工程说明见 [`XCODE-SETUP.md`](XCODE-SETUP.md)。

核心流程：**拍照上传 → 视觉模型识别彩种与号码 → 用户确认 → 选数据源拉取开奖结果 → 评奖**。所有数据本地留存，可反复用不同数据源/版本重新验奖。

---

## 功能概览

### Mac App
- **照片识别**：调用 OpenAI 兼容的多模态接口（`/chat/completions`），输出严格 JSON 的彩种 + 期号 + 号码，识别后可手动编辑再验奖。
- **以彩票为中心的数据模型**：一张彩票可有多条验奖记录；开奖结果按 `(彩种, 期数, 数据源)` 唯一，并保存**不可变版本**（抓取得到的为 `fetched` 版本，手动新增/修改生成新的 `manual` 版本）；每条验奖记录引用具体的开奖版本并存结果快照。
- **多数据源、缓存优先**：官方体彩（大乐透）、官方福彩（双色球）、自建 Web 服务、手动录入；命中缓存不重复联网，可强制刷新。抓取来的版本记录可点击的来源 URL。
- **评奖**：双色球 / 大乐透全奖级；固定奖金内置，一/二等浮动奖取开奖数据中的金额。当前仅实现单式，复式/胆拖入口标「开发中」。
- **页面**：首页 Dashboard、验奖流程、彩票列表 / 详情、开奖版本浮层、验奖结果总览、统计页（盈亏 / 购买 / 中奖 / 号码频率，Swift Charts）、设置。
- **本地存储**：SwiftData（iCloud-ready，CloudKit 默认关闭），上传原图落盘到 Application Support。

### Web 服务
- 网页登录（共享口令）后手动录入 / 编辑双色球、大乐透开奖（号码 + 可选各奖级奖金）。
- 提供 `/api/v1` REST API（JSON camelCase），共享 Bearer Token 鉴权，供 Mac App 拉取。
- SQLite 默认（数据库文件挂载到宿主机，容器重启不丢数据），可切换 Postgres；支持 Docker 部署。

---

## 仓库结构

```
.
├── LotteryKit/                 # Mac App 逻辑层：独立本地 SwiftPM 包（无第三方依赖）
│   ├── Package.swift           #   库 + 测试 target
│   ├── Sources/LotteryKit/     #   模型/校验/评奖/数据源/识别/持久化/统计（全部单测）
│   └── Tests/LotteryKitTests/
├── LotteryApp/                 # Mac App：Xcode 工程 + SwiftUI 界面层
│   ├── LotteryApp.xcodeproj
│   ├── LotteryApp/             #   App 入口、Views、Assets.xcassets
│   ├── LotteryAppTests/
│   └── LotteryAppUITests/
├── XCODE-SETUP.md              # Xcode 工程说明、签名/沙盒/分发要点
├── webservice/             # Web 服务
│   ├── backend/            # FastAPI + SQLAlchemy
│   ├── frontend/           # React + Vite
│   ├── docker-compose.yml
│   ├── DEPLOY.md           # 部署指南
│   └── README.md           # Web 服务说明 + API 契约
└── docs/
    ├── design-diagrams.html        # 架构/时序/ER 设计图（SVG，可切 Mermaid）
    └── superpowers/specs|plans/    # 设计规格与实现计划
```

---

## 运行 Mac App

需要安装完整的 **Xcode**（不是仅 Command Line Tools —— SwiftData/Charts 及打包所需）。仓库已包含 `LotteryApp/LotteryApp.xcodeproj`，**工程说明见 [`XCODE-SETUP.md`](XCODE-SETUP.md)**，要点：

1. 装完整版 Xcode，`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
2. 打开 `LotteryApp/LotteryApp.xcodeproj`，工程已通过本地包依赖引用 `LotteryKit/`。
3. 配 App Sandbox（网络客户端 + 用户选取文件）、Bundle ID、图标 → ⌘R 运行 / Archive 上架。
4. 也可用 `script/build_and_run.sh` 从命令行构建并启动。

**首次使用**：先在「设置」页填视觉模型（Base URL / API Key / 模型名）；如需自建数据源，开启 Web 服务并填 Base URL / Token。然后到「验奖」页：选图 → 识别 → 核对 → 选源 → 验奖。

**测试** —— 逻辑层 `LotteryKit` 可脱离工程独立跑（需完整 Xcode 工具链以加载 SwiftData 宏插件）：

```bash
cd LotteryKit
swift test   # 12 个测试文件 / 43 个单测
# 若系统默认仍是 Command Line Tools，前面加：
# DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

---

## 运行 Web 服务

本地开发：

```bash
# 后端（需 Python 3.12）
cd webservice/backend && pip install -r requirements.txt && uvicorn app.main:app --reload
# 前端（已配 /api 代理到 :8000）
cd webservice/frontend && npm install && npm run dev
```

Docker 部署见 [`webservice/DEPLOY.md`](webservice/DEPLOY.md)，API 契约见 [`webservice/README.md`](webservice/README.md)。

---

## 设计文档

- 设计图（架构 / 时序 / ER）：[`docs/design-diagrams.html`](docs/design-diagrams.html)（浏览器打开，默认手绘 SVG，可一键切 Mermaid）
- 规格：`docs/superpowers/specs/` ｜ 实现计划：`docs/superpowers/plans/`

---

## 已知限制

- **官方开奖接口有反爬 / 地域限制**（体彩 anti-bot、福彩 WAF + 境外 IP 拦截）：解析逻辑有单测覆盖，但真实联网可能拉不到，必要时按实际返回结构微调对应 `parse`。无法联网时可用「手动录入」数据源或开奖版本浮层手填号码完成验奖。
- 视觉识别与各数据源的真实网络调用需在你本机配置（API Key / 数据源地址）后联调；分发/上架请按 [`XCODE-SETUP.md`](XCODE-SETUP.md) 用 Xcode 打 Archive（需 Apple Developer Program 拿 `Apple Distribution` / `Developer ID` 证书）。
- 复式 / 胆拖尚未实现（界面预留入口）。

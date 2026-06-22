# 彩票开奖录入 Web 服务（LotteryDraws Service）设计文档

日期：2026-06-23
状态：已与用户确认，待进入实现计划
相关：配套 Mac app 见 `2026-06-23-lottery-checker-design.md`

## 1. 目标

一个自托管 Web 服务：在网页上手动录入双色球/大乐透的**开奖期数 + 号码（+ 可选各奖级奖金）**，
保存到数据库；提供网页浏览/管理，并对外提供 **REST API** 供 Mac app 按期数拉取开奖信息。
要求可 Docker 部署，支持 git 拉取代码 → 构建镜像 → 启动。

## 2. 关键决策（已确认）

- **架构**：前后端分离。**React 前端（SPA）** + **FastAPI 后端（Python）API**。
  - 后端语言推荐 FastAPI：自带 OpenAPI/Swagger 文档，正好作为 Mac app 的接口契约。
- **访问控制**：**共享 Token**。录入/管理页需登录口令；写接口与（可选）读接口校验 `Bearer` Token。
- **数据库**：**SQLite 默认 + 可切 Postgres**，经环境变量 `DATABASE_URL` 切换；ORM（SQLAlchemy）抽象，一套代码。
  - SQLite 文件持久化：DB 文件位于容器内 `/data/lottery.db`，通过 **Docker 卷挂载到宿主机**
    （如 `-v /opt/lottery/data:/data`），容器重启/重建数据不丢。
  - Postgres 选项：腾讯云托管 PG，或用 docker-compose 起一个 PG 服务（备用方案）。
- **开奖录入**：期数 + 号码为必填；各奖级奖金为**可选**。
- **部署**：多阶段 Dockerfile + 部署指南；支持服务器 `git pull` → `docker build` → `docker run`/compose。

## 3. 总体架构

```
浏览器 (React SPA)
   │  HTTPS / Bearer Token
   ▼
FastAPI 后端 (REST API)
   ├─ 鉴权中间件（共享 Token）
   ├─ 路由：开奖 CRUD + 列表查询
   └─ Service / Repository 层（SQLAlchemy）
   ▼
数据库（SQLite 文件 卷挂载 ／ Postgres）

部署形态：
  方案A（默认，单机最简）：docker-compose 起 api + web(静态) 两个容器，DB 用 SQLite 卷。
  方案B（生产）：api + web + postgres 三容器；或 DB 用腾讯云托管 PG，仅起 api + web。
```

前后端分离的代码组织：`frontend/`（React）与 `backend/`（FastAPI）同仓；各自 Dockerfile，
docker-compose 编排。前端构建为静态资源由 nginx 容器托管，API 由 FastAPI 容器提供。

## 4. 数据模型

`draw` 表（唯一键：category + issue）：
- `id`、`category`（`dlt`|`ssq`）、`issue`（期数，字符串）
- `front_numbers`（前区/红球，整数数组，存 JSON 或关联表）
- `back_numbers`（后区/蓝球，整数数组）
- `draw_date`（开奖日期，可空）
- `prizes`（可选：各奖级金额，JSON，如 `{"first": 10000000, "second": 200000, ...}`）
- `created_at`、`updated_at`
- 录入时做号码个数/范围校验（与 app 同一规则）。

## 5. API 契约（与 Mac app 共享）

基础路径 `"/api/v1"`。鉴权：写接口必须带 `Authorization: Bearer <TOKEN>`；
读接口是否鉴权由环境变量 `READ_REQUIRES_AUTH` 控制（默认开启，与 app 配置一致）。

- `GET /api/v1/draws/{category}/{issue}`
  → 200 单条开奖：`{category, issue, frontNumbers, backNumbers, drawDate, prizes?}`；404 不存在。
  （Mac app 的 `WebServiceDataSource` 调用此接口；返回结果 app 端标记 `source = webService`。）
- `GET /api/v1/draws?category=&page=&pageSize=`
  → 200 分页列表（供前端浏览，也可供 app 同步）。
- `POST /api/v1/draws`（鉴权）
  → 创建或更新（按 category+issue upsert）。请求体含号码与可选 prizes。
- `DELETE /api/v1/draws/{category}/{issue}`（鉴权）→ 删除。
- `POST /api/v1/auth/login`（口令换取/校验 Token，供前端登录页）。
- `GET /healthz` → 健康检查（容器探针）。
- FastAPI 自动暴露 `/docs`（Swagger），作为 app 端实现接口的依据。

## 6. 前端页面（React）

1. **登录页**：输入共享口令，拿到 Token 存本地。
2. **开奖列表页**：按彩种筛选、分页；显示期数/号码/日期/是否含奖金。
3. **录入/编辑页**：选彩种 → 填期数 → 号码格子（双色球 6 红+1 蓝；大乐透 5 前+2 后）→
   可选填各奖级奖金 → 保存（前端做与后端一致的校验）。
4. **详情页**：查看单期完整信息。

## 7. 部署

- **后端 Dockerfile**：python slim 基础镜像，装依赖，`uvicorn` 启动；`/data` 为卷挂载点存 SQLite。
- **前端 Dockerfile**：多阶段（node 构建 → nginx 托管静态），nginx 反代 `/api` 到后端容器。
- **docker-compose.yml**：
  - 默认：`api`（挂载 `./data:/data`）+ `web`；DB=SQLite。
  - 可选 profile：加 `postgres` 服务并设 `DATABASE_URL` 指向它。
- **配置（环境变量）**：`DATABASE_URL`、`API_TOKEN`/`ADMIN_PASSWORD`、`READ_REQUIRES_AUTH`、`CORS_ORIGINS`。
- **部署指南（README/DEPLOY.md）**：服务器上
  `git clone/pull` → `docker compose build` → `docker compose up -d`；
  含 SQLite 卷挂载说明、切换腾讯云 PG 的步骤、升级（pull + rebuild + up）流程、备份建议。

## 8. 错误处理

- 鉴权失败 401；号码非法 422（带具体原因）；重复期数走 upsert 不报错；DB 不可用 503。
- 统一 JSON 错误结构，前端与 app 都能解析。

## 9. 测试

- 后端：API 单测（CRUD、鉴权、号码校验、upsert、SQLite/PG 切换）。
- 前端：录入校验与关键交互的组件测试。
- 部署：在干净环境跑一遍 compose 起服务 + 调 `/healthz` + 录一条 + app 拉取的端到端冒烟。

## 10. 非目标（YAGNI）

- 多用户/角色权限（单口令足够）。
- 自动从官方抓取（本服务定位为手动录入源；自动抓取在 app 端）。
- 复杂的奖金计算（仅存录入值）。

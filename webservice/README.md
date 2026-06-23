# 彩票开奖录入 Web 服务

网页手动录入双色球/大乐透开奖（号码 + 可选奖金），提供 REST API 供 Mac App 拉取。

- 后端：FastAPI（`backend/`），API 见 `/docs`（Swagger）。
- 前端：React + Vite（`frontend/`），苹果风设计系统（设计令牌 + CSS Modules，零额外依赖）。
- 部署：见 `DEPLOY.md`。

## 前端页面与路由
- `/` 首页（公开）：介绍配套 Mac App。
- `/login` 登录（公开）：共享口令换取 Bearer token。
- `/draws` 开奖列表（需登录）：彩种分段筛选 + 号码球卡片列表。
- `/draws/new`、`/draws/edit/:category/:issue` 录入/编辑（需登录）。
- `/draws/:category/:issue` 开奖详情（需登录）。

设计文档见 `docs/superpowers/specs/2026-06-23-web-frontend-redesign-design.md`。

## 本地开发
后端：`cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload`
前端：`cd frontend && npm install && npm run dev`（已配 `/api` 代理到 :8000）

## 测试
后端：`cd backend && pytest`（需 Python 3.12）
前端：`cd frontend && npm test`

## API 契约（/api/v1，JSON camelCase）
- `POST /auth/login {password}` → `{token}`
- `GET  /draws/{category}/{issue}` → 开奖（404 不存在）
- `GET  /draws?category=&page=&pageSize=` → 列表
- `POST /draws`（Bearer）→ upsert
- `DELETE /draws/{category}/{issue}`（Bearer）

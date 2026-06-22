# 部署指南

## 1. 前置
服务器装好 Docker 与 docker compose 插件。

## 2. 拉取代码
    git clone <repo> && cd <repo>/webservice

## 3. 配置环境变量
在 `webservice/` 下创建 `.env`：
    API_TOKEN=用长随机串
    ADMIN_PASSWORD=强密码
    READ_REQUIRES_AUTH=true
    CORS_ORIGINS=*
    # 默认 SQLite，无需设 DATABASE_URL

## 4. 构建并启动（默认 SQLite，数据落在 ./data，宿主持久化）
    docker compose build
    docker compose up -d

访问前端：`http://<服务器IP>:8080`；API 经由前端容器反代在 `http://<服务器IP>:8080/api/v1`（FastAPI 文档在 api 容器 `:8000/docs`）。

## 5. 升级（拉新代码重建）
    git pull
    docker compose build
    docker compose up -d

## 6. 切换数据库
- 用编排内 Postgres：在 `.env` 设
      DATABASE_URL=postgresql+psycopg2://lottery:lottery@postgres:5432/lottery
  并 `docker compose --profile pg up -d`。
- 用腾讯云托管 PG：把 `DATABASE_URL` 指向云实例连接串即可，不启 postgres profile。

## 7. 备份
- SQLite：备份 `webservice/data/lottery.db`。
- Postgres：`pg_dump`。

# 彩票开奖录入 Web 服务 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一个可 Docker 部署的自托管 Web 服务：网页手动录入双色球/大乐透开奖（号码 + 可选奖金），存数据库，并提供 REST API 供 Mac App 按期数拉取。

**Architecture:** 前后端分离。FastAPI 后端提供 `/api/v1` REST API + 共享 Token 鉴权，SQLAlchemy 抽象数据库（默认 SQLite 文件、可切 Postgres）；React(Vite+TS) 前端做登录/列表/录入/详情；docker-compose 编排 nginx(前端静态) + api，SQLite 文件用宿主卷持久化。

**Tech Stack:** Python 3.12 · FastAPI · SQLAlchemy 2.x · pydantic v2 / pydantic-settings · uvicorn · pytest + httpx · React 18 + Vite + TypeScript · Vitest + Testing Library · Docker / docker-compose / nginx

## Global Constraints

- 目录根：仓库下 `webservice/`；后端 `webservice/backend/`，前端 `webservice/frontend/`。
- API 基础路径：`/api/v1`。健康检查：`GET /healthz`。
- **API JSON 字段一律 camelCase**：`category, issue, frontNumbers, backNumbers, drawDate, prizes, createdAt, updatedAt`（与 Mac App 契约一致）。
- 彩种取值：`dlt`（大乐透）/ `ssq`（双色球）。
- **号码校验规则（前后端一致）**：
  - `ssq`：front = 6 个互不相同整数，范围 1–33；back = 1 个整数，范围 1–16。
  - `dlt`：front = 5 个互不相同整数，范围 1–35；back = 2 个互不相同整数，范围 1–12。
- 号码必填；`prizes` 可选（`{tierName: 金额(非负整数)}`，可空）；`drawDate` 可选（ISO `YYYY-MM-DD`）。
- 写接口（POST/DELETE）必须 `Authorization: Bearer <API_TOKEN>`；读接口在 `READ_REQUIRES_AUTH=true`（默认）时也需鉴权。
- 登录：`POST /api/v1/auth/login {password}`，密码等于 `ADMIN_PASSWORD` 时返回 `{token: API_TOKEN}`。
- upsert 语义：按 `(category, issue)` 唯一键创建或更新。
- 环境变量：`DATABASE_URL`（默认 `sqlite:///./lottery.db`，Docker 用 `sqlite:////data/lottery.db`）、`API_TOKEN`、`ADMIN_PASSWORD`、`READ_REQUIRES_AUTH`、`CORS_ORIGINS`。
- 每个任务结束都要 `git commit`。后端测试用 pytest，跑命令 `cd webservice/backend && pytest`。

---

## 文件结构

```
webservice/
  backend/
    app/
      __init__.py
      config.py          # 环境变量配置
      database.py        # SQLAlchemy engine/session/Base + get_db
      models.py          # Draw ORM 模型
      validation.py      # 号码校验（纯函数）
      schemas.py         # Pydantic 请求/响应模型（camelCase）
      auth.py            # Token 依赖 + 登录逻辑
      main.py            # FastAPI app 装配 + /healthz
      routers/
        __init__.py
        auth.py          # POST /api/v1/auth/login
        draws.py         # 开奖 CRUD + 列表
    tests/
      __init__.py
      conftest.py        # 测试 client + 内存库 fixture
      test_validation.py
      test_auth.py
      test_draws_api.py
    requirements.txt
    .env.example
    Dockerfile
  frontend/
    package.json
    vite.config.ts
    tsconfig.json
    index.html
    nginx.conf
    Dockerfile
    src/
      main.tsx
      App.tsx
      api.ts             # API 客户端 + 类型
      validation.ts      # 前端号码校验（与后端同规则）
      auth.ts            # token 本地存取
      pages/
        LoginPage.tsx
        DrawListPage.tsx
        DrawFormPage.tsx
        DrawDetailPage.tsx
    src/__tests__/
      validation.test.ts
      DrawFormPage.test.tsx
  docker-compose.yml
  DEPLOY.md
  README.md
```

---

### Task 1: 后端脚手架 + 配置 + 健康检查

**Files:**
- Create: `webservice/backend/requirements.txt`
- Create: `webservice/backend/app/__init__.py`
- Create: `webservice/backend/app/config.py`
- Create: `webservice/backend/app/main.py`
- Create: `webservice/backend/tests/__init__.py`
- Create: `webservice/backend/tests/test_health.py`

**Interfaces:**
- Produces: `app.config.settings`（属性 `database_url, api_token, admin_password, read_requires_auth, cors_origins`）；`app.main.app`（FastAPI 实例）。

- [ ] **Step 1: 写依赖文件**

`webservice/backend/requirements.txt`：
```
fastapi==0.111.0
uvicorn[standard]==0.30.1
SQLAlchemy==2.0.31
pydantic==2.8.2
pydantic-settings==2.3.4
psycopg2-binary==2.9.9
pytest==8.2.2
httpx==0.27.0
```

- [ ] **Step 2: 安装依赖**

Run: `cd webservice/backend && python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt`
Expected: 安装成功，无报错。

- [ ] **Step 3: 写失败测试**

`webservice/backend/tests/__init__.py`：空文件。
`webservice/backend/app/__init__.py`：空文件。
`webservice/backend/tests/test_health.py`：
```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_healthz_ok():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}
```

- [ ] **Step 4: 跑测试确认失败**

Run: `cd webservice/backend && pytest tests/test_health.py -v`
Expected: FAIL（`ModuleNotFoundError: app.main` 或 import 失败）。

- [ ] **Step 5: 写配置**

`webservice/backend/app/config.py`：
```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./lottery.db"
    api_token: str = "change-me-token"
    admin_password: str = "change-me-pass"
    read_requires_auth: bool = True
    cors_origins: str = "*"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
```

- [ ] **Step 6: 写最小 app**

`webservice/backend/app/main.py`：
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings

app = FastAPI(title="Lottery Draws Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
```

- [ ] **Step 7: 跑测试确认通过**

Run: `cd webservice/backend && pytest tests/test_health.py -v`
Expected: PASS。

- [ ] **Step 8: 提交**

```bash
git add webservice/backend
git commit -m "feat(web): 后端脚手架+配置+健康检查"
```

---

### Task 2: 数据库层 + Draw 模型

**Files:**
- Create: `webservice/backend/app/database.py`
- Create: `webservice/backend/app/models.py`
- Create: `webservice/backend/tests/test_model.py`

**Interfaces:**
- Consumes: `app.config.settings`。
- Produces: `app.database.Base`、`app.database.engine`、`app.database.SessionLocal`、`app.database.get_db`（生成器依赖）、`app.database.init_db()`；`app.models.Draw`（列：`id, category, issue, front_numbers, back_numbers, draw_date, prizes, created_at, updated_at`；唯一约束 `(category, issue)`）。

- [ ] **Step 1: 写失败测试**

`webservice/backend/tests/test_model.py`：
```python
import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import IntegrityError
from app.database import Base
from app.models import Draw


@pytest.fixture()
def session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    Local = sessionmaker(bind=engine)
    s = Local()
    yield s
    s.close()


def test_create_and_read_draw(session):
    d = Draw(category="ssq", issue="24001", front_numbers=[1, 2, 3, 4, 5, 6], back_numbers=[7])
    session.add(d)
    session.commit()
    got = session.scalar(select(Draw).where(Draw.category == "ssq", Draw.issue == "24001"))
    assert got.front_numbers == [1, 2, 3, 4, 5, 6]
    assert got.back_numbers == [7]
    assert got.prizes is None
    assert got.created_at is not None


def test_unique_category_issue(session):
    session.add(Draw(category="ssq", issue="24001", front_numbers=[1, 2, 3, 4, 5, 6], back_numbers=[7]))
    session.commit()
    session.add(Draw(category="ssq", issue="24001", front_numbers=[1, 2, 3, 4, 5, 7], back_numbers=[8]))
    with pytest.raises(IntegrityError):
        session.commit()
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd webservice/backend && pytest tests/test_model.py -v`
Expected: FAIL（`app.database`/`app.models` 不存在）。

- [ ] **Step 3: 写 database.py**

`webservice/backend/app/database.py`：
```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from .config import settings


class Base(DeclarativeBase):
    pass


connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def init_db() -> None:
    from . import models  # noqa: F401  确保模型已注册
    Base.metadata.create_all(engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

- [ ] **Step 4: 写 models.py**

`webservice/backend/app/models.py`：
```python
from datetime import date, datetime

from sqlalchemy import String, JSON, Date, DateTime, Integer, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Draw(Base):
    __tablename__ = "draws"
    __table_args__ = (UniqueConstraint("category", "issue", name="uq_category_issue"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category: Mapped[str] = mapped_column(String(8), index=True)
    issue: Mapped[str] = mapped_column(String(16), index=True)
    front_numbers: Mapped[list] = mapped_column(JSON)
    back_numbers: Mapped[list] = mapped_column(JSON)
    draw_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    prizes: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )
```

- [ ] **Step 5: 跑测试确认通过**

Run: `cd webservice/backend && pytest tests/test_model.py -v`
Expected: PASS（2 passed）。

- [ ] **Step 6: 提交**

```bash
git add webservice/backend
git commit -m "feat(web): SQLAlchemy 数据库层与 Draw 模型"
```

---

### Task 3: 号码校验（纯函数，TDD 重点）

**Files:**
- Create: `webservice/backend/app/validation.py`
- Create: `webservice/backend/tests/test_validation.py`

**Interfaces:**
- Produces: `app.validation.validate_numbers(category: str, front: list[int], back: list[int]) -> None`（不合法时 `raise ValueError(中文原因)`）；`app.validation.RULES`（字典，键 `ssq`/`dlt`，值含 `front_count, front_max, back_count, back_max`）。

- [ ] **Step 1: 写失败测试**

`webservice/backend/tests/test_validation.py`：
```python
import pytest
from app.validation import validate_numbers


def test_ssq_valid():
    validate_numbers("ssq", [1, 2, 3, 4, 5, 6], [16])  # 不抛异常


def test_dlt_valid():
    validate_numbers("dlt", [1, 2, 3, 4, 35], [1, 12])


@pytest.mark.parametrize("front,back,kw", [
    ([1, 2, 3, 4, 5], [16], "6"),          # ssq 红球个数错
    ([1, 2, 3, 4, 5, 34], [16], "33"),     # ssq 红球越界
    ([1, 2, 3, 4, 5, 5], [16], "不"),       # ssq 红球重复
    ([1, 2, 3, 4, 5, 6], [17], "16"),      # ssq 蓝球越界
    ([1, 2, 3, 4, 5, 6], [1, 2], "1"),     # ssq 蓝球个数错
])
def test_ssq_invalid(front, back, kw):
    with pytest.raises(ValueError) as e:
        validate_numbers("ssq", front, back)
    assert kw in str(e.value)


def test_unknown_category():
    with pytest.raises(ValueError):
        validate_numbers("xxx", [1], [1])
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd webservice/backend && pytest tests/test_validation.py -v`
Expected: FAIL（`app.validation` 不存在）。

- [ ] **Step 3: 写实现**

`webservice/backend/app/validation.py`：
```python
RULES = {
    "ssq": {"front_count": 6, "front_max": 33, "back_count": 1, "back_max": 16},
    "dlt": {"front_count": 5, "front_max": 35, "back_count": 2, "back_max": 12},
}


def _check(name: str, nums: list[int], count: int, max_v: int) -> None:
    if not isinstance(nums, list) or len(nums) != count:
        raise ValueError(f"{name}必须为 {count} 个号码")
    if len(set(nums)) != len(nums):
        raise ValueError(f"{name}不能重复")
    for n in nums:
        if not isinstance(n, int) or n < 1 or n > max_v:
            raise ValueError(f"{name}范围应为 1-{max_v}")


def validate_numbers(category: str, front: list[int], back: list[int]) -> None:
    rule = RULES.get(category)
    if rule is None:
        raise ValueError(f"未知彩种: {category}")
    _check("前区/红球", front, rule["front_count"], rule["front_max"])
    _check("后区/蓝球", back, rule["back_count"], rule["back_max"])
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd webservice/backend && pytest tests/test_validation.py -v`
Expected: PASS（全部通过）。

- [ ] **Step 5: 提交**

```bash
git add webservice/backend
git commit -m "feat(web): 号码校验纯函数"
```

---

### Task 4: Pydantic schemas（camelCase 契约）

**Files:**
- Create: `webservice/backend/app/schemas.py`
- Create: `webservice/backend/tests/test_schemas.py`

**Interfaces:**
- Produces：
  - `app.schemas.DrawIn`（字段 `category, issue, frontNumbers, backNumbers, drawDate(可空), prizes(可空)`；含号码校验）。
  - `app.schemas.DrawOut`（同上 + `createdAt, updatedAt`；`from_attributes=True`，可由 ORM `Draw` 转换；输出 camelCase）。
  - `app.schemas.DrawList`（`items: list[DrawOut]`, `total: int`, `page: int`, `pageSize: int`）。
  - `app.schemas.LoginIn`（`password: str`）、`app.schemas.LoginOut`（`token: str`）。

- [ ] **Step 1: 写失败测试**

`webservice/backend/tests/test_schemas.py`：
```python
import pytest
from pydantic import ValidationError
from app.schemas import DrawIn, DrawOut


def test_drawin_camel_and_validation():
    d = DrawIn.model_validate({
        "category": "ssq", "issue": "24001",
        "frontNumbers": [1, 2, 3, 4, 5, 6], "backNumbers": [16],
    })
    assert d.front_numbers == [1, 2, 3, 4, 5, 6]
    assert d.prizes is None


def test_drawin_rejects_bad_numbers():
    with pytest.raises(ValidationError):
        DrawIn.model_validate({
            "category": "ssq", "issue": "24001",
            "frontNumbers": [1, 2, 3], "backNumbers": [16],
        })


def test_drawout_serializes_camel():
    class FakeRow:
        category = "dlt"; issue = "24001"
        front_numbers = [1, 2, 3, 4, 5]; back_numbers = [1, 2]
        draw_date = None; prizes = None
        created_at = None; updated_at = None
    out = DrawOut.model_validate(FakeRow())
    body = out.model_dump(by_alias=True)
    assert body["frontNumbers"] == [1, 2, 3, 4, 5]
    assert "backNumbers" in body and "createdAt" in body
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd webservice/backend && pytest tests/test_schemas.py -v`
Expected: FAIL（`app.schemas` 不存在）。

- [ ] **Step 3: 写实现**

`webservice/backend/app/schemas.py`：
```python
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, model_validator
from pydantic.alias_generators import to_camel

from .validation import validate_numbers


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class DrawIn(CamelModel):
    category: str
    issue: str
    front_numbers: list[int]
    back_numbers: list[int]
    draw_date: date | None = None
    prizes: dict[str, int] | None = None

    @model_validator(mode="after")
    def _check(self):
        validate_numbers(self.category, self.front_numbers, self.back_numbers)
        if self.prizes is not None:
            for k, v in self.prizes.items():
                if not isinstance(v, int) or v < 0:
                    raise ValueError(f"奖金 {k} 必须为非负整数")
        return self


class DrawOut(CamelModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)
    category: str
    issue: str
    front_numbers: list[int]
    back_numbers: list[int]
    draw_date: date | None = None
    prizes: dict[str, int] | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class DrawList(CamelModel):
    items: list[DrawOut]
    total: int
    page: int
    page_size: int


class LoginIn(CamelModel):
    password: str


class LoginOut(CamelModel):
    token: str
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd webservice/backend && pytest tests/test_schemas.py -v`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add webservice/backend
git commit -m "feat(web): Pydantic camelCase schemas"
```

---

### Task 5: 鉴权（Token 依赖 + 登录路由）

**Files:**
- Create: `webservice/backend/app/auth.py`
- Create: `webservice/backend/app/routers/__init__.py`
- Create: `webservice/backend/app/routers/auth.py`
- Modify: `webservice/backend/app/main.py`（挂载 auth 路由）
- Create: `webservice/backend/tests/conftest.py`
- Create: `webservice/backend/tests/test_auth.py`

**Interfaces:**
- Consumes: `app.config.settings`、`app.schemas.LoginIn/LoginOut`、`app.database.get_db`、`app.database.Base`。
- Produces:
  - `app.auth.require_write`（FastAPI 依赖：校验 `Authorization: Bearer == settings.api_token`，失败 401）。
  - `app.auth.require_read`（依赖：`read_requires_auth` 为真时同 `require_write`，否则放行）。
  - `app.routers.auth.router`（含 `POST /api/v1/auth/login`）。
  - 测试夹具 `client`（`TestClient`，已用内存库覆盖 `get_db` 并建表）、`auth_headers`。

- [ ] **Step 1: 写测试夹具**

`webservice/backend/app/routers/__init__.py`：空文件。
`webservice/backend/tests/conftest.py`：
```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.database import Base, get_db
from app.main import app


@pytest.fixture()
def client():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    TestingSession = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(engine)

    def override_get_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    settings.read_requires_auth = True
    settings.api_token = "test-token"
    settings.admin_password = "test-pass"
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture()
def auth_headers():
    return {"Authorization": "Bearer test-token"}
```

- [ ] **Step 2: 写失败测试**

`webservice/backend/tests/test_auth.py`：
```python
def test_login_success(client):
    r = client.post("/api/v1/auth/login", json={"password": "test-pass"})
    assert r.status_code == 200
    assert r.json()["token"] == "test-token"


def test_login_wrong_password(client):
    r = client.post("/api/v1/auth/login", json={"password": "nope"})
    assert r.status_code == 401
```

- [ ] **Step 3: 跑测试确认失败**

Run: `cd webservice/backend && pytest tests/test_auth.py -v`
Expected: FAIL（路由不存在 → 404，断言失败）。

- [ ] **Step 4: 写 auth.py**

`webservice/backend/app/auth.py`：
```python
from fastapi import Header, HTTPException, status

from .config import settings


def _check_bearer(authorization: str | None) -> None:
    expected = f"Bearer {settings.api_token}"
    if authorization != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未授权")


def require_write(authorization: str | None = Header(default=None)) -> None:
    _check_bearer(authorization)


def require_read(authorization: str | None = Header(default=None)) -> None:
    if settings.read_requires_auth:
        _check_bearer(authorization)
```

- [ ] **Step 5: 写登录路由**

`webservice/backend/app/routers/auth.py`：
```python
from fastapi import APIRouter, HTTPException, status

from ..config import settings
from ..schemas import LoginIn, LoginOut

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/login", response_model=LoginOut)
def login(body: LoginIn):
    if body.password != settings.admin_password:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="密码错误")
    return LoginOut(token=settings.api_token)
```

- [ ] **Step 6: 挂载路由到 main.py**

修改 `webservice/backend/app/main.py`，在 `app = FastAPI(...)` 与中间件之后追加：
```python
from .routers import auth as auth_router

app.include_router(auth_router.router)
```

- [ ] **Step 7: 跑测试确认通过**

Run: `cd webservice/backend && pytest tests/test_auth.py -v`
Expected: PASS。

- [ ] **Step 8: 提交**

```bash
git add webservice/backend
git commit -m "feat(web): 共享Token鉴权与登录路由"
```

---

### Task 6: 开奖 CRUD + 列表 API

**Files:**
- Create: `webservice/backend/app/routers/draws.py`
- Modify: `webservice/backend/app/main.py`（挂载 draws 路由）
- Create: `webservice/backend/tests/test_draws_api.py`

**Interfaces:**
- Consumes: `app.auth.require_read/require_write`、`app.database.get_db`、`app.models.Draw`、`app.schemas.DrawIn/DrawOut/DrawList`。
- Produces: `app.routers.draws.router`，含：
  - `POST /api/v1/draws`（写鉴权，按 `(category, issue)` upsert，返回 `DrawOut`）。
  - `GET /api/v1/draws/{category}/{issue}`（读鉴权，命中 200 `DrawOut`，未命中 404）。
  - `GET /api/v1/draws?category=&page=&pageSize=`（读鉴权，返回 `DrawList`，按 `issue` 倒序）。
  - `DELETE /api/v1/draws/{category}/{issue}`（写鉴权，删除返回 204，未命中 404）。

- [ ] **Step 1: 写失败测试**

`webservice/backend/tests/test_draws_api.py`：
```python
SSQ = {"category": "ssq", "issue": "24001", "frontNumbers": [1, 2, 3, 4, 5, 6], "backNumbers": [16]}


def test_create_requires_auth(client):
    r = client.post("/api/v1/draws", json=SSQ)
    assert r.status_code == 401


def test_create_and_get(client, auth_headers):
    r = client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    assert r.status_code == 200
    body = r.json()
    assert body["frontNumbers"] == [1, 2, 3, 4, 5, 6]

    r2 = client.get("/api/v1/draws/ssq/24001", headers=auth_headers)
    assert r2.status_code == 200
    assert r2.json()["issue"] == "24001"


def test_get_not_found(client, auth_headers):
    r = client.get("/api/v1/draws/ssq/99999", headers=auth_headers)
    assert r.status_code == 404


def test_upsert_updates(client, auth_headers):
    client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    updated = {**SSQ, "backNumbers": [10], "prizes": {"first": 5000000}}
    r = client.post("/api/v1/draws", json=updated, headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["backNumbers"] == [10]
    r2 = client.get("/api/v1/draws/ssq/24001", headers=auth_headers)
    assert r2.json()["prizes"] == {"first": 5000000}


def test_create_rejects_bad_numbers(client, auth_headers):
    bad = {**SSQ, "frontNumbers": [1, 2, 3]}
    r = client.post("/api/v1/draws", json=bad, headers=auth_headers)
    assert r.status_code == 422


def test_list_and_filter(client, auth_headers):
    client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    client.post("/api/v1/draws", json={**SSQ, "issue": "24002"}, headers=auth_headers)
    client.post("/api/v1/draws", json={"category": "dlt", "issue": "24001",
                                       "frontNumbers": [1, 2, 3, 4, 5], "backNumbers": [1, 2]},
                headers=auth_headers)
    r = client.get("/api/v1/draws?category=ssq", headers=auth_headers)
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 2
    assert body["items"][0]["issue"] == "24002"  # 倒序


def test_delete(client, auth_headers):
    client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    r = client.delete("/api/v1/draws/ssq/24001", headers=auth_headers)
    assert r.status_code == 204
    assert client.get("/api/v1/draws/ssq/24001", headers=auth_headers).status_code == 404
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd webservice/backend && pytest tests/test_draws_api.py -v`
Expected: FAIL（draws 路由不存在）。

- [ ] **Step 3: 写 draws 路由**

`webservice/backend/app/routers/draws.py`：
```python
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from ..auth import require_read, require_write
from ..database import get_db
from ..models import Draw
from ..schemas import DrawIn, DrawOut, DrawList

router = APIRouter(prefix="/api/v1/draws", tags=["draws"])


def _get(db: Session, category: str, issue: str) -> Draw | None:
    return db.scalar(select(Draw).where(Draw.category == category, Draw.issue == issue))


@router.post("", response_model=DrawOut, dependencies=[Depends(require_write)])
def upsert_draw(body: DrawIn, db: Session = Depends(get_db)):
    row = _get(db, body.category, body.issue)
    if row is None:
        row = Draw(category=body.category, issue=body.issue)
        db.add(row)
    row.front_numbers = body.front_numbers
    row.back_numbers = body.back_numbers
    row.draw_date = body.draw_date
    row.prizes = body.prizes
    db.commit()
    db.refresh(row)
    return row


@router.get("/{category}/{issue}", response_model=DrawOut, dependencies=[Depends(require_read)])
def get_draw(category: str, issue: str, db: Session = Depends(get_db)):
    row = _get(db, category, issue)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="该期不存在")
    return row


@router.get("", response_model=DrawList, dependencies=[Depends(require_read)])
def list_draws(
    category: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=30, ge=1, le=200, alias="pageSize"),
    db: Session = Depends(get_db),
):
    stmt = select(Draw)
    count_stmt = select(func.count()).select_from(Draw)
    if category:
        stmt = stmt.where(Draw.category == category)
        count_stmt = count_stmt.where(Draw.category == category)
    total = db.scalar(count_stmt) or 0
    stmt = stmt.order_by(Draw.issue.desc()).offset((page - 1) * page_size).limit(page_size)
    items = list(db.scalars(stmt))
    return DrawList(items=items, total=total, page=page, page_size=page_size)


@router.delete("/{category}/{issue}", status_code=204, dependencies=[Depends(require_write)])
def delete_draw(category: str, issue: str, db: Session = Depends(get_db)):
    row = _get(db, category, issue)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="该期不存在")
    db.delete(row)
    db.commit()
    return Response(status_code=204)
```

- [ ] **Step 4: 挂载到 main.py**

修改 `webservice/backend/app/main.py`，追加：
```python
from .routers import draws as draws_router
from .database import init_db

app.include_router(draws_router.router)


@app.on_event("startup")
def _startup():
    init_db()
```

- [ ] **Step 5: 跑全部后端测试确认通过**

Run: `cd webservice/backend && pytest -v`
Expected: 全部 PASS（health/model/validation/schemas/auth/draws）。

- [ ] **Step 6: 提交**

```bash
git add webservice/backend
git commit -m "feat(web): 开奖CRUD与列表API"
```

---

### Task 7: 后端 Dockerfile + .env.example

**Files:**
- Create: `webservice/backend/Dockerfile`
- Create: `webservice/backend/.env.example`
- Create: `webservice/backend/.dockerignore`

**Interfaces:**
- Produces: 可构建的后端镜像，监听 `8000`，SQLite 默认落在 `/data/lottery.db`。

- [ ] **Step 1: 写 .env.example**

`webservice/backend/.env.example`：
```
DATABASE_URL=sqlite:////data/lottery.db
API_TOKEN=请改成长随机串
ADMIN_PASSWORD=请改成强密码
READ_REQUIRES_AUTH=true
CORS_ORIGINS=*
```

- [ ] **Step 2: 写 .dockerignore**

`webservice/backend/.dockerignore`：
```
.venv
__pycache__
*.pyc
tests
.env
lottery.db
```

- [ ] **Step 3: 写 Dockerfile**

`webservice/backend/Dockerfile`：
```dockerfile
FROM python:3.12-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1 DATABASE_URL=sqlite:////data/lottery.db

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN mkdir -p /data
VOLUME ["/data"]
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 4: 构建并冒烟验证**

Run:
```bash
cd webservice/backend && docker build -t lottery-api . && \
docker run -d --name lottery-api-test -p 8001:8000 -e API_TOKEN=t -e ADMIN_PASSWORD=p lottery-api && \
sleep 3 && curl -s localhost:8001/healthz
```
Expected: 输出 `{"status":"ok"}`。
清理：`docker rm -f lottery-api-test`

- [ ] **Step 5: 提交**

```bash
git add webservice/backend/Dockerfile webservice/backend/.env.example webservice/backend/.dockerignore
git commit -m "feat(web): 后端 Dockerfile 与环境样例"
```

---

### Task 8: 前端脚手架 + API 客户端 + 校验

**Files:**
- Create: `webservice/frontend/package.json`
- Create: `webservice/frontend/vite.config.ts`
- Create: `webservice/frontend/tsconfig.json`
- Create: `webservice/frontend/index.html`
- Create: `webservice/frontend/src/main.tsx`
- Create: `webservice/frontend/src/api.ts`
- Create: `webservice/frontend/src/auth.ts`
- Create: `webservice/frontend/src/validation.ts`
- Create: `webservice/frontend/src/__tests__/validation.test.ts`

**Interfaces:**
- Produces:
  - `validation.ts`：`validateNumbers(category: 'ssq'|'dlt', front: number[], back: number[]): string | null`（合法返回 `null`，否则返回中文错误）；`RULES`。
  - `auth.ts`：`getToken(): string | null`、`setToken(t: string)`、`clearToken()`。
  - `api.ts`：类型 `Draw`、`DrawList`；函数 `login(password)`、`listDraws(category?, page?)`、`getDraw(category, issue)`、`upsertDraw(draw)`、`deleteDraw(category, issue)`（自动带 `Bearer` 头）。

- [ ] **Step 1: 写 package.json**

`webservice/frontend/package.json`：
```json
{
  "name": "lottery-frontend",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "test": "vitest run"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.24.0"
  },
  "devDependencies": {
    "@testing-library/react": "^16.0.0",
    "@testing-library/jest-dom": "^6.4.6",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.1",
    "jsdom": "^24.1.0",
    "typescript": "^5.5.3",
    "vite": "^5.3.3",
    "vitest": "^2.0.2"
  }
}
```

- [ ] **Step 2: 写配置文件**

`webservice/frontend/tsconfig.json`：
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noEmit": true,
    "types": ["vitest/globals", "@testing-library/jest-dom"]
  },
  "include": ["src"]
}
```
`webservice/frontend/vite.config.ts`：
```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: { proxy: { "/api": "http://localhost:8000" } },
  test: { environment: "jsdom", globals: true },
});
```
`webservice/frontend/index.html`：
```html
<!doctype html>
<html lang="zh-CN">
  <head><meta charset="UTF-8" /><title>开奖录入</title></head>
  <body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body>
</html>
```

- [ ] **Step 3: 安装依赖**

Run: `cd webservice/frontend && npm install`
Expected: 安装成功。

- [ ] **Step 4: 写失败测试**

`webservice/frontend/src/__tests__/validation.test.ts`：
```typescript
import { describe, it, expect } from "vitest";
import { validateNumbers } from "../validation";

describe("validateNumbers", () => {
  it("ssq valid -> null", () => {
    expect(validateNumbers("ssq", [1, 2, 3, 4, 5, 6], [16])).toBeNull();
  });
  it("dlt valid -> null", () => {
    expect(validateNumbers("dlt", [1, 2, 3, 4, 35], [1, 12])).toBeNull();
  });
  it("ssq wrong count -> error", () => {
    expect(validateNumbers("ssq", [1, 2, 3], [16])).toContain("6");
  });
  it("ssq out of range -> error", () => {
    expect(validateNumbers("ssq", [1, 2, 3, 4, 5, 34], [16])).toContain("33");
  });
  it("ssq duplicate -> error", () => {
    expect(validateNumbers("ssq", [1, 2, 3, 4, 5, 5], [16])).toContain("重复");
  });
});
```

- [ ] **Step 5: 跑测试确认失败**

Run: `cd webservice/frontend && npm test`
Expected: FAIL（`../validation` 不存在）。

- [ ] **Step 6: 写 validation.ts**

`webservice/frontend/src/validation.ts`：
```typescript
export type Category = "ssq" | "dlt";

export const RULES: Record<Category, { fc: number; fmax: number; bc: number; bmax: number }> = {
  ssq: { fc: 6, fmax: 33, bc: 1, bmax: 16 },
  dlt: { fc: 5, fmax: 35, bc: 2, bmax: 12 },
};

function check(name: string, nums: number[], count: number, max: number): string | null {
  if (nums.length !== count) return `${name}必须为 ${count} 个号码`;
  if (new Set(nums).size !== nums.length) return `${name}不能重复`;
  for (const n of nums) {
    if (!Number.isInteger(n) || n < 1 || n > max) return `${name}范围应为 1-${max}`;
  }
  return null;
}

export function validateNumbers(category: Category, front: number[], back: number[]): string | null {
  const r = RULES[category];
  if (!r) return `未知彩种: ${category}`;
  return check("前区/红球", front, r.fc, r.fmax) ?? check("后区/蓝球", back, r.bc, r.bmax);
}
```

- [ ] **Step 7: 写 auth.ts 与 api.ts**

`webservice/frontend/src/auth.ts`：
```typescript
const KEY = "lottery_token";
export const getToken = () => localStorage.getItem(KEY);
export const setToken = (t: string) => localStorage.setItem(KEY, t);
export const clearToken = () => localStorage.removeItem(KEY);
```
`webservice/frontend/src/api.ts`：
```typescript
import { getToken } from "./auth";
import type { Category } from "./validation";

export interface Draw {
  category: Category;
  issue: string;
  frontNumbers: number[];
  backNumbers: number[];
  drawDate?: string | null;
  prizes?: Record<string, number> | null;
  createdAt?: string;
  updatedAt?: string;
}
export interface DrawList { items: Draw[]; total: number; page: number; pageSize: number; }

async function req(path: string, init: RequestInit = {}) {
  const headers: Record<string, string> = { "Content-Type": "application/json", ...(init.headers as any) };
  const t = getToken();
  if (t) headers["Authorization"] = `Bearer ${t}`;
  const res = await fetch(`/api/v1${path}`, { ...init, headers });
  if (!res.ok) {
    const detail = await res.json().catch(() => ({}));
    throw new Error(detail.detail || `请求失败 ${res.status}`);
  }
  return res.status === 204 ? null : res.json();
}

export const login = (password: string): Promise<{ token: string }> =>
  req("/auth/login", { method: "POST", body: JSON.stringify({ password }) });
export const listDraws = (category?: string, page = 1): Promise<DrawList> =>
  req(`/draws?${category ? `category=${category}&` : ""}page=${page}`);
export const getDraw = (category: string, issue: string): Promise<Draw> =>
  req(`/draws/${category}/${issue}`);
export const upsertDraw = (draw: Draw): Promise<Draw> =>
  req("/draws", { method: "POST", body: JSON.stringify(draw) });
export const deleteDraw = (category: string, issue: string): Promise<null> =>
  req(`/draws/${category}/${issue}`, { method: "DELETE" });
```

- [ ] **Step 8: 写最小 main.tsx 占位（保证可编译）**

`webservice/frontend/src/main.tsx`：
```typescript
import React from "react";
import ReactDOM from "react-dom/client";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode><div>开奖录入服务</div></React.StrictMode>,
);
```

- [ ] **Step 9: 跑测试确认通过**

Run: `cd webservice/frontend && npm test`
Expected: PASS（validation 测试全过）。

- [ ] **Step 10: 提交**

```bash
git add webservice/frontend
git commit -m "feat(web): 前端脚手架+API客户端+号码校验"
```

---

### Task 9: 前端页面（登录 / 列表 / 录入 / 详情）+ 路由

**Files:**
- Create: `webservice/frontend/src/pages/LoginPage.tsx`
- Create: `webservice/frontend/src/pages/DrawListPage.tsx`
- Create: `webservice/frontend/src/pages/DrawFormPage.tsx`
- Create: `webservice/frontend/src/pages/DrawDetailPage.tsx`
- Create: `webservice/frontend/src/App.tsx`
- Modify: `webservice/frontend/src/main.tsx`（接入 Router + App）
- Create: `webservice/frontend/src/__tests__/DrawFormPage.test.tsx`

**Interfaces:**
- Consumes: `api.ts`、`auth.ts`、`validation.ts`、`react-router-dom`。
- Produces: 4 个页面组件 + `App`（路由：`/login`、`/`列表、`/new`录入、`/edit/:category/:issue`编辑、`/draw/:category/:issue`详情）。`DrawFormPage` 在号码非法时显示错误且不提交。

- [ ] **Step 1: 写 DrawFormPage 失败测试**

`webservice/frontend/src/__tests__/DrawFormPage.test.tsx`：
```typescript
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import DrawFormPage from "../pages/DrawFormPage";

vi.mock("../api", () => ({ upsertDraw: vi.fn().mockResolvedValue({}) }));
import { upsertDraw } from "../api";

function renderForm() {
  render(<MemoryRouter><DrawFormPage /></MemoryRouter>);
}

describe("DrawFormPage", () => {
  it("非法号码时报错且不提交", async () => {
    renderForm();
    fireEvent.change(screen.getByLabelText("期数"), { target: { value: "24001" } });
    fireEvent.change(screen.getByLabelText("前区/红球"), { target: { value: "1 2 3" } });
    fireEvent.change(screen.getByLabelText("后区/蓝球"), { target: { value: "16" } });
    fireEvent.click(screen.getByText("保存"));
    expect(await screen.findByRole("alert")).toBeInTheDocument();
    expect(upsertDraw).not.toHaveBeenCalled();
  });

  it("合法号码时提交", async () => {
    renderForm();
    fireEvent.change(screen.getByLabelText("期数"), { target: { value: "24001" } });
    fireEvent.change(screen.getByLabelText("前区/红球"), { target: { value: "1 2 3 4 5 6" } });
    fireEvent.change(screen.getByLabelText("后区/蓝球"), { target: { value: "16" } });
    fireEvent.click(screen.getByText("保存"));
    await vi.waitFor(() => expect(upsertDraw).toHaveBeenCalledOnce());
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd webservice/frontend && npm test src/__tests__/DrawFormPage.test.tsx`
Expected: FAIL（`DrawFormPage` 不存在）。

- [ ] **Step 3: 写 DrawFormPage.tsx**

`webservice/frontend/src/pages/DrawFormPage.tsx`：
```typescript
import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { upsertDraw } from "../api";
import { validateNumbers, type Category } from "../validation";

const parse = (s: string): number[] =>
  s.split(/[\s,]+/).filter(Boolean).map((x) => parseInt(x, 10));

export default function DrawFormPage() {
  const nav = useNavigate();
  const params = useParams();
  const [category, setCategory] = useState<Category>((params.category as Category) || "ssq");
  const [issue, setIssue] = useState(params.issue || "");
  const [front, setFront] = useState("");
  const [back, setBack] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    const f = parse(front);
    const b = parse(back);
    const err = !issue ? "请填写期数" : validateNumbers(category, f, b);
    if (err) { setError(err); return; }
    try {
      await upsertDraw({ category, issue, frontNumbers: f, backNumbers: b });
      nav("/");
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div>
      <h2>录入 / 编辑开奖</h2>
      {error && <div role="alert" style={{ color: "crimson" }}>{error}</div>}
      <label>彩种
        <select value={category} onChange={(e) => setCategory(e.target.value as Category)}>
          <option value="ssq">双色球</option>
          <option value="dlt">大乐透</option>
        </select>
      </label>
      <label htmlFor="issue">期数</label>
      <input id="issue" value={issue} onChange={(e) => setIssue(e.target.value)} />
      <label htmlFor="front">前区/红球</label>
      <input id="front" value={front} onChange={(e) => setFront(e.target.value)} placeholder="空格分隔" />
      <label htmlFor="back">后区/蓝球</label>
      <input id="back" value={back} onChange={(e) => setBack(e.target.value)} placeholder="空格分隔" />
      <button onClick={submit}>保存</button>
    </div>
  );
}
```

- [ ] **Step 4: 跑 DrawFormPage 测试确认通过**

Run: `cd webservice/frontend && npm test src/__tests__/DrawFormPage.test.tsx`
Expected: PASS。

- [ ] **Step 5: 写 LoginPage.tsx**

`webservice/frontend/src/pages/LoginPage.tsx`：
```typescript
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { login } from "../api";
import { setToken } from "../auth";

export default function LoginPage() {
  const nav = useNavigate();
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    try {
      const { token } = await login(password);
      setToken(token);
      nav("/");
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div>
      <h2>登录</h2>
      {error && <div role="alert" style={{ color: "crimson" }}>{error}</div>}
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="口令" />
      <button onClick={submit}>登录</button>
    </div>
  );
}
```

- [ ] **Step 6: 写 DrawListPage.tsx**

`webservice/frontend/src/pages/DrawListPage.tsx`：
```typescript
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { listDraws, type Draw } from "../api";

export default function DrawListPage() {
  const [items, setItems] = useState<Draw[]>([]);
  const [category, setCategory] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listDraws(category || undefined).then((r) => setItems(r.items)).catch((e) => setError(e.message));
  }, [category]);

  return (
    <div>
      <h2>开奖列表</h2>
      <Link to="/new">+ 录入</Link>
      <select value={category} onChange={(e) => setCategory(e.target.value)}>
        <option value="">全部</option>
        <option value="ssq">双色球</option>
        <option value="dlt">大乐透</option>
      </select>
      {error && <div role="alert">{error}</div>}
      <ul>
        {items.map((d) => (
          <li key={`${d.category}-${d.issue}`}>
            <Link to={`/draw/${d.category}/${d.issue}`}>
              [{d.category}] {d.issue} — {d.frontNumbers.join(" ")} + {d.backNumbers.join(" ")}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

- [ ] **Step 7: 写 DrawDetailPage.tsx**

`webservice/frontend/src/pages/DrawDetailPage.tsx`：
```typescript
import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getDraw, type Draw } from "../api";

export default function DrawDetailPage() {
  const { category = "", issue = "" } = useParams();
  const [draw, setDraw] = useState<Draw | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getDraw(category, issue).then(setDraw).catch((e) => setError(e.message));
  }, [category, issue]);

  if (error) return <div role="alert">{error}</div>;
  if (!draw) return <div>加载中…</div>;
  return (
    <div>
      <Link to="/">← 返回</Link>
      <h2>[{draw.category}] {draw.issue}</h2>
      <p>号码：{draw.frontNumbers.join(" ")} + {draw.backNumbers.join(" ")}</p>
      <p>开奖日期：{draw.drawDate || "—"}</p>
      <p>奖金：{draw.prizes ? JSON.stringify(draw.prizes) : "—"}</p>
      <Link to={`/edit/${draw.category}/${draw.issue}`}>编辑</Link>
    </div>
  );
}
```

- [ ] **Step 8: 写 App.tsx 与接入 main.tsx**

`webservice/frontend/src/App.tsx`：
```typescript
import { Navigate, Route, Routes } from "react-router-dom";
import { getToken } from "./auth";
import LoginPage from "./pages/LoginPage";
import DrawListPage from "./pages/DrawListPage";
import DrawFormPage from "./pages/DrawFormPage";
import DrawDetailPage from "./pages/DrawDetailPage";

function RequireAuth({ children }: { children: JSX.Element }) {
  return getToken() ? children : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/" element={<RequireAuth><DrawListPage /></RequireAuth>} />
      <Route path="/new" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/edit/:category/:issue" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/draw/:category/:issue" element={<RequireAuth><DrawDetailPage /></RequireAuth>} />
    </Routes>
  );
}
```
修改 `webservice/frontend/src/main.tsx`：
```typescript
import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter><App /></BrowserRouter>
  </React.StrictMode>,
);
```

- [ ] **Step 9: 跑全部前端测试 + 构建确认通过**

Run: `cd webservice/frontend && npm test && npm run build`
Expected: 测试 PASS；`npm run build` 生成 `dist/` 无 TS 错误。

- [ ] **Step 10: 提交**

```bash
git add webservice/frontend
git commit -m "feat(web): 前端登录/列表/录入/详情页与路由"
```

---

### Task 10: 前端 Dockerfile + nginx

**Files:**
- Create: `webservice/frontend/nginx.conf`
- Create: `webservice/frontend/Dockerfile`
- Create: `webservice/frontend/.dockerignore`

**Interfaces:**
- Produces: 前端镜像（nginx 托管 `dist/`，`/api` 反代到 `api:8000`，SPA fallback 到 `index.html`）。

- [ ] **Step 1: 写 nginx.conf**

`webservice/frontend/nginx.conf`：
```nginx
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;

  location /api/ {
    proxy_pass http://api:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  location / {
    try_files $uri $uri/ /index.html;
  }
}
```

- [ ] **Step 2: 写 .dockerignore**

`webservice/frontend/.dockerignore`：
```
node_modules
dist
```

- [ ] **Step 3: 写多阶段 Dockerfile**

`webservice/frontend/Dockerfile`：
```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

- [ ] **Step 4: 构建验证**

Run: `cd webservice/frontend && docker build -t lottery-web .`
Expected: 构建成功（包含 npm run build 阶段）。

- [ ] **Step 5: 提交**

```bash
git add webservice/frontend/nginx.conf webservice/frontend/Dockerfile webservice/frontend/.dockerignore
git commit -m "feat(web): 前端 Dockerfile 与 nginx 反代"
```

---

### Task 11: docker-compose + 部署文档 + 端到端冒烟

**Files:**
- Create: `webservice/docker-compose.yml`
- Create: `webservice/DEPLOY.md`
- Create: `webservice/README.md`

**Interfaces:**
- Produces: 一键启动编排（web + api；可选 postgres profile）；部署/升级/切库指南。

- [ ] **Step 1: 写 docker-compose.yml**

`webservice/docker-compose.yml`：
```yaml
services:
  api:
    build: ./backend
    environment:
      DATABASE_URL: ${DATABASE_URL:-sqlite:////data/lottery.db}
      API_TOKEN: ${API_TOKEN:?must set}
      ADMIN_PASSWORD: ${ADMIN_PASSWORD:?must set}
      READ_REQUIRES_AUTH: ${READ_REQUIRES_AUTH:-true}
      CORS_ORIGINS: ${CORS_ORIGINS:-*}
    volumes:
      - ./data:/data
    restart: unless-stopped

  web:
    build: ./frontend
    ports:
      - "8080:80"
    depends_on:
      - api
    restart: unless-stopped

  # 可选：docker compose --profile pg up -d
  postgres:
    image: postgres:16-alpine
    profiles: ["pg"]
    environment:
      POSTGRES_USER: lottery
      POSTGRES_PASSWORD: lottery
      POSTGRES_DB: lottery
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    restart: unless-stopped
```

- [ ] **Step 2: 写 DEPLOY.md**

`webservice/DEPLOY.md`：
```markdown
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

访问前端：`http://<服务器IP>:8080`；API 健康检查：`http://<服务器IP>:8080/api/v1`（FastAPI 文档在 api 容器 `:8000/docs`）。

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
```

- [ ] **Step 3: 写 README.md**

`webservice/README.md`：
```markdown
# 彩票开奖录入 Web 服务

网页手动录入双色球/大乐透开奖（号码 + 可选奖金），提供 REST API 供 Mac App 拉取。

- 后端：FastAPI（`backend/`），API 见 `/docs`（Swagger）。
- 前端：React + Vite（`frontend/`）。
- 部署：见 `DEPLOY.md`。

## 本地开发
后端：`cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload`
前端：`cd frontend && npm install && npm run dev`（已配 `/api` 代理到 :8000）

## API 契约（/api/v1，JSON camelCase）
- `POST /auth/login {password}` → `{token}`
- `GET  /draws/{category}/{issue}` → 开奖（404 不存在）
- `GET  /draws?category=&page=&pageSize=` → 列表
- `POST /draws`（Bearer）→ upsert
- `DELETE /draws/{category}/{issue}`（Bearer）
```

- [ ] **Step 4: 端到端冒烟验证**

Run:
```bash
cd webservice && API_TOKEN=t ADMIN_PASSWORD=p docker compose up -d --build && sleep 6 && \
curl -s -X POST localhost:8080/api/v1/auth/login -H 'Content-Type: application/json' -d '{"password":"p"}' && echo && \
curl -s -X POST localhost:8080/api/v1/draws -H 'Authorization: Bearer t' -H 'Content-Type: application/json' \
  -d '{"category":"ssq","issue":"24001","frontNumbers":[1,2,3,4,5,6],"backNumbers":[16]}' && echo && \
curl -s localhost:8080/api/v1/draws/ssq/24001 -H 'Authorization: Bearer t' && echo
```
Expected: 依次返回 `{"token":"t"}`、创建的开奖 JSON、查询到的开奖 JSON。
清理：`cd webservice && docker compose down`

- [ ] **Step 5: 提交**

```bash
git add webservice/docker-compose.yml webservice/DEPLOY.md webservice/README.md
git commit -m "feat(web): docker-compose 编排+部署指南+端到端冒烟"
```

---

## Self-Review

**1. Spec coverage（对照 `2026-06-23-lottery-webservice-design.md`）**
- 前后端分离 React + FastAPI → Task 1-6（后端）/ 8-9（前端）✓
- 共享 Token 鉴权 + 登录 → Task 5 ✓
- SQLite 默认 + 卷挂载 + 可切 Postgres → Task 2/7（VOLUME `/data`）、Task 11（compose 卷 + pg profile + 腾讯云说明）✓
- 号码必填 + 可选奖金 + 校验规则 → Task 3/4 ✓
- API 契约（GET 单条/列表、POST upsert、DELETE、login、healthz、camelCase）→ Task 1/5/6 ✓
- 号码越界/重复/个数错误 422，重复期数 upsert，401 鉴权 → Task 6 测试覆盖 ✓
- 多阶段 Dockerfile + nginx 反代 + docker-compose + 部署/升级/切库/备份指南 → Task 7/10/11 ✓
- 测试：后端 API/校验/鉴权/upsert/切库（SQLite 内存）单测、前端校验 + 表单组件测、compose 端到端冒烟 → Task 2-6/8-9/11 ✓

**2. Placeholder scan**：无 TBD/TODO；每个写代码步骤均含完整代码与确切命令、预期输出。

**3. Type consistency**：
- 后端字段 snake_case（`front_numbers`），API JSON camelCase（`frontNumbers`）经 `to_camel` 别名统一；`DrawIn/DrawOut/DrawList` 与路由返回一致。
- `validate_numbers(category, front, back)` 后端、`validateNumbers(category, front, back)` 前端 同名同义、规则常量一致。
- `api.ts` 的 `Draw/DrawList` 字段与后端 `DrawOut/DrawList`（camelCase）对齐；`login/getDraw/listDraws/upsertDraw/deleteDraw` 与后端路由一致。
- `getToken/setToken/clearToken` 在 auth.ts 定义并被 api.ts/页面一致使用。

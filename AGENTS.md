# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

A lottery-checking (验奖) toolkit for China's **大乐透 (dlt)** and **双色球 (ssq)** lotteries, made of two independent subprojects that talk over HTTP:

- **Mac App** — `LotteryKit/` (logic, a local SwiftPM package) + `LotteryApp/` (Xcode macOS app project, SwiftUI sources in `LotteryApp/LotteryApp/`). Photo of a ticket → multimodal model recognizes numbers → user confirms → fetch official/self-hosted draw results → evaluate prizes → record & chart.
- **Web service** — `webservice/` (React+Vite frontend, FastAPI+SQLite/Postgres backend). Manual entry of draw numbers + optional prize amounts; exposes a REST API that the Mac App consumes as one data source.

## Commands

**Mac App logic (`LotteryKit/`)** — requires the **full Xcode** toolchain (not just Command Line Tools) because SwiftData uses a macro plugin:
```bash
cd LotteryKit
swift test                                          # all tests
swift test --filter PrizeEvaluatorDLTTests          # single test class
# If the system default is still Command Line Tools, prefix:
# DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
Building/running the `.app` uses the existing `LotteryApp/LotteryApp.xcodeproj`, which references `LotteryKit/` as a local package — see `XCODE-SETUP.md`. The SwiftUI layer is **not** part of `swift test`; it only builds inside the Xcode project.

**Mac App (`LotteryApp/`)**:
```bash
open LotteryApp/LotteryApp.xcodeproj
script/build_and_run.sh          # command-line build + run
script/build_and_run.sh --verify # build + launch smoke check
```

**Web backend (`webservice/backend/`)** — Python 3.12:
```bash
pip install -r requirements.txt
uvicorn app.main:app --reload          # serves on :8000, Swagger at /docs
pytest                                  # all tests
pytest tests/test_draws_api.py -k upsert
```

**Web frontend (`webservice/frontend/`)**:
```bash
npm install
npm run dev          # Vite dev server, /api proxied to :8000
npm test             # vitest
npm run build
```

Docker deployment: `webservice/docker-compose.yml` (details in `webservice/DEPLOY.md`).

## Architecture

### Mac App data model (SwiftData, `LotteryKit/Sources/LotteryKit/Models/`)
The model is **ticket-centric with immutable, versioned draw results** — this is the core design decision and drives most logic:

- **`Ticket`** — one purchased ticket (category, issue, `[Bet]`, image, cost). Has many `VerificationRecord`s (cascade delete).
- **`Draw`** — uniquely identified by `(category, issue, source)`. Has many `DrawVersion`s.
- **`DrawVersion`** — an **immutable** snapshot of draw numbers/prizes. `origin` is `"fetched"` (from network) or `"manual"` (user-entered/edited). Editing never mutates a version; `Store.addVersion` always appends a new incrementing `versionNumber`.
- **`VerificationRecord`** — links a `Ticket` to a specific `DrawVersion` and stores a `[BetResultSnapshot]` (frozen result). Re-verifying with a different source/version produces a new record, never overwrites.

`Store` (`Persistence/Store.swift`) is the single `@MainActor` gateway to the `ModelContext` — all fetch/insert/save goes through it. `latestVersion` = max `versionNumber`.

### Draw fetching (`DataSources/`)
`DrawFetchService` is **cache-first**: it returns the cached latest version unless `forceRefresh`, and only appends a new version when fetched numbers differ from the latest. Data sources conform to `DrawDataSource`:
- `SportteryDataSource` → 大乐透 only (`.officialSporttery` ⇒ `.dlt`)
- `CWLDataSource` → 双色球 only (`.officialCWL` ⇒ `.ssq`)
- `WebServiceDataSource` → the self-hosted web service (any category, configured in Settings)
- `manual` → user-entered, no network

`DataSourceKind.category` encodes which official source serves which lottery. `AppModel.availableSources(for:)` filters the user's `sourcePriority` by category + config. **Official endpoints have anti-bot/geo restrictions** and may fail live; parsing has unit-test coverage but adjust each source's `parse` to match real responses. Manual entry is the always-available fallback.

### Prize evaluation (`Logic/PrizeEvaluator.swift`)
Pure function over `(category, bet, drawFront, drawBack, prizes)`. Tier tables `ssqTier`/`dltTier` return `(tierName, fixedAmount?)`. **Fixed-amount tiers are hardcoded; floating tiers (一/二等奖) return `nil` and the amount is looked up from the `DrawVersion.prizes` dict.** Category rules (counts/max) live in `Category.swift`. Currently single bets (单式) only; 复式/胆拖 are stubbed "开发中".

### Recognition (`Recognition/VisionRecognizer.swift`)
`OpenAIVisionRecognizer` calls an OpenAI-compatible `/chat/completions` endpoint (configurable base URL / key / model in Settings) and expects strict-JSON category+issue+numbers back, which the user then confirms/edits before verifying.

### Web service (`webservice/backend/app/`)
Standard FastAPI layout: `routers/` (auth, draws) → `schemas.py` (Pydantic, **camelCase** over the wire) → `models.py` (SQLAlchemy) → `database.py`. Auth is a shared password → Bearer token (`auth.py`). `config.py` reads env (`.env`): `database_url`, `api_token`, `admin_password`, `read_requires_auth`, `cors_origins`. SQLite by default (file mounted to host so restarts persist), swappable to Postgres. API contract is documented in `webservice/README.md` (`/api/v1`).

## Public Repository Safety
- This GitHub repository is public. Treat all committed content, including Git history, as publicly visible.
- Never commit secrets, tokens, passwords, private keys, real `.env` files, production database files, personal ticket images/data, or machine-local build/runtime artifacts.
- Before committing or pushing, review `git status`, staged diffs, and newly added files for sensitive content. If a leak is suspected, stop and ask before committing; rotating the secret is required even if the file is later removed.
- Keep `.env`, SQLite/Postgres data directories, Xcode/SwiftPM build outputs, `xcuserdata`, `.DS_Store`, and similar local-only files ignored.

## Conventions
- `LotteryKit` has **no third-party dependencies** and is the place for all testable logic; keep view code in `LotteryApp/LotteryApp/` thin.
- Category and source identifiers are stored as `rawValue` strings in SwiftData (`"ssq"`, `"dlt"`, `"manual"`, etc.) — use the enums, not literals, in new code.
- Web API JSON is camelCase even though Python is snake_case (Pydantic aliases handle the mapping).
- Design docs: `docs/superpowers/specs/` (specs) and `docs/superpowers/plans/` (plans); architecture diagrams in `docs/design-diagrams.html`.

## Imported Claude Cowork project instructions

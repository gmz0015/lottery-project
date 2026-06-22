from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import init_db
from .routers import auth as auth_router
from .routers import draws as draws_router

app = FastAPI(title="Lottery Draws Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(draws_router.router)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.on_event("startup")
def _startup():
    init_db()

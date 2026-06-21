from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app import models
from app.config import CORS_ORIGINS
from app.database import SessionLocal, engine
from app.routes import game, sessions, telemetry


def _run_migrations() -> None:
    """Применяет SQL-миграции при каждом старте (все операции идемпотентны)."""
    migrations_dir = Path(__file__).resolve().parents[1] / "migrations"
    if not migrations_dir.is_dir():
        return

    for migration_path in sorted(migrations_dir.glob("*.sql")):
        sql = migration_path.read_text(encoding="utf-8")
        sql = "\n".join(
            line for line in sql.splitlines() if not line.strip().startswith("--")
        )
        statements = [
            statement.strip()
            for statement in sql.split(";")
            if statement.strip()
        ]
        with engine.begin() as conn:
            for statement in statements:
                conn.execute(text(statement))


@asynccontextmanager
async def lifespan(app: FastAPI):
    models.Base.metadata.create_all(bind=engine)
    _run_migrations()
    yield


app = FastAPI(
    title="Game Telemetry API",
    description="""
    **API для сбора игровой телеметрии и адаптивного геймдизайна**

    Единая точка входа для Godot-плагина:
    * Сессии и события
    * `/telemetry/ingest` — сохранение + ML-предсказание каждые N событий
    * `/game/train` — запуск обучения модели на накопленных данных
    """,
    version="0.4.0",
    lifespan=lifespan,
    swagger_ui_parameters={"defaultModelsExpandDepth": -1},
)

_allow_credentials = "*" not in CORS_ORIGINS
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS if CORS_ORIGINS else ["*"],
    allow_credentials=_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(game.router)
app.include_router(telemetry.router)
app.include_router(sessions.router)


@app.get("/health", tags=["health"])
def health_check():
    db_status = "unavailable"
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        db_status = "ok"
    except SQLAlchemyError:
        pass
    return {"status": "ok", "database": db_status}

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import SQLAlchemyError

# Импортируем роутеры
from gamedb_backend.routes import sessions, test, game
from gamedb_backend.database import engine, SessionLocal
from gamedb_backend import models

# Создаём экземпляр приложения FastAPI
app = FastAPI(
    title="Game Telemetry API",
    description="""
    **API для сбора игровой телеметрии и адаптивного геймдизайна**

    Этот API позволяет:
    * Регистрировать игровые сессии и события
    * Получать текущие параметры адаптации для игрока
    * Сохранять прогнозы ML-моделей

    Все данные хранятся в PostgreSQL. Документация описывает доступные endpoints.
    """,
    version="0.2.0",
)

# Настройка CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключаем роутеры
app.include_router(sessions.router)      # /sessions
app.include_router(test.router, prefix="/api")  # /api/test
app.include_router(game.router)          # /game/...

# Корневой эндпоинт
@app.get("/", tags=["root"], summary="Корневой эндпоинт")
def root():
    """Возвращает приветственное сообщение."""
    return {"message": "Game Telemetry API is running"}

# Эндпоинт для проверки здоровья (с проверкой БД)
@app.get("/health", tags=["health"], summary="Проверка здоровья сервиса")
def health_check():
    """Проверяет, что API работает и база данных доступна."""
    try:
        # Пытаемся выполнить простой запрос к БД
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        db_status = "ok"
    except SQLAlchemyError:
        db_status = "unavailable"
    return {
        "status": "ok",
        "database": db_status
    }
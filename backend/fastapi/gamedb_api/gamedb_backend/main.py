from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Импортируем роутеры (убедись, что они существуют по указанным путям)
from gamedb_backend.routes import sessions, test, game


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

# Настройка CORS (разрешаем запросы с любых источников для разработки)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Разрешить все источники (для продакшена заменить на конкретные домены)
    allow_credentials=True,
    allow_methods=["*"],  # Разрешить все HTTP-методы (GET, POST и т.д.)
    allow_headers=["*"],  # Разрешить все заголовки
)

# Подключаем роутеры с префиксами
app.include_router(sessions.router)  # все эндпоинты /sessions
app.include_router(test.router, prefix="/api")  # тестовый эндпоинт /api/test
app.include_router(game.router)


# Корневой эндпоинт для проверки
@app.get("/", tags=["root"], summary="Корневой эндпоинт")
def root():
    """Возвращает приветственное сообщение."""
    return {"message": "Game Telemetry API is running"}


# Эндпоинт для проверки здоровья (можно использовать для мониторинга)
@app.get("/health", tags=["health"], summary="Проверка здоровья сервиса")
def health_check():
    """Проверяет, что API работает и может подключаться к БД."""
    # Здесь можно добавить проверку соединения с БД
    return {"status": "ok"}
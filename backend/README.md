# Game Telemetry API

Единая точка входа для Godot-плагина. Контракт: [docs/integration.md](../docs/integration.md).

## Docker (рекомендуется)

Из **корня** репозитория:

```powershell
docker compose up --build -d
```

- API: http://localhost:8000/docs  
- ML: http://localhost:8001/health  

## Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME` | PostgreSQL | см. `app/config.py` |
| `ML_SERVICE_URL` | URL ML-service | в compose: `http://ml:8001` |
| `ML_PREDICT_ENABLED` | Вызывать ML | `true` в compose |
| `BOOTSTRAP_ACTIONS` | Порог событий для prediction | `10` |
| `MODELS_DIR` | Каталог ONNX | `/app/models` |

Без ML включён встроенный fallback в `app/services/ml_client.py`.

## Эндпоинты

| Метод | Путь | Назначение |
|-------|------|------------|
| POST | `/game/session/start` | Новая сессия |
| PATCH | `/game/session/{id}/end` | Завершить сессию |
| POST | `/telemetry/ingest` | Ingest + prediction + adaptation |
| GET | `/game/adaptation/{session_id}` | Параметры адаптации |
| PUT/GET | `/game/profile` | Профиль модели |
| GET | `/game/model/manifest` | Манифест ONNX |
| GET | `/game/model/download` | Скачать ONNX |
| GET | `/sessions/{id}/prediction/latest` | Последний прогноз |

## Seed и тесты

```powershell
cd backend
pip install -r requirements.txt
$env:DB_HOST="localhost"; $env:DB_PASSWORD="postgres"
python scripts/seed_data.py --sessions 100 --events-per-session 10

pip install -r requirements-dev.txt
pytest tests/ -v
```

Unit без БД: `pytest tests/test_features.py -v`

## Схема БД

Миграции в `migrations/` (например `001_schema.sql`) применяются при старте API.

Корневые скрипты: `scripts/dev-up.ps1`, `scripts/seed.ps1`. Основные таблицы: `players`, `game_models`, `sessions`, `events`, `predictions`.

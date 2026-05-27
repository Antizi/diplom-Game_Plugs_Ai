# Game Telemetry API (backend)

Единая точка входа для Godot-плагина по контракту [docs/Max.md](../../docs/Max.md).

## Запуск (Docker)

```powershell
cd backend/gamedb_api
# .env или переменные окружения:
# POSTGRES_PASSWORD=postgres

docker compose up --build -d
```

- API: http://localhost:8000/docs  
- Health: http://localhost:8000/health  

## Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME` | PostgreSQL | см. `config.py` |
| `POSTGRES_PASSWORD` | Пароль в docker-compose | `postgres` |
| `ML_SERVICE_URL` | URL внешнего ML-service (другая команда) | пусто |
| `ML_PREDICT_ENABLED` | Вызывать ML-service | `false` |
| `BOOTSTRAP_ACTIONS` | Порог событий для prediction | `10` |
| `MODELS_DIR` | Каталог ONNX для `/game/model/download` | `/app/models` |
| `CORS_ORIGINS` | Origins через запятую | `*` |

Без ML-service backend использует встроенную эвристику (`heuristic-0.1`).

## Основные эндпоинты

| Метод | Путь | Назначение |
|-------|------|------------|
| POST | `/game/session/start` | Новая сессия |
| PATCH | `/game/session/{id}/end` | Завершить сессию |
| POST | `/telemetry/ingest` | Ingest + фичи + prediction + adaptation |
| GET | `/game/adaptation/{session_id}` | Параметры адаптации |
| PUT/GET | `/game/profile` | Конфигурация модели: версии, признаки, архетипы, критические точки |
| GET | `/game/model/manifest` | Манифест ONNX |
| GET | `/game/model/download` | Скачать ONNX |
| GET | `/sessions/{id}/prediction/latest` | Последний прогноз |
| GET | `/health` | Healthcheck |

## Пример ingest

```bash
curl -X PUT http://localhost:8000/game/profile \
  -H "Content-Type: application/json" \
  -d '{"model_version":"model-1","feature_schema_version":1,"game_profile_version":1,"feature_order":["event_count_first_n","deaths"],"critical_points":[{"name":"deaths","weight":2}],"archetypes":["explorer","achiever"],"bootstrap_actions":10}'

curl -X POST "http://localhost:8000/game/session/start?player_id=p1"

curl -X POST http://localhost:8000/telemetry/ingest \
  -H "Content-Type: application/json" \
  -d '{"events":[{"session_id":"<UUID>","player_id":"p1","event_name":"jump","timestamp":1.0}]}'
```

## Seed тестовых данных

```powershell
$env:DB_HOST="localhost"
$env:DB_PASSWORD="postgres"
python scripts/seed_data.py --sessions 1000 --events-per-session 10 --players 50
```

## Тесты

```powershell
pip install -r requirements-dev.txt
# Postgres должен быть доступен (docker compose up)
pytest tests/ -v
```

Unit-тесты без БД: `pytest tests/test_features.py -v`

## Схема БД (5 таблиц)

При старте API автоматически применяются идемпотентные SQL из `migrations/` (без служебных таблиц учёта).

| Таблица | Назначение | Основные поля |
|---------|------------|----------------|
| `players` | игроки | `player_id`, `created_at` |
| `game_models` | версии + профиль | `model_version`, `game_profile_version`, `feature_schema_version`, `critical_points`, `archetypes`, `feature_schema` (order + bootstrap), `onnx` |
| `sessions` | сессии | `session_id`, `player_id`, `model_id` → FK, `game_version`, `started_at`, `ended_at` |
| `events` | телеметрия | `session_id`, `event_type`, `payload`, `created_at` |
| `predictions` | прогноз | `session_id`, `player_id`, `model_id`, `predicted_archetype`, `confidence`, `result` (JSONB) |

Версии модели и профиля хранятся только в `game_models`; сессии и прогнозы ссылаются на неё через `model_id`.

## Статус по Max.md

- [x] Сессии, ingest, adaptation, game profile, model manifest
- [x] Debug: prediction/latest
- [x] Docker: postgres + backend
- [ ] Аутентификация (API-key)
- [ ] Production Gunicorn
- [ ] Подключение внешнего ML-service (`ML_SERVICE_URL` + `/predict`)

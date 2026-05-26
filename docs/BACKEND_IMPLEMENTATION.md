# Статус реализации по docs/Max.md

## Сделано (этап 1–2)

| Контракт Max.md | Статус |
|-----------------|--------|
| `POST /game/session/start` | ✅ (+ опциональный `game_id`) |
| `PATCH /game/session/{id}/end` | ✅ |
| `POST /game/events` | ✅ legacy |
| `POST /telemetry/ingest` | ✅ сохранение + фичи + ML + adaptation |
| `GET /game/adaptation/{session_id}` | ✅ |
| `PUT/GET /games/{game_id}/profile` | ✅ |
| `GET /games/{game_id}/model/manifest` | ✅ |
| `GET /games/{game_id}/model/download` | ✅ |
| `GET /sessions/{id}/prediction/latest` | ✅ |
| `GET /players/{id}/history` | ✅ |
| Таблицы `game_profiles`, `model_registry` | ✅ + миграция |
| Расширение `adaptation_state`, `predictions` | ✅ миграция |
| 3 контейнера (API, DB, ML) | ✅ docker-compose |
| ML `POST /predict` | ✅ |

## Следующие этапы

- [ ] Аутентификация (API-key / JWT)
- [ ] `POST /ml/train` + пайплайн обучения
- [ ] Unit/integration тесты (pytest)
- [ ] Скрипт seed 1000+ сессий
- [ ] `GET /stats/player/{id}` (аналитика)
- [ ] Production: Gunicorn + workers
- [ ] Синхронизация Godot-плагина с `/telemetry/ingest`

## Запуск

```bash
cd backend/gamedb_api
# .env: POSTGRES_PASSWORD=postgres
docker compose up --build -d
```

Swagger: http://localhost:8000/docs  
ML health: http://localhost:8001/health

## Пример ingest

```bash
# 1. Профиль игры
curl -X PUT http://localhost:8000/games/my_game/profile \
  -H "Content-Type: application/json" \
  -d '{"critical_points":[{"name":"deaths","weight":2}],"archetypes":["explorer","achiever"],"bootstrap_actions":10}'

# 2. Старт сессии
curl -X POST "http://localhost:8000/game/session/start?player_id=p1&game_id=my_game"

# 3. Ingest (подставьте session_id из шага 2)
curl -X POST http://localhost:8000/telemetry/ingest \
  -H "Content-Type: application/json" \
  -d '{"game_id":"my_game","events":[{"session_id":"<UUID>","player_id":"p1","event_name":"jump","timestamp":1.0}]}'
```

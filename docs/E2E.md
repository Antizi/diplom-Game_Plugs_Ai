# E2E: Godot → Backend → ML → адаптация

Пошаговая проверка всей цепочки.

## 1. Поднять стек

```powershell
# из корня репозитория
.\scripts\dev-up.ps1
```

Проверка:

```powershell
curl http://localhost:8000/health
curl http://localhost:8001/health
```

В ответе ML должно быть `"model_loaded": true`, `"model_version": "sklearn-rf-1.0"`.

## 2. Профиль на сервере

В Godot (свой проект + аддон):

1. **Plugins** → Analytics Plugin → ON  
2. **Analytics** → «Настроить облачный режим» → URL: `http://localhost:8000/telemetry/ingest` → Сохранить  
3. Добавьте critical points: `time_sec`, `hints_used`, `deaths`, `score`  
4. Архетипы: `explorer`, `achiever`, `socializer`, `killer`  
5. **Сохранить ML профиль** → в Output: `✅ ML-профиль синхронизирован`

Проверка API:

```powershell
curl http://localhost:8000/game/profile
```

## 3. Тест из Godot

На Node в сцене повесьте `godot-plugin/examples/test_integration.gd` (F6).

Ожидаемо в Output:

- `📊 Серверная сессия: <UUID>`
- после ~10–12 событий: `✅ adaptation applied in game: { difficulty: ... }`
- `difficulty =` число от ML (не всегда 1.0)

## 4. Тест через curl (без Godot)

```powershell
# Старт сессии
$r = curl -s -X POST "http://localhost:8000/game/session/start?player_id=e2e_player"
# Извлеките session_id из JSON вручную или через jq

$body = @{
  events = @(
    @{
      session_id = "<SESSION_UUID>"
      player_id = "e2e_player"
      event_name = "puzzle_completed"
      timestamp = 1716812345.0
      game_time = 10.0
      parameters = @{ time_sec = 45.0; hints_used = 1; deaths = 0; score = 100.0 }
      state = @{}
    }
  ) * 12
  metadata = @{
    critical_points = @(
      @{ name = "time_sec"; weight = 1.0 }
      @{ name = "hints_used"; weight = 1.0 }
    )
    archetypes = @("explorer", "achiever", "socializer", "killer")
    bootstrap_actions = 10
  }
} | ConvertTo-Json -Depth 6

curl -X POST http://localhost:8000/telemetry/ingest -H "Content-Type: application/json" -d $body
```

В ответе: `prediction`, `adaptation.parameters` (difficulty, enemy_density, …).

## 5. Seed и обучение ML из Postgres

```powershell
.\scripts\seed.ps1 -Sessions 500 -EventsPerSession 12
.\scripts\train-from-db.ps1
docker compose restart ml
curl http://localhost:8001/health
# model_version: sklearn-rf-pg-1.0, model_loaded: true
```

## Устранение проблем

| Симптом | Решение |
|---------|---------|
| HTTP 31 / пустой URL | Сохраните cloud URL в настройках плагина |
| 422 session_id | Вызовите `start_new_game()` до `track()` |
| Нет adaptation | Нужно ≥ `bootstrap_actions` событий (по умолчанию 10) |
| `model_loaded: false` | `.\scripts\train-ml.ps1` или пересоберите образ `ml` |

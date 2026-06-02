# Интеграция Godot-плагина и JSON для API телеметрии

## Установка аддона (без project.godot в репозитории)

1. Скопируйте `godot-plugin/addons/analytics_plugin/` в `ваш_проект/addons/analytics_plugin/`.
2. **Project → Project Settings → Plugins** → включите **Analytics Plugin**.
3. Autoload `Analytics` создаётся плагином автоматически.
4. Панель **Analytics** → cloud URL: `http://localhost:8000/telemetry/ingest`.

Шаблон кода: `godot-plugin/examples/game_manager.gd`. Подробнее: [godot-plugin/README.md](../godot-plugin/README.md).

---

## Жизненный цикл в игре

| Шаг | Метод | Когда |
|-----|--------|--------|
| 1 | `Analytics.initialize()` | Один раз при старте приложения |
| 2 | `Analytics.start_new_game("1.0.0")` | Кнопка «Новая игра», начало run |
| 3 | `Analytics.track("event_name", {...})` | Во время геймплея |
| 4 | `Analytics.end_game()` | Выход в меню / game over |

Шаблон: `godot-plugin/examples/game_manager.gd`

Настройки URL: панель **Analytics → Настроить облачный режим** →  
`http://localhost:8000/telemetry/ingest`

Стек: из корня репозитория `docker compose up --build -d` (postgres + backend + ml).

---

## Порядок HTTP-запросов (cloud)

```text
1. POST /game/session/start?player_id=...&game_version=...
   → session_id (UUID)

2. POST /telemetry/ingest  (батчами)
   → events_received, prediction?, adaptation?

3. PATCH /game/session/{session_id}/end
   → сессия закрыта
```

---

## 1. Старт сессии

**POST** `/game/session/start?player_id=player_1&game_version=1.0.0`

Тело: пустое.

**Ответ:**

```json
{
  "session_id": "c2a7c5e1-1234-5678-9abc-def012345678",
  "player_id": "player_1",
  "game_version": "1.0.0",
  "started_at": "2026-05-27T12:00:00Z",
  "ended_at": null
}
```

Плагин сохраняет `session_id` и подставляет его во все события.

---

## 2. Ingest телеметрии (основной JSON)

**POST** `/telemetry/ingest`  
**Content-Type:** `application/json`

### Тело запроса

```json
{
  "events": [
    {
      "session_id": "c2a7c5e1-1234-5678-9abc-def012345678",
      "player_id": "player_1",
      "event_name": "puzzle_completed",
      "timestamp": 1716812345.12,
      "game_time": 42.5,
      "parameters": {
        "level": 3,
        "time_sec": 42.5,
        "hints_used": 1
      },
      "state": {
        "current_level": 3,
        "health": 80
      }
    }
  ],
  "metadata": {
    "critical_points": [
      { "name": "time_sec", "weight": 1.0 },
      { "name": "hints_used", "weight": 1.5 }
    ],
    "archetypes": ["explorer", "achiever", "socializer"],
    "model_mode": "cloud",
    "feature_schema_version": 1
  }
}
```

### Поля `events[]`

| Поле | Тип | Обязательно | Описание |
|------|-----|-------------|----------|
| `session_id` | UUID string | да | Из `/game/session/start` |
| `player_id` | string | да | Стабильный id игрока |
| `event_name` | string | да | Имя события (`puzzle_completed`, `enemy_killed`) |
| `timestamp` | number | да | Unix time (секунды) |
| `game_time` | number | нет | Секунды от начала текущей игры |
| `parameters` | object | нет | **Числовые/логические метрики** для ML (см. critical_points) |
| `state` | object | нет | Снимок состояния игры на момент события |

### Поля `metadata`

| Поле | Тип | Описание |
|------|-----|----------|
| `critical_points` | array | Что важно для ML: `{ "name": "...", "weight": 1.0 }` |
| `archetypes` | array | Список архетипов, заданных разработчиком |
| `model_mode` | string | `"cloud"` или `"local"` |
| `feature_schema_version` | int | Версия схемы признаков (по умолчанию `1`) |

`critical_points[].name` должны совпадать с ключами в `parameters` (или маппиться на них на сервере).

### Ответ

```json
{
  "events_received": 1,
  "prediction": {
    "predicted_archetype": "explorer",
    "confidence": 0.72,
    "model_id": 1
  },
  "adaptation": {
    "parameters": {
      "difficulty": 0.8,
      "enemy_density": 1.2
    },
    "predicted_archetype": "explorer",
    "confidence": 0.72,
    "model_id": 1,
    "source": "cloud"
  }
}
```

Плагин эмитит сигнал `adaptation_received` с объектом `adaptation`.

---

## 3. Завершение сессии

**PATCH** `/game/session/{session_id}/end`

Тело: пустое.

---

## Профиль игры (редактор плагина)

Кнопка **«Сохранить ML профиль»** в панели Analytics:

1. Локально: `user://ml_profile.json` + поля в `user://analytics_config.json`
2. Если задан `cloud_url` — **PUT** `/game/profile` на backend

**PUT** `/game/profile`

```json
{
  "model_version": "default",
  "feature_order": ["time_sec", "hints_used"],
  "critical_points": [
    { "name": "time_sec", "weight": 1.0 },
    { "name": "hints_used", "weight": 1.5 }
  ],
  "archetypes": ["explorer", "achiever", "socializer"],
  "feature_schema_version": 1,
  "bootstrap_actions": 10
}
```

`bootstrap_actions` — после скольких событий сервер делает первое предсказание.

---

## Пример в GDScript

```gdscript
Analytics.initialize()
Analytics.start_new_game("1.0.0")
Analytics.adaptation_received.connect(_on_adaptation)

Analytics.track("puzzle_completed", {
    "level": 2,
    "time_sec": 35.0,
    "hints_used": 0
})

func _on_adaptation(adaptation: Dictionary) -> void:
    var p = adaptation.get("parameters", {})
    # difficulty = p.get("difficulty", 1.0)
```

---

## Что формирует плагин автоматически

При `Analytics.track()` плагин собирает:

- `session_id`, `player_id` — из текущей сессии
- `event_name` — аргумент `track`
- `timestamp` — `Time.get_unix_time_from_system()`
- `game_time` — время с начала run
- `parameters` — ваш словарь
- `state` — всё, что вы задали через `Analytics.set_state(key, value)`

При `sync_now()` / автоотправке добавляется `metadata` из конфига (критические точки и архетипы из панели редактора).

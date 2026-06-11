# Руководство по демонстрации и скриншотам для диплома

---

## Часть 1. Как протестить демо (инструкция для Фёдора)

### Подготовка (один раз)

```powershell
# Убедиться что стек запущен
docker compose up -d

# Проверить что модель загружена
Invoke-WebRequest http://localhost:8001/health -UseBasicParsing
# Должно быть: "model_loaded": true
```

Проверить в браузере:
- `http://localhost:8000/docs` — Swagger UI backend
- `http://localhost:8001/health` — ML health

---

### Шаг 1. Установить плагин

- Скопировать `godot-plugin/addons/analytics_plugin/` в корень своего Godot-проекта
- **Project Settings → Plugins → Analytics Plugin → Enable**
- Autoload `Analytics` добавится автоматически

---

### Шаг 2. Настроить облако

- Вкладка **Analytics** внизу редактора → кнопка **«Настройки облака»**
- Поле **URL сервера**: `http://localhost:8000/telemetry/ingest`
- Нажать **Сохранить**

---

### Шаг 3. Добавить события (вкладка «Профиль»)

События — это имена действий, которые игра будет отслеживать через `Analytics.track()`.

Нажать **«+ Добавить событие»** и добавить три события по одному:

| Название события | Описание |
|-----------------|----------|
| `enemy_killed` | Убийство врага |
| `item_collected` | Подбор предмета |
| `level_complete` | Завершение уровня |

> Поле одно — просто вписать название и нажать **Сохранить**.

---

### Шаг 4. Добавить критические точки (вкладка «Профиль»)

Критические точки — это **числовые параметры** из `Analytics.track()`, которые ML использует как признаки.
**Название** должно точно совпадать с ключом в словаре `parameters` вызова `track()`.

Нажать **«+ Добавить критическую точку»** и добавить три точки:

#### Критическая точка 1 — `score`

| Поле | Значение |
|------|---------|
| **Название** | `score` |
| **Тип источника** | Функция |
| **Путь / имя** | `get_player_score` |
| **Что собирать** | ☑ Значение |
| **Вес** | `1.0` |

#### Критическая точка 2 — `deaths`

| Поле | Значение |
|------|---------|
| **Название** | `deaths` |
| **Тип источника** | Функция |
| **Путь / имя** | `get_death_count` |
| **Что собирать** | ☑ Значение |
| **Вес** | `2.0` |

> Вес 2.0 — смерти влияют на ML-вектор вдвое сильнее

#### Критическая точка 3 — `time_sec`

| Поле | Значение |
|------|---------|
| **Название** | `time_sec` |
| **Тип источника** | Функция |
| **Путь / имя** | `get_session_time` |
| **Что собирать** | ☑ Длительность |
| **Вес** | `1.0` |

> **Важно:** поле «Путь / имя» обязательно — но это просто метаданные для документации.
> Реальные данные берутся из параметров `Analytics.track()`, а не из этого поля.

---

### Шаг 5. Добавить архетипы

В блоке **Архетипы** ввести каждый и нажать **«+»**:

```
explorer
achiever
socializer
killer
```

---

### Шаг 6. Синхронизировать профиль

Нажать **«Сохранить ML профиль»** (или «Синхронизировать профиль») →
в статусе должно появиться **OK** или зелёная галочка.

Это отправляет `PUT /game/profile` на backend с вашими событиями, critical points и архетипами.

---

### Шаг 7. Написать тестовый скрипт

Создать новую сцену, прикрепить скрипт:

```gdscript
extends Node

func _ready():
    Analytics.initialize()
    Analytics.start_new_game("demo-1.0")
    Analytics.adaptation_received.connect(_on_adaptation)

    # 12 событий killer-паттерна: много убийств, высокий deaths
    for i in range(12):
        Analytics.track("enemy_killed", {
            "score":    25.0,
            "deaths":   3.0,
            "time_sec": 30.0
        })

func _on_adaptation(adaptation: Dictionary) -> void:
    var p = adaptation.get("parameters", {})
    print("=== АДАПТАЦИЯ ПОЛУЧЕНА ===")
    print("Архетип:       ", adaptation.get("predicted_archetype"))
    print("Уверенность:   ", adaptation.get("confidence"))
    print("difficulty:    ", p.get("difficulty"))
    print("enemy_density: ", p.get("enemy_density"))
    print("loot_mult:     ", p.get("loot_multiplier"))
```

---

### Шаг 8. Запустить (F5) и проверить Output

Через ~2 секунды в панели **Output** должно появиться:

```
=== АДАПТАЦИЯ ПОЛУЧЕНА ===
Архетип:       killer
Уверенность:   1.0
difficulty:    1.35
enemy_density: 1.4
loot_mult:     0.95
```

**Если адаптация не пришла** — проверить:
1. В Swagger `GET /health` → `"database": "ok"`
2. `GET /game/profile` → в ответе `bootstrap_actions` = 10, archetypes заполнены
3. В Output Godot нет ошибок сети (красных строк)

---

### Шаг 9. Проверить другие архетипы

**Explorer** (исследователь — много предметов, мало смертей):
```gdscript
for i in range(12):
    Analytics.track("item_collected", {
        "score": 40.0, "deaths": 0.0, "time_sec": 90.0
    })
# Ожидается: archetype=explorer, difficulty=0.85
```

**Achiever** (достигатель — высокий счёт, быстрое прохождение):
```gdscript
for i in range(12):
    Analytics.track("level_complete", {
        "score": 95.0, "deaths": 1.0, "time_sec": 45.0
    })
# Ожидается: archetype=achiever, difficulty=1.2
```

---

## Часть 2. Какие скриншоты прикрепить в диплом

### Обязательные (без них диплом неполный)

| № | Что снимать | Где |
|---|-------------|-----|
| 1 | **Swagger UI** — список всех endpoint'ов | `http://localhost:8000/docs` |
| 2 | **POST /telemetry/ingest** — тело запроса + ответ с `adaptation` | Swagger → Try it out |
| 3 | **Панель редактора Godot** — вкладка «Профиль» с событиями и critical points заполнены | Godot editor |
| 4 | **Output в Godot** — вывод `=== АДАПТАЦИЯ ПОЛУЧЕНА ===` с архетипом и параметрами | Godot → Output |
| 5 | **ML health** — `"model_loaded": true, "model_version": "sklearn-rf-db-1061s"` | `http://localhost:8001/health` |

### Важные (усиливают работу)

| № | Что снимать | Где |
|---|-------------|-----|
| 6 | **Настройки облака в Godot** — диалог с URL `http://localhost:8000/telemetry/ingest` | Godot editor |
| 7 | **POST /game/train** — ответ с `samples: 1061`, `train_accuracy: 1.0` | Swagger |
| 8 | **Диаграмма архитектуры** — схема потока данных (нарисовать в draw.io по схеме из README) | — |
| 9 | **Вывод pytest** — `13 passed in 1.08s` | Терминал |
| 10 | **docker compose ps** — три контейнера Up | Терминал |

---

### Порядок скриншотов в тексте диплома

```
Глава 3 (Архитектура)    → скрин 8  (диаграмма системы)
Глава 4 (Реализация)     → скрины 3, 6 (панель редактора Godot)
Глава 4 (API)            → скрины 1, 2, 7 (Swagger)
Глава 5 (Тестирование)   → скрины 9, 10 (pytest + docker)
Глава 6 (Демо)           → скрин 4 (Output с адаптацией), скрин 5 (health)
```

---

### Совет по скрину №2 (самый важный для комиссии)

Использовать **Try it out** в Swagger. Сначала создать сессию:

```
POST /game/session/start?player_id=demo_player
```

Скопировать `session_id` из ответа. Затем выполнить `POST /telemetry/ingest` с этим JSON
(подставить свой `session_id` вместо UUID-заглушки):

```json
{
  "events": [
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 1.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 2.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 3.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 4.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 5.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 6.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 7.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 8.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 9.0,  "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 10.0, "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 11.0, "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}},
    {"session_id": "ВСТАВИТЬ_SESSION_ID", "player_id": "demo_player", "event_name": "enemy_killed", "timestamp": 12.0, "parameters": {"score": 25.0, "deaths": 3.0, "time_sec": 30.0}}
  ],
  "metadata": {
    "critical_points": [
      {"name": "score",    "weight": 1.0},
      {"name": "deaths",   "weight": 2.0},
      {"name": "time_sec", "weight": 1.0}
    ],
    "archetypes": ["explorer", "achiever", "socializer", "killer"]
  }
}
```

Ожидаемый ответ для скриншота:
```json
{
  "events_received": 12,
  "prediction": {
    "predicted_archetype": "killer",
    "confidence": 1.0
  },
  "adaptation": {
    "parameters": {
      "difficulty": 1.35,
      "enemy_density": 1.4,
      "loot_multiplier": 0.95
    }
  }
}
```

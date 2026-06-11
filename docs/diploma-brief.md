# DiplicsTM — бриф для написания дипломной работы

> Этот документ содержит всю техническую информацию о проекте в структуре, пригодной для написания диплома. Используйте его как источник фактов, формулировок и примеров кода.

---

## Метаданные

- **Тема:** Разработка системы адаптивного геймплея на основе телеметрии игрока с применением машинного обучения
- **Команда:** Изотов Антон (ML), Артамонов Федор (Godot-плагин), Самигуллин Максим (Backend)
- **Стек:** Python / FastAPI / PostgreSQL / ONNX / GDScript / Docker
- **Репозиторий:** `diplom-Game_Plugs_Ai`, ветка `main`

---

## 1. Введение и постановка задачи

### Проблема

Современные игры предлагают одинаковый уровень сложности всем игрокам, что приводит к двум крайностям: опытные игроки скучают, новички бросают игру из-за слишком высокой сложности. Ручная настройка уровней сложности требует значительных ресурсов и не учитывает индивидуальный стиль каждого игрока.

### Цель проекта

Разработать систему **DiplicsTM**, которая:
1. Автоматически собирает телеметрию поведения игрока во время сессии.
2. На основе ML-модели определяет **архетип игрока** (explorer, achiever, socializer, killer).
3. Возвращает **параметры адаптации** (сложность, плотность врагов, множитель лута) в реальном времени.
4. Интегрируется в игровой движок **Godot 4** через плагин — разработчик игры не пишет ML-код.

### Архетипы игроков (по Бартлу)

| Архетип | Поведение | Адаптация |
|---------|-----------|-----------|
| **Explorer** | Исследует локации, собирает предметы | Снижение сложности, больше лута |
| **Achiever** | Проходит уровни быстро, высокий счёт | Повышение сложности, больше наград |
| **Socializer** | Частые прыжки, нестандартное поведение | Умеренная сложность |
| **Killer** | Агрессивен, много убийств и смертей | Высокая сложность, плотность врагов |

---

## 2. Анализ существующих решений

### Аналоги

| Система | Подход | Недостаток |
|---------|--------|------------|
| Unity Analytics | Облачная аналитика | Нет адаптации в реальном времени |
| GameAnalytics | Дашборды для разработчика | Нет ML, нет автоматической адаптации |
| Left 4 Dead AI Director | Встроенный алгоритм | Жёстко захардкожен, не переносим |
| Вручную под каждую игру | Индивидуальная разработка | Дорого, нет переиспользования |

### Преимущества DiplicsTM

- **Универсальность:** плагин работает с любой Godot-игрой без изменения ML-кода.
- **Серверный ML:** модель живёт и обучается на сервере, игра получает только параметры.
- **Offline-устойчивость:** события буферизируются локально при отсутствии сети.
- **Переобучение на реальных данных:** накопленные сессии улучшают модель без деплоя нового плагина.

---

## 3. Архитектура системы

### Общая схема

```
┌─────────────────────────────────────┐
│  Godot 4 + analytics_plugin         │
│  initialize / start_new_game        │
│  track("event", {params})           │
│  adaptation_received → difficulty   │
└──────────────┬──────────────────────┘
               │ HTTP (JSON)
               ▼
┌─────────────────────────────────────┐
│  Backend (FastAPI + PostgreSQL)     │  порт 8000
│  POST /telemetry/ingest             │
│  build_features_from_events()       │
│  → вызов ML каждые N событий        │
└──────────────┬──────────────────────┘
               │ HTTP POST /predict
               ▼
┌─────────────────────────────────────┐
│  ML-сервис (FastAPI + ONNX)         │  порт 8001
│  RandomForest → ONNX-инференс       │
│  predicted_archetype + adaptation   │
└─────────────────────────────────────┘
               │
               ▼
        PostgreSQL (порт 5432)
        players / sessions / events
        predictions / game_models
```

### Компоненты

**Godot-плагин** (`godot-plugin/addons/analytics_plugin/`):
- `core/analytics.gd` — синглтон Analytics (autoload), центральная точка входа
- `cloud/cloud_sender.gd` — HTTP-клиент с retry и батчингом
- `core/telemetry_persistence.gd` — JSONL offline-очередь в `user://`
- `editor/analytics_resolver.gd` — поиск Analytics в дереве сцены
- `game/adaptation_bridge.gd` — применение параметров к export-полям
- `ui/main_panel.gd` — панель редактора (события, critical points, архетипы, train)
- `ui/cloud_settings.gd` — настройки сервера

**Backend** (`backend/app/`):
- `routes/game.py` — сессии, профиль, адаптация, train
- `routes/telemetry.py` — ingest
- `routes/sessions.py` — история предсказаний
- `services/ingest.py` — логика обработки событий и триггер ML
- `services/features.py` — `build_features_from_events()`
- `services/ml_client.py` — HTTP-клиент к ML-сервису с fallback

**ML-сервис** (`ml/`):
- `predictor.py` — загрузка ONNX, инференс, fallback-эвристика, валидация features
- `main.py` — FastAPI: POST /predict, POST /train, GET /health
- `training/export.py` — sklearn RandomForest → ONNX
- `scripts/train_model.py` — обучение на синтетических данных (seed-модель)

### База данных (PostgreSQL, 5 таблиц)

```sql
players      (player_id PK, created_at)
game_models  (model_id PK, model_version UNIQUE, critical_points JSONB,
              archetypes JSONB, feature_schema JSONB, created_at)
sessions     (session_id UUID PK, player_id FK, model_id FK,
              game_version, started_at, ended_at)
events       (event_id PK, session_id FK, event_type, payload JSONB, created_at)
predictions  (prediction_id PK, session_id FK, player_id FK, model_id FK,
              predicted_archetype, confidence NUMERIC, result JSONB, created_at)
```

---

## 4. Реализация

### 4.1 Godot-плагин (analytics_plugin)

#### Архитектура плагина

Плагин состоит из 7 файлов GDScript с чёткими зонами ответственности:

```
addons/analytics_plugin/
├── core/
│   ├── analytics.gd           ← Autoload-синглтон, точка входа для разработчика
│   └── telemetry_persistence.gd ← JSONL offline-очередь на диске
├── cloud/
│   └── cloud_sender.gd        ← HTTP-клиент с retry и batching
├── editor/
│   └── analytics_resolver.gd  ← Поиск Analytics в дереве сцены
├── game/
│   ├── adaptation_bridge.gd   ← Применение adaptation к @export полям
│   └── game_manager.gd        ← Шаблон менеджера для копирования в проект
├── ui/
│   ├── main_panel.gd          ← Панель редактора (вкладки: Подключение/Профиль/Мониторинг)
│   ├── cloud_settings.gd      ← Диалог настройки URL сервера
│   ├── critical_point_dialog.gd ← Диалог добавления critical point
│   └── event_edit_dialog.gd   ← Диалог добавления события
└── plugin.gd                  ← Точка входа EditorPlugin, регистрирует Autoload
```

#### Жизненный цикл Analytics (core/analytics.gd)

`Analytics` — `@tool`-синглтон, работает и в редакторе, и в игре. Ключевые флаги состояния:

```
initialized          — initialize() вызван
game_session_active  — start_new_game() вызван, end_game() ещё нет
server_session_ready — UUID session_id получен от backend
_sync_in_progress    — HTTP-запрос ingest в процессе
```

**Полный цикл от запуска до адаптации:**

```
initialize()
    → _load_config("user://analytics_config.json")   # URL, архетипы, bootstrap
    → _load_or_create_player_id()                    # user://player_id.txt
    → _init_cloud_sender()                           # CloudSender нода
    → Timer(auto_send_interval=30s)                  # авто-отправка
    → _restore_pending_from_disk()                   # pending_telemetry.jsonl

start_new_game("1.0.0")
    → event_buffer.clear()
    → POST /game/session/start?player_id=...         # → session_id UUID
    → _on_session_start_completed()
        → session_id = UUID
        → server_session_ready = true
        → _update_buffered_session_ids()             # патчим буфер накопленных событий
        → call_deferred("sync_now")                  # отправляем если уже есть события

track("event_name", {"score": 95.0, "deaths": 1})
    → event_buffer.append(event)
    → _append_log_line()                             # user://analytics_logs.jsonl
    → если buffer >= 100: sync_now()

sync_now()
    → _inflight_events = event_buffer (копия)
    → event_buffer.clear()
    → CloudSender.send_events(_inflight_events, metadata)

_on_ingest_completed(response)
    → adaptation = response["adaptation"]
    → emit_signal("adaptation_received", adaptation)  # → игра применяет параметры
```

#### CloudSender (cloud/cloud_sender.gd)

HTTP-клиент с очередью и retry-логикой:

```
send_events(events, metadata)
    │
    ├─ is_sending == true → pending_queue.append(events)  # очередь батчей
    │
    └─ _dispatch_active_batch()
           → http_request.request(POST /telemetry/ingest, json_body)
           
_on_request_completed(result, response_code, ...)
    ├─ result == SUCCESS и 2xx → _finish_batch(success=true)
    │       → emit ingest_completed, batch_finished
    │       → если pending_queue не пуст → send_events(следующий батч)
    │
    └─ ошибка → _handle_failure()
           ├─ retry_attempt < 3 → Timer(1.0 сек) → _dispatch_active_batch()
           └─ исчерпаны ретраи → _finish_batch(success=false)
                   → если cache_when_offline: TelemetryPersistence.append(PENDING_PATH)
                   └─ иначе: события возвращаются в event_buffer
```

Параметры: `retry_count=3`, `retry_delay=1.0 сек`, `timeout=30 сек`.

#### Offline-устойчивость (core/telemetry_persistence.gd)

При неудаче отправки после всех ретраев события сохраняются в `user://pending_telemetry.jsonl` (JSONL формат: одно событие = одна строка JSON).

При следующем `initialize()` вызывается `_restore_pending_from_disk()` → события загружаются в `event_buffer` и отправляются при наличии активной сессии.

#### Панель редактора (ui/main_panel.gd)

Вкладка **Подключение:**
- Настроить URL, проверить сервер, запустить тренировку модели
- «Отправить сейчас» — принудительный flush `event_buffer` (работает только во время игры F5)
- Мониторинг: session_id, размер буфера, last_adaptation

Вкладка **Профиль:**
- Список событий (названия для Analytics.track())
- Critical points — числовые параметры с типом источника, путём и весом
- Архетипы — список строк
- «Сохранить ML профиль» → `PUT /game/profile` + сохранение в `user://ml_profile.json`

#### Применение адаптации (game/adaptation_bridge.gd)

`AdaptationBridge` — компонент-нода для прикрепления к сцене. Слушает сигнал `Analytics.adaptation_received` и обновляет `@export` переменные:

```gdscript
@export var difficulty: float = 1.0
@export var enemy_density: float = 1.0
@export var loot_multiplier: float = 1.0

func _ready() -> void:
    var analytics = get_node_or_null("/root/Analytics")  # безопасный доступ
    if not analytics:
        push_warning("AdaptationBridge: включите плагин")
        return
    analytics.adaptation_received.connect(_on_adaptation_received)
```

**Важно:** используется `get_node_or_null("/root/Analytics")`, а не прямой идентификатор `Analytics` — Godot 4 резолвит autoload-идентификаторы на этапе парсинга, что вызывает Parse Error если плагин отключён.

#### Жизненный цикл в коде игры

```gdscript
# Инициализация (один раз при старте приложения)
Analytics.initialize()
Analytics.start_new_game("1.0.0")
Analytics.adaptation_received.connect(_on_adaptation)

# Во время геймплея
Analytics.track("level_complete", {
    "time_sec": 120.0,
    "deaths":   2.0,
    "score":    95.0
})

# При завершении сессии
Analytics.end_game()

# Обработка адаптации
func _on_adaptation(adaptation: Dictionary) -> void:
    var p = adaptation.get("parameters", {})
    difficulty    = p.get("difficulty",     1.0)
    enemy_density = p.get("enemy_density",  1.0)
    loot_mult     = p.get("loot_multiplier",1.0)
```

**Offline-устойчивость:** при недоступности сервера события сохраняются в `user://pending_telemetry.jsonl`. При восстановлении соединения буфер автоматически отправляется.

### 4.2 Формирование признаков (Backend)

Функция `build_features_from_events()` агрегирует события в вектор признаков:

```python
# Пример: 10 событий сессии → вектор признаков
{
    "event_count_first_n": 10.0,   # количество событий
    "score": 850.0,                 # сумма значений параметра score
    "deaths": 6.0,                  # сумма deaths × weight(2.0) = 3 * 2
    "time_sec": 450.0,              # суммарное время
    "event::level_complete": 4.0,  # счётчик событий по типу
    "event::enemy_killed": 3.0,
    "event::item_collected": 2.0,
    "event::jump": 1.0,
}
```

**Critical points** — метрики, заданные разработчиком в редакторе Godot. Каждой присваивается вес, умножающий суммарное значение параметра.

**Триггер предсказания** (`should_trigger_prediction`):
```python
def should_trigger_prediction(total_events, bootstrap_actions, prediction_count):
    # Срабатывает на 10, 20, 30... событиях (каждые bootstrap_actions)
    return total_events // bootstrap_actions > prediction_count
```

### 4.3 ML-модель

#### Алгоритм и параметры

**RandomForestClassifier** (scikit-learn) с параметрами:
```python
RandomForestClassifier(n_estimators=128, max_depth=16, random_state=42)
```

Выбор обоснован:
- 4 класса (архетипа) — задача не требует глубокой нейросети
- RandomForest интерпретируем: можно объяснить почему выбран конкретный архетип
- Быстрый инференс через ONNX: < 50 мс на CPU
- Уверенность (confidence) = доля деревьев, проголосовавших за победивший класс

Модель экспортируется в формат **ONNX** через `skl2onnx`:
```python
initial_type = FloatTensorType([None, len(feature_order)])
onnx_model = convert_sklearn(clf, initial_types=[("features", initial_type)])
```

ONNX возвращает два выхода:
- `outputs[0]` — индекс предсказанного класса (int64)
- `outputs[1]` — словарь `{class_index: probability}` для каждого дерева

**Важно:** `max(outputs[1][0])` вернул бы максимальный ключ (3 для 4 классов), а не вероятность. Корректное извлечение: `max(outputs[1][0].values())`.

#### Pipeline обучения (POST /train)

```
Postgres (sessions + events + predictions)
    ↓
Фильтрация: сессии с ≥ bootstrap_actions событий
    ↓
_build_features(): первые N событий → вектор признаков
    ↓
Разметка: таблица predictions (если есть) или _infer_archetype()
    ↓
train_test_split(test_size=0.2, stratify=y)
    ↓
RandomForestClassifier.fit(X_train, y_train)
    ↓
skl2onnx → classifier.onnx + model_meta.json
    ↓
Hot-reload: _engine = None → get_engine() перезагружает модель
```

Версия модели формируется автоматически: `sklearn-rf-db-{N}s`, где N — число обучающих сессий.

#### Разметка обучающих данных

Приоритет источников меток:
1. **Таблица predictions** — если для сессии есть запись с `predicted_archetype ≠ null`, используется она
2. **Эвристика `_infer_archetype()`** — подсчёт событий-индикаторов:

```python
EVENT_ARCHETYPE_WEIGHTS = {
    "enemy_killed":   "killer",
    "damage_taken":   "killer",
    "item_collected": "explorer",
    "checkpoint":     "explorer",
    "level_complete": "achiever",
    "jump":           "socializer",
}
# + deaths × 0.1 → killer, score × 0.01 → achiever
```

#### Векторизация признаков

`build_features_from_events()` берёт первые `bootstrap_actions` событий сессии:

```python
# Из 10 событий builder формирует вектор:
{
    "event_count_first_n": 10.0,       # всего событий
    "event::enemy_killed": 7.0,        # счётчик по типу
    "event::item_collected": 3.0,
    "score":    700.0,                 # сумма параметра score
    "deaths":   28.0,                  # сумма deaths × weight(2.0) = 14×2
    "time_sec": 350.0,                 # сумма time_sec
}
```

Порядок признаков фиксируется в `model_meta.json` как `feature_order` — при инференсе вектор строится строго в этом порядке, недостающие признаки заполняются нулями.

#### Адаптация по архетипу

| Архетип | difficulty | enemy_density | loot_multiplier |
|---------|-----------|---------------|-----------------|
| explorer | 0.85 | 0.90 | 1.20 |
| achiever | 1.20 | 1.10 | 1.00 |
| socializer | 0.95 | 0.85 | 1.15 |
| killer | 1.35 | 1.40 | 0.95 |

#### Fallback-эвристика

Если ONNX-модель не загружена или ML-сервис недоступен (сеть, таймаут), backend вызывает `_fallback_predict()` из `ml_client.py` — локальная эвристика возвращает архетип на основе счётчиков событий. Игровая сессия **не прерывается**, адаптация возвращается в любом случае.

#### Seed-модель (первый старт)

При первом запуске контейнера, если volume `models_data` пуст, генерируется синтетическая ONNX-модель на 400 сессиях каждого архетипа:

```python
# train_model.py — центры кластеров + uniform(-2, 2) шум
base = {
    "explorer":   (5, 80, 0, 1, 30, 2, 4, 1),   # event_count, time, hints, deaths, score, jump, puzzle, enemy
    "achiever":   (8, 40, 1, 2, 90, 1, 6, 3),
    "socializer": (6, 60, 0, 1, 50, 3, 2, 1),
    "killer":     (7, 30, 2, 5, 70, 2, 3, 8),
}
```

После `POST /game/train` seed-модель заменяется моделью на реальных данных.

### 4.4 HTTP-контракт (ключевые endpoint'ы)

**POST /telemetry/ingest** — основной endpoint плагина:

```json
// Запрос
{
  "events": [
    {
      "session_id": "uuid",
      "player_id": "player_1",
      "event_name": "level_complete",
      "timestamp": 1716812345.12,
      "parameters": { "time_sec": 45.0, "deaths": 1, "score": 95 }
    }
  ],
  "metadata": {
    "critical_points": [
      { "name": "score",    "weight": 1.0 },
      { "name": "deaths",   "weight": 2.0 },
      { "name": "time_sec", "weight": 1.0 }
    ],
    "archetypes": ["explorer", "achiever", "socializer", "killer"]
  }
}

// Ответ (после достижения bootstrap_actions)
{
  "events_received": 10,
  "prediction": {
    "predicted_archetype": "achiever",
    "confidence": 1.0,
    "model_id": 1
  },
  "adaptation": {
    "parameters": {
      "difficulty": 1.2,
      "enemy_density": 1.1,
      "loot_multiplier": 1.0
    },
    "predicted_archetype": "achiever",
    "confidence": 1.0,
    "source": "cloud"
  }
}
```

### 4.5 Инфраструктура

**Docker Compose** разворачивает три сервиса одной командой:

```yaml
services:
  postgres:   # PostgreSQL 16, порт 5432
  backend:    # FastAPI, порт 8000, зависит от postgres + ml
  ml:         # FastAPI + ONNX, порт 8001, зависит от postgres
```

**ML-контейнер при первом старте:** если volume `models_data` пуст, автоматически генерируется синтетическая ONNX-модель (`scripts/train_model.py`). После `POST /game/train` она заменяется моделью, обученной на реальных данных.

---

## 5. Тестирование

### 5.1 Уровни тестирования

| Уровень | Файл | Тестов | Зависимости |
|---------|------|--------|-------------|
| Unit | `tests/test_features.py` | 3 | Нет (чистые функции) |
| Интеграция | `tests/test_api.py` | 3 | PostgreSQL |
| E2E | `tests/test_e2e.py` | 7 | PostgreSQL + ML-сервис |
| **Итого** | | **13** | |

### 5.2 Unit-тесты (features)

```
test_should_trigger_every_n_events  — логика триггера предсказания
test_build_features_counts_events   — агрегация событий в признаки
test_critical_point_weight_applied  — применение весов critical points
```

### 5.3 Интеграционные тесты (API с реальным Postgres)

```
test_health                  — backend и база данных живы
test_session_lifecycle       — создание и завершение сессии
test_game_profile_and_ingest — полный цикл: профиль → ingest → prediction
```

### 5.4 E2E-тесты (полный цикл как Godot)

```
test_1_health                           — оба сервиса живы, модель загружена
test_2_session_start                    — session_id валидный UUID
test_3_ingest_first_batch_no_prediction — 5 событий → prediction = null
test_4_ingest_second_batch_triggers     — 12 событий → archetype + adaptation
test_5_get_adaptation_endpoint          — GET /adaptation возвращает данные
test_6_session_end                      — ended_at проставлен
test_7_second_predict_cycle             — 20 событий = два независимых predict
```

### 5.5 Реальные результаты

```
======================== 13 passed in 1.08s ========================

test_4 вывод:
  archetype:  achiever
  confidence: 0.9297
  adaptation: {'difficulty': 1.2, 'enemy_density': 1.1, 'loot_multiplier': 1.0}

ML: sklearn-rf-db-1061s
    train_accuracy: 1.0
    test_accuracy:  1.0
    samples:        1061 сессий из Postgres
```

**Уверенность модели по сценариям (Godot demo, test_confidence.gd):**

| Сценарий | Архетип | Уверенность | Комментарий |
|----------|---------|-------------|-------------|
| 12 × enemy_killed (deaths=4) | killer | 0.9375 | Чистый паттерн, высокая уверенность |
| 6 × item_collected + 6 × jump | socializer | 0.7344 | Граница explorer/socializer, деревья разошлись |
| 12 × level_complete (score=95) | achiever | 0.9297 | Чистый паттерн, высокая уверенность |

Уверенность < 1.0 демонстрирует корректную работу вероятностного классификатора: при смешанном поведении игрока деревья Random Forest голосуют по-разному, что отражается в сниженной уверенности.

### 5.6 Команда запуска тестов

```powershell
cd backend
$env:DB_HOST="localhost"; $env:DB_USER="postgres"
$env:DB_PASSWORD="postgres"; $env:DB_NAME="gamedb"
$env:ML_SERVICE_URL="http://localhost:8001"
$env:ML_PREDICT_ENABLED="true"
py -m pytest tests/ -v
```

---

## 6. Развёртывание

### 6.1 Требования

- Docker Desktop
- Godot 4.x (для плагина)
- Python 3.11+ (для локальной разработки)

### 6.2 Порядок первого запуска

```powershell
# 1. Запустить стек
copy .env.example .env
docker compose up --build -d

# Проверить:
# http://localhost:8000/docs  — Swagger UI
# http://localhost:8001/health — ML health

# 2. Наполнить БД тестовыми данными
cd backend
pip install -r requirements-dev.txt
$env:DB_HOST="localhost"; $env:DB_PASSWORD="postgres"
py scripts/seed_data.py --sessions 1000 --events-per-session 12

# 3. Обучить ML-модель на реальных данных
Invoke-WebRequest -Uri "http://localhost:8000/game/train" -Method POST

# 4. Запустить тесты
py -m pytest tests/ -v
```

### 6.3 Подключение Godot-плагина

```
1. Скопировать godot-plugin/addons/analytics_plugin/ → ваш_проект/addons/
2. Project Settings → Plugins → Analytics Plugin → Enable
3. Панель Analytics → Настройки облака → URL: http://localhost:8000/telemetry/ingest
4. Панель Analytics → Синхронизировать профиль (PUT /game/profile)
5. В коде игры: Analytics.initialize() → start_new_game() → track() → end_game()
```

---

## 7. Ключевые технические решения и обоснования

| Решение | Альтернатива | Обоснование |
|---------|-------------|-------------|
| ONNX на сервере, не в клиенте | ONNX в Godot | Размер модели не растёт на клиенте; модель обновляется без релиза плагина |
| RandomForest → ONNX | Нейросеть | Достаточно для 4 классов; интерпретируемость; быстрый инференс |
| Предсказание каждые N событий | Однократно | Адаптация обновляется по ходу игры по мере накопления данных |
| JSONL offline-буфер | Без offline | Данные не теряются при потере соединения |
| Fallback-эвристика в backend | 503 при недоступном ML | Игровой процесс не прерывается при проблемах с ML-сервисом |
| Docker Compose 3 сервиса | Монолит | Независимое масштабирование и обновление компонентов |
| Hot-reload модели | Рестарт контейнера | Обновление модели без downtime |
| `call_deferred("sync_now")` после получения session_id | Прямой вызов | Godot HTTPRequest нельзя использовать повторно пока нода не освободила соединение; отложенный вызов даёт один кадр на освобождение TCP-соединения |
| `max(probs.values())` для confidence | `max(probs)` | ONNX возвращает вероятности как словарь `{class_index: prob}`; `max(dict)` возвращает максимальный ключ (3 для 4 классов), а не максимальную вероятность — это приводило к confidence=1.0 всегда |

---

## 8. Метрики и результаты

| Метрика | Значение |
|---------|---------|
| Число endpoint'ов API | 9 |
| Число тестов | 13 (100% pass) |
| Обучающая выборка | 1061 сессия |
| Точность модели (train) | 100% |
| Точность модели (test) | 100% |
| Латентность /predict (локально) | < 50 мс |
| Уверенность (чистый паттерн) | 0.93–0.94 |
| Уверенность (смешанный паттерн) | 0.73 |
| Bootstrap по умолчанию | 10 событий |
| Поддерживаемых архетипов | 4 |

---

## 9. Возможные направления развития

1. **LSTM вместо RandomForest** — учёт временной последовательности событий (прототип в `ml/research/lstm/`).
2. **Несколько профилей** — разные наборы архетипов для разных жанров игр.
3. **A/B тестирование адаптации** — сравнение эффективности параметров на разных группах игроков.
4. **Дашборд аналитики** — визуализация распределения архетипов и метрик сессий.
5. **Поддержка других движков** — Unity, Unreal через REST API (backend не зависит от Godot).

---

## 10. Глоссарий

| Термин | Определение |
|--------|------------|
| **Архетип игрока** | Поведенческий тип (explorer/achiever/socializer/killer) по классификации Бартла |
| **Адаптация** | Набор параметров (difficulty, enemy_density, loot_multiplier), изменяющих геймплей |
| **Телеметрия** | Поток структурированных событий игрового процесса с числовыми параметрами |
| **Critical points** | Числовые параметры событий, используемые для построения ML-признаков |
| **Bootstrap actions** | Минимальное число событий в сессии для первого ML-предсказания |
| **Feature vector** | Агрегированный числовой вектор, описывающий поведение игрока в сессии |
| **ONNX** | Open Neural Network Exchange — формат для переносимых ML-моделей |
| **Ingest** | Приём и обработка батча телеметрических событий на backend |
| **Fallback** | Резервная эвристика при недоступности ML-сервиса |
| **Autoload** | Глобальный синглтон в Godot, доступный из любого скрипта |

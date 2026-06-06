# DiplicsTM — адаптивный геймплей на телеметрии

Дипломный проект: Godot-плагин собирает игровые события, backend строит ML-признаки, ML-сервис определяет архетип игрока и возвращает параметры адаптации (сложность, плотность врагов, лут). Игра применяет их в реальном времени — геймплей подстраивается под стиль каждого игрока.

```
Godot (analytics_plugin)
    │  HTTP POST /telemetry/ingest
    ▼
Backend (FastAPI + PostgreSQL)         порт 8000
    │  build_features → POST /predict
    ▼
ML-service (FastAPI + ONNX)            порт 8001
    │  predicted_archetype + adaptation
    ▼
Godot → сигнал adaptation_received → difficulty / enemy_density / loot_multiplier
```

## Команда

| Участник | Роль |
|----------|------|
| Изотов Антон | ML / Data Science — `ml/` |
| Артамонов Федор | Godot / плагин — `godot-plugin/` |
| Самигуллин Максим | Backend / БД — `backend/` |

## Структура репозитория

```
diplom-Game_Plugs_Ai/
├── docker-compose.yml
├── .env.example
├── backend/                      # FastAPI (пакет app/)
│   ├── app/
│   │   ├── routes/               # game, telemetry, sessions
│   │   └── services/             # ingest, features, ml_client
│   ├── migrations/               # SQL-миграции (идемпотентные)
│   ├── scripts/seed_data.py      # генерация тестовых данных
│   └── tests/                    # unit + интеграция + E2E
├── ml/                           # ML-сервис (ONNX + обучение)
│   ├── predictor.py              # инференс
│   ├── training/export.py        # sklearn → ONNX
│   └── scripts/train_model.py    # синтетическая модель (seed)
├── godot-plugin/
│   ├── addons/analytics_plugin/  # ← устанавливать в игровой проект
│   └── examples/                 # шаблоны GDScript
└── docs/
    ├── vision.md                 # архитектура и решения
    ├── integration.md            # HTTP-контракт для плагина
    └── ml-roadmap.md             # план ML
```

## Быстрый старт

### 1. Запуск стека

```powershell
copy .env.example .env        # при необходимости поправить пароли
docker compose up --build -d
```

| Сервис | URL |
|--------|-----|
| API + Swagger | http://localhost:8000/docs |
| ML health | http://localhost:8001/health |
| Postgres | localhost:5432 / gamedb |

### 2. Первый запуск — наполнить БД и обучить модель

На чистой БД ML работает в режиме эвристики. Для полноценного обучения:

```powershell
# Сгенерировать 1000 размеченных сессий (50 игроков, 4 архетипа)
cd backend
pip install -r requirements-dev.txt
$env:DB_HOST="localhost"; $env:DB_PASSWORD="postgres"
py scripts/seed_data.py --sessions 1000 --events-per-session 12

# Обучить ONNX-модель на данных из Postgres
Invoke-WebRequest -Uri "http://localhost:8000/game/train" -Method POST
```

После обучения `/health` ML-сервиса покажет `"model_loaded": true` и версию модели.

### 3. Проверить что всё работает

```powershell
# Health
Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing
Invoke-WebRequest -Uri "http://localhost:8001/health" -UseBasicParsing

# Полный E2E-тест через API (без Godot)
cd backend
$env:DB_HOST="localhost"; $env:DB_USER="postgres"
$env:DB_PASSWORD="postgres"; $env:DB_NAME="gamedb"
$env:ML_SERVICE_URL="http://localhost:8001"; $env:ML_PREDICT_ENABLED="true"
py -m pytest tests/ -v
```

Ожидаемый результат: **13 passed** (3 unit + 3 integration + 7 E2E).

## Godot — подключение плагина к проекту

1. Скопируйте папку `godot-plugin/addons/analytics_plugin/` в корень вашего Godot-проекта.
2. Откройте **Project → Project Settings → Plugins** → включите **Analytics Plugin** (autoload `Analytics` добавится автоматически).
3. Вкладка **Analytics** в редакторе → **Настройки облака** → URL: `http://localhost:8000/telemetry/ingest` → Сохранить.
4. В коде игры:

```gdscript
# _ready() главного узла
Analytics.initialize()
Analytics.start_new_game("1.0.0")
Analytics.adaptation_received.connect(_on_adaptation)

func _on_adaptation(params: Dictionary) -> void:
    difficulty    = params.get("difficulty",    1.0)
    enemy_density = params.get("enemy_density", 1.0)

# В игровых событиях
Analytics.track("level_complete", {"time_sec": 120.0, "deaths": 2, "score": 95})

# При выходе
Analytics.end_game()
```

Шаблоны: `godot-plugin/examples/` · Детали: [godot-plugin/README.md](godot-plugin/README.md) · Контракт: [docs/integration.md](docs/integration.md)

## Переменные окружения

Файл `.env` (пример — `.env.example`):

| Переменная | По умолчанию | Описание |
|-----------|-------------|----------|
| `POSTGRES_PASSWORD` | `postgres` | Пароль Postgres |
| `ML_PREDICT_ENABLED` | `true` | Включить ML-предсказания |
| `BOOTSTRAP_ACTIONS` | `10` | Событий до первого predict |

## Локальная разработка без Docker

```powershell
# Backend
cd backend
pip install -r requirements-dev.txt
$env:DB_HOST="localhost"; $env:DB_PASSWORD="postgres"
py -m uvicorn app.main:app --reload --port 8000

# ML-сервис (другой терминал)
cd ml
pip install -r requirements.txt
py -m uvicorn main:app --port 8001
```

## Тесты

```powershell
cd backend
$env:DB_HOST="localhost"; $env:DB_USER="postgres"
$env:DB_PASSWORD="postgres"; $env:DB_NAME="gamedb"
$env:ML_SERVICE_URL="http://localhost:8001"; $env:ML_PREDICT_ENABLED="true"

py -m pytest tests/ -v                        # все тесты
py -m pytest tests/test_features.py -v        # только unit
py -m pytest tests/test_e2e.py -v -s          # E2E с выводом
```

## Документация

| Файл | Содержание |
|------|------------|
| [docs/vision.md](docs/vision.md) | Идея, архитектура, cloud-only ML |
| [docs/integration.md](docs/integration.md) | HTTP + JSON контракт для плагина |
| [docs/ml-roadmap.md](docs/ml-roadmap.md) | Статус и план ML |
| [godot-plugin/README.md](godot-plugin/README.md) | Установка аддона |

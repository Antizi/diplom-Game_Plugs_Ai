# Дипломный проект DiplicsTM — адаптивный геймплей на телеметрии

Godot-аддон → Backend API (PostgreSQL) → ML-service (`/predict`).

## Команда

- Изотов Антон — ML / Data Science
- Артамонов Федор — Godot / плагин
- Самигуллин Максим — Backend / БД

## Структура репозитория

```text
diplom-Game_Plugs_Ai/
├── docker-compose.yml
├── .env.example
├── backend/                    # FastAPI (пакет app/)
├── ml/                           # POST /predict
│   └── research/lstm/            # офлайн-прототип
├── godot-plugin/
│   ├── addons/analytics_plugin/  # ← отдавать разработчикам игр
│   └── examples/                 # шаблоны GDScript (не аддон)
└── docs/
    ├── integration.md            # JSON-контракт API
    └── ml-roadmap.md             # план по ML-service
```

## Быстрый старт (backend + ML)

```powershell
# из корня репозитория
copy .env.example .env   # при необходимости
docker compose up --build -d
```

| Сервис | URL |
|--------|-----|
| API + Swagger | http://localhost:8000/docs |
| ML health | http://localhost:8001/health |
| Postgres | localhost:5432 |

## Godot — перенос плагина в новый проект

1. Скопируйте **только** `godot-plugin/addons/analytics_plugin/` → `ваш_проект/addons/analytics_plugin/` (не копируйте `prototip-plugina-1/` и `.godot/`).
2. Откройте свой `project.godot` в Godot 4 → **Project → Project Settings → Plugins** → включите **Analytics Plugin** (autoload `Analytics` добавится автоматически).
3. Вкладка **Analytics** внизу редактора → **Настроить облачный режим** → URL: `http://localhost:8000/telemetry/ingest` → Сохранить.
4. В игре: `Analytics.initialize()` → `start_new_game` → `track` → `end_game` (шаблоны: `godot-plugin/examples/`).

```powershell
# пример копирования (Windows)
Copy-Item -Recurse -Force godot-plugin\addons\analytics_plugin C:\path\to\your_game\addons\analytics_plugin
```

Подробная инструкция: [godot-plugin/README.md](godot-plugin/README.md) · API: [docs/integration.md](docs/integration.md) · E2E: [docs/E2E.md](docs/E2E.md)

## Локальная разработка без Docker

```powershell
# Backend
cd backend
pip install -r requirements.txt
$env:DB_HOST="localhost"; $env:DB_PASSWORD="postgres"
python -m uvicorn app.main:app --reload --port 8000

# ML
cd ml
pip install -r requirements.txt
$env:ML_SERVICE_URL="http://localhost:8001"   # для ручной проверки predict
python -m uvicorn main:app --port 8001
```

Тесты backend: `cd backend` → `pip install -r requirements-dev.txt` → `pytest tests/ -v`

Seed: `.\scripts\seed.ps1` → ML из БД: `.\scripts\train-from-db.ps1`

## Документация

| Файл | Содержание |
|------|------------|
| [docs/vision.md](docs/vision.md) | Идея проекта, cloud-only ML, задачи по компонентам |
| [docs/integration.md](docs/integration.md) | HTTP + JSON для плагина |
| [docs/ml-roadmap.md](docs/ml-roadmap.md) | План по ML |
| [docs/E2E.md](docs/E2E.md) | Сквозной тест Godot → API → ML |
| [backend/README.md](backend/README.md) | API, env, тесты |
| [ml/README.md](ml/README.md) | ML runtime |

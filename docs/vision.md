# DiplicsTM — видение проекта и план разработки

Документ фиксирует общую идею дипломного проекта, принятые архитектурные решения и оставшиеся задачи по компонентам. Используется как единая точка входа для команды и для контекста при дальнейшей разработке.

---

## Идея проекта

**DiplicsTM** — система адаптивного геймплея на основе телеметрии игрока.

Игра (Godot) собирает события: время прохождения, смерти, использование подсказок и т.д. События уходят на сервер, где из них строятся признаки (features), ML-модель определяет **архетип игрока** и возвращает **рекомендации по адаптации** (сложность, плотность врагов, множитель лута). Игра применяет эти параметры в рантайме — геймплей подстраивается под стиль игрока без ручной настройки.

Ключевой принцип: **разработчик игры не пишет ML-код**. Он:

1. Устанавливает Godot-плагин `analytics_plugin`.
2. В редакторе задаёт список событий, критические метрики и архетипы.
3. В коде вызывает `Analytics.track(...)` и обрабатывает сигнал `adaptation_received`.

Вся ML-логика, обучение и хранение модели — **только на сервере**.

---

## Команда и зоны ответственности

| Участник | Роль | Компонент |
|----------|------|-----------|
| Изотов Антон | ML / Data Science | `ml/` — инференс, обучение, ONNX |
| Артамонов Федор | Godot / плагин | `godot-plugin/addons/analytics_plugin/` |
| Самигуллин Максим | Backend / БД | `backend/` — API, Postgres, связка с ML |

---

## Архитектура (cloud-only)

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  Godot 4 + analytics_plugin                                             │
│  • initialize / start_new_game / track / end_game                       │
│  • редактор: ML-профиль, URL сервера, offline-буфер событий             │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ HTTP
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Backend (FastAPI + PostgreSQL)                                         │
│  • сессии, ingest телеметрии, профиль игры                              │
│  • build_features_from_events() → вектор признаков                      │
│  • вызов ML-service, сохранение prediction, ответ adaptation            │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ HTTP POST /predict
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  ML-service (FastAPI)                                                   │
│  • POST /predict — инференс (ONNX / эвристика)                          │
│  • POST /train — обучение на данных из Postgres (TODO)                  │
│  • GET  /health — статус модели                                         │
│  • models/classifier.onnx + model_meta.json                             │
└─────────────────────────────────────────────────────────────────────────┘
```

### Поток данных при игре

```text
1. Analytics.start_new_game()
      → POST /game/session/start
      ← session_id (UUID)

2. Analytics.track("level_complete", { time_sec: 120, deaths: 2 })
      → события копятся в буфере
      → POST /telemetry/ingest (батч + metadata: critical_points, archetypes)

3. Backend сохраняет events в Postgres
      → после bootstrap_actions событий строит features
      → POST /predict → ML-service
      ← predicted_archetype, confidence, recommended_adaptation
      → сохраняет prediction, возвращает adaptation в ответе ingest

4. Godot: сигнал adaptation_received → игра меняет difficulty, enemy_density и т.д.

5. Analytics.end_game()
      → PATCH /game/session/{id}/end
```

---

## Принятое решение: без локальной ML-модели

**Отказываемся от локального режима с ONNX/SQLite на клиенте.**

| Было в планах | Решение |
|---------------|---------|
| Режим `local`: SQLite + offline ONNX в Godot | **Не делаем** |
| Скачивание модели `GET /game/model/download` в плагин | **Не делаем** |
| Инференс на устройстве игрока | **Не делаем** |

**Оставляем в плагине:**

- **Cloud-режим** — единственный способ получить адаптацию.
- **Offline-буфер** — JSONL-очередь событий при отсутствии сети; при восстановлении связи события отправляются на backend, ML считается на сервере.
- Локальные файлы `user://` только для конфига, player_id и очереди — не для ML.

Модель живёт **только в ML-service**. Backend — единственный клиент ML для predict. Обучение — тоже на сервере (скрипт или endpoint), не в Godot и не при `docker build`.

---

## Что уже работает

| Компонент | Статус |
|-----------|--------|
| Docker Compose: postgres + backend + ml | ✅ |
| Backend: сессии, ingest, профиль, features | ✅ |
| Backend → ML `POST /predict` через `ml_client.py` | ✅ |
| ML: `GET /health`, `POST /predict`, ONNX + fallback | ✅ частично |
| Godot: autoload, cloud sender, буфер, offline JSONL | ✅ |
| Godot: ML-профиль → `PUT /game/profile` | ✅ |
| Godot: `AdaptationBridge`, примеры, E2E-док | ✅ |
| Seed данных + обучение из Postgres (скрипт) | ✅ скрипт |

---

## Задачи по компонентам

### 1. ML-service (`ml/`) — приоритет

Цель: **самостоятельный сервис** с инференсом и обучением; backend ходит к нему по HTTP.

| # | Задача | Детали |
|---|--------|--------|
| 1.1 | Стабильный Docker-образ | Убрать `RUN python scripts/train_model.py` из Dockerfile (сейчас ломает build). Модель: volume `./ml/models` или train при старте/по запросу. |
| 1.2 | `POST /train` | Endpoint или фоновая задача: читать events из Postgres → датасет → sklearn/LSTM → ONNX → обновить `classifier.onnx` + `model_meta.json`. |
| 1.3 | Валидация `/predict` | Проверять `features` по `feature_order` из `model_meta.json`; явные ошибки, если модель не загружена. |
| 1.4 | Версионирование | `model_version` в ответе; hot-reload модели после train без пересборки образа. |
| 1.5 | Метрики | Лог latency predict, fallback rate, версия модели в `/health`. |
| 1.6 | LSTM (исследование) | Прототип в `ml/research/lstm/` → экспорт ONNX → замена sklearn, когда готово. |

**Контракт `/predict` (без изменений):**

```json
{
  "session_id": "uuid",
  "player_id": "player_...",
  "features": { "time_sec": 120.0, "deaths": 2.0 },
  "model_version": "optional",
  "archetypes": ["explorer", "achiever", "socializer"]
}
```

**Планируемый `/train`:**

```json
{
  "source": "postgres",
  "min_events": 100,
  "model_version": "sklearn-rf-1.1"
}
```

---

### 2. Backend (`backend/`) — связка с ML

| # | Задача | Детали |
|---|--------|--------|
| 2.1 | Надёжный вызов ML | При недоступности ML — понятная ошибка в ingest (сейчас есть backend-эвристика; зафиксировать политику: fallback или 503). |
| 2.2 | Триггер обучения | `POST /admin/train` или cron → вызов ML `POST /train`; обновление `game_models` (version, onnx blob, feature_schema). |
| 2.3 | Согласованность профиля | `critical_points` из Godot = `feature_order` для features и для ML meta. |
| 2.4 | Убрать dead code local-model | Эндпоинты manifest/download ONNX оставить только для админки/отладки, не для плагина. |

---

### 3. Godot-плагин (`godot-plugin/addons/analytics_plugin/`) — довести до продакшена

Цель: **разработчик копирует одну папку аддона** и получает работающую cloud-интеграцию.

| # | Задача | Детали |
|---|--------|--------|
| 3.1 | Исправить parse error | Переименовать локальную переменную `name` в `sync_game_profile()` (конфликт с `Node.name`). |
| 3.2 | Упростить конфиг | Убрать/скрыть `mode: local`, `ml_model_path`, `local_db_path` из UI; cloud — режим по умолчанию. |
| 3.3 | Панель редактора | Профиль: события, critical points, архетипы, bootstrap_actions; кнопка «Проверить сервер»; блок последней адаптации. |
| 3.4 | Применение adaptation | Документировать + `AdaptationBridge`: difficulty, enemy_density, loot_multiplier из `adaptation.parameters`. |
| 3.5 | Надёжность сети | Доработать retry, flush offline-очереди, индикация в панели. |
| 3.6 | Примеры и E2E | `examples/test_integration.gd` + [E2E.md](E2E.md) как регрессионный чеклист. |

**Минимальный API для игры:**

```gdscript
Analytics.initialize()
Analytics.start_new_game("1.0.0")
Analytics.track("level_complete", {"time_sec": 120.0, "deaths": 2})
Analytics.adaptation_received.connect(_apply_adaptation)
Analytics.end_game()
```

---

## Соглашения по данным

### ML-профиль (Godot → backend)

- **События** — имена для `track()`, например `level_complete`, `puzzle_solved`.
- **Critical points** — числовые поля в `parameters` событий, из которых backend строит features: `time_sec`, `deaths`, `hints_used`.
- **Архетипы** — классы, которые предсказывает модель: `explorer`, `achiever`, `socializer`, `killer`.
- **bootstrap_actions** — сколько событий нужно до первого predict (по умолчанию 10).

`feature_order` на backend должен совпадать с именами critical points из плагина.

### Адаптация (ML → Godot)

```json
{
  "adaptation": {
    "parameters": {
      "difficulty": 2,
      "enemy_density": 1.2,
      "loot_multiplier": 1.0
    }
  }
}
```

Игра читает `parameters` и применяет к своим системам баланса.

---

## Инфраструктура

```powershell
# из корня репозитория
copy .env.example .env
docker compose up --build -d
```

| Сервис | URL |
|--------|-----|
| API + Swagger | http://localhost:8000/docs |
| ML health | http://localhost:8001/health |
| Postgres | localhost:5432 |

Плагин в Godot: URL ingest = `http://localhost:8000/telemetry/ingest`.

---

## Порядок работ (рекомендуемый)

```text
Фаза 1 — стабильный стек
  • Починить ml/Dockerfile (без train на build)
  • Убедиться: ingest → predict → adaptation в Godot (E2E)

Фаза 2 — ML на сервере
  • POST /train + скрипт train_from_postgres
  • Backend: регистрация новой model_version после train

Фаза 3 — плагин
  • Fix parse error, убрать local ML из UI
  • Полировка панели, offline, примеры

Фаза 4 — качество модели
  • Обучение на реальных/seed данных
  • LSTM → ONNX (по готовности)
```

---

## Связанные документы

| Файл | Назначение |
|------|------------|
| [integration.md](integration.md) | HTTP-контракт для плагина |
| [E2E.md](E2E.md) | Сквозной тест Godot → API → ML |
| [ml-roadmap.md](ml-roadmap.md) | Детали по ML-service |
| [godot-plugin/README.md](../godot-plugin/README.md) | Установка аддона |
| [README.md](../README.md) | Быстрый старт репозитория |

---

## Краткое резюме для контекста

> **DiplicsTM** — Godot-плагин шлёт телеметрию на FastAPI-backend; backend строит features и вызывает отдельный ML-service; ML возвращает архетип и параметры адаптации; игра их применяет. Локальной модели в клиенте нет — только серверный ONNX и обучение на сервере. Плагин настраивается в редакторе Godot (профиль + URL), в игре — четыре вызова API autoload `Analytics`.

# ML-service: что сделано и что осталось

## Текущее состояние

| Компонент | Статус |
|-----------|--------|
| `ml/main.py` — `GET /health`, `POST /predict` | ✅ runtime |
| Docker-сервис `ml` в корневом `docker-compose.yml` | ✅ |
| Backend вызывает ML через `app/services/ml_client.py` | ✅ |
| sklearn → ONNX (`classifier.onnx`) + fallback-эвристика | ✅ |
| `ml/research/lstm/` — офлайн-прототип PyTorch | ✅ исследование, не в проде |

Цепочка в cloud:

```text
Godot → POST /telemetry/ingest (backend)
          → build_features_from_events()
          → POST /predict (ml)  [если ML_PREDICT_ENABLED=true]
          → adaptation в ответе ingest
```

---

## Что нужно сделать для полноценного ML

### 1. Модель вместо эвристики (приоритет)

- [x] Экспорт **ONNX** (RandomForest, `ml/scripts/train_model.py`).
- [x] Загрузка ONNX в `ml/main.py` (`onnxruntime`).
- [x] Версионирование: `model_version` в ответе (`sklearn-rf-1.0`).
- [x] Обучить на данных из Postgres (`ml/scripts/train_from_postgres.py`, `scripts/train-from-db.ps1`).
- [ ] LSTM → ONNX и замена sklearn.
- [ ] Регистрация артефакта в `game_models.onnx` на backend.

### 2. Контракт `/predict` (расширение)

Сейчас тело:

```json
{
  "session_id": "...",
  "player_id": "...",
  "features": { "time_sec": 12.0, "deaths": 1.0 },
  "model_version": "optional",
  "archetypes": ["explorer", "achiever"]
}
```

Планируемые дополнения:

- [ ] `POST /train` — дообучение по батчу (или отдельный offline-скрипт + загрузка артефакта).
- [ ] Валидация `features` по `feature_order` из профиля игры.
- [ ] Явные коды ошибок, если модель не загружена.

### 3. Связка с backend

- [ ] Backend: при успешном train — обновить `game_models` и `GET /game/model/manifest`.
- [ ] Плагин (будущее): скачивание ONNX для local-режима.
- [ ] Метрики: логировать latency `/predict`, fallback rate.

### 4. Пайплайн обучения (Anton)

- [ ] Скрипт `ml/scripts/train.py`: читает события из Postgres → датасет → train → ONNX.
- [ ] CI/job: периодическое переобучение (опционально).
- [ ] Документировать зависимость `feature_order` ↔ `critical_points` в Godot.

### 5. LSTM (`ml/research/lstm`)

- [ ] Привести выход прототипа к тем же `archetypes`, что в профиле игры.
- [ ] Экспорт в ONNX и проверка в `onnxruntime`.
- [ ] Не дублировать ingest — только обучение и экспорт артефактов.

---

## Быстрая проверка сейчас

```powershell
docker compose up --build -d
curl http://localhost:8001/health
curl -X POST http://localhost:8001/predict -H "Content-Type: application/json" -d "{\"session_id\":\"s1\",\"player_id\":\"p1\",\"features\":{\"score\":10},\"archetypes\":[\"a\",\"b\"]}"
```

После ingest с достаточным числом событий (`bootstrap_actions`) в ответе должен быть `prediction` с `model_version` вида `ml-heuristic-0.2` или будущей ONNX-модели.

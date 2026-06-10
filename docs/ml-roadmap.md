# ML-service: что сделано и что осталось

> **Архитектурное решение:** ML только на сервере, без offline ONNX в Godot. См. [vision.md](vision.md).

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
          → POST /predict (ml)  [каждые bootstrap_actions событий]
          → adaptation в ответе ingest
```

---

## Что нужно сделать для полноценного ML

### 1. Модель вместо эвристики (приоритет)

- [x] Экспорт **ONNX** (RandomForest, `ml/scripts/train_model.py`).
- [x] Загрузка ONNX в `ml/main.py` (`onnxruntime`).
- [x] Версионирование: `model_version` в ответе.
- [x] Обучить на данных из Postgres (`ml/scripts/train_from_postgres.py`, `scripts/train-from-db.ps1`).
- [x] `POST /train` в ML-сервисе — запуск из панели Godot и из backend `/game/train`.
- [x] После обучения модель перезагружается без рестарта контейнера.
- [ ] LSTM → ONNX и замена sklearn.

### 2. Предсказания

- [x] Предсказание каждые `bootstrap_actions` событий (10, 20, 30…) вместо однократного.
- [ ] Валидация `features` по `feature_order` из профиля игры.

### 3. Связка с backend

- [x] `POST /game/train` в backend — проксирует запрос в ML-сервис.
- [x] Cloud-only режим — локальный ONNX и локальный режим удалены.
- [ ] Метрики: логировать latency `/predict`, fallback rate.

### 4. LSTM (`ml/research/lstm`)

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

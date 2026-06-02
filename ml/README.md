# ML Predict Service

Runtime-сервис: **только инференс**. Телеметрия — в backend.

| Метод | Путь | Назначение |
|-------|------|------------|
| GET | `/health` | Healthcheck |
| POST | `/predict` | Архетип + `recommended_adaptation` по признакам |

Полный план развития: [docs/ml-roadmap.md](../docs/ml-roadmap.md).

## Запуск

```powershell
# Docker (из корня репо)
docker compose up -d ml

# локально
cd ml
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8001
```

## Пример predict

```powershell
curl -X POST http://localhost:8001/predict `
  -H "Content-Type: application/json" `
  -d '{"session_id":"s1","player_id":"p1","features":{"score":10},"archetypes":["explorer","achiever"]}'
```

## Исследования

Прототип LSTM (обучение offline, не runtime): [research/lstm/README.md](research/lstm/README.md)

"""
E2E-тест: полный цикл как Godot-плагин.

Godot start_new_game → track × N → adaptation_received → end_game
"""
import uuid
import httpx
import pytest

BASE = "http://localhost:8000"
PLAYER_ID = f"e2e_player_{uuid.uuid4().hex[:8]}"

# 12 событий — больше bootstrap_actions=10, чтобы гарантированно сработал predict
EVENTS = [
    ("level_complete", {"score": 95.0, "deaths": 1.0, "time_sec": 45.0}),
    ("jump",           {"score": 10.0, "deaths": 0.0, "time_sec": 5.0}),
    ("enemy_killed",   {"score": 20.0, "deaths": 2.0, "time_sec": 30.0}),
    ("item_collected", {"score": 15.0, "deaths": 0.0, "time_sec": 20.0}),
    ("level_complete", {"score": 80.0, "deaths": 1.0, "time_sec": 50.0}),
    ("checkpoint",     {"score": 5.0,  "deaths": 0.0, "time_sec": 10.0}),
    ("enemy_killed",   {"score": 25.0, "deaths": 3.0, "time_sec": 35.0}),
    ("jump",           {"score": 8.0,  "deaths": 0.0, "time_sec": 4.0}),
    ("item_collected", {"score": 12.0, "deaths": 0.0, "time_sec": 15.0}),
    ("level_complete", {"score": 90.0, "deaths": 1.0, "time_sec": 40.0}),
    ("enemy_killed",   {"score": 30.0, "deaths": 4.0, "time_sec": 25.0}),
    ("checkpoint",     {"score": 5.0,  "deaths": 0.0, "time_sec": 8.0}),
]


@pytest.fixture(scope="module")
def client():
    with httpx.Client(base_url=BASE, timeout=30.0) as c:
        yield c


@pytest.fixture(scope="module")
def session_id(client):
    r = client.post(f"/game/session/start?player_id={PLAYER_ID}&game_version=e2e-1.0")
    assert r.status_code == 200, r.text
    sid = r.json()["session_id"]
    print(f"\n  session_id: {sid}")
    return sid


def test_1_health(client):
    """Оба сервиса живы."""
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"
    assert r.json()["database"] == "ok"

    r_ml = httpx.get("http://localhost:8001/health", timeout=5)
    assert r_ml.status_code == 200
    body = r_ml.json()
    assert body["model_loaded"] is True
    print(f"\n  ML model: {body['model_version']}")


def test_2_session_start(session_id):
    """Сессия создана, session_id — валидный UUID."""
    assert uuid.UUID(session_id)


def test_3_ingest_first_batch_no_prediction(client, session_id):
    """5 событий — меньше bootstrap_actions=10, prediction не должен прийти."""
    events = [
        {
            "session_id": session_id,
            "player_id": PLAYER_ID,
            "event_name": name,
            "timestamp": float(i),
            "parameters": params,
        }
        for i, (name, params) in enumerate(EVENTS[:5])
    ]
    r = client.post("/telemetry/ingest", json={"events": events, "metadata": {}})
    assert r.status_code == 200
    body = r.json()
    assert body["events_received"] == 5
    assert body["prediction"] is None, "После 5 событий predict не должен срабатывать"


def test_4_ingest_second_batch_triggers_prediction(client, session_id):
    """Ещё 7 событий → итого 12 → predict срабатывает, adaptation приходит."""
    events = [
        {
            "session_id": session_id,
            "player_id": PLAYER_ID,
            "event_name": name,
            "timestamp": float(5 + i),
            "parameters": params,
        }
        for i, (name, params) in enumerate(EVENTS[5:])
    ]
    r = client.post("/telemetry/ingest", json={"events": events, "metadata": {}})
    assert r.status_code == 200
    body = r.json()
    assert body["events_received"] == 7

    prediction = body.get("prediction")
    adaptation = body.get("adaptation")

    assert prediction is not None, f"prediction должен прийти после 12 событий. Ответ: {body}"
    assert adaptation is not None, "adaptation должен прийти вместе с prediction"

    assert prediction["predicted_archetype"] in ["explorer", "achiever", "socializer", "killer"]
    assert 0.0 <= prediction["confidence"] <= 1.0

    assert "parameters" in adaptation
    print(f"\n  archetype:  {prediction['predicted_archetype']}")
    print(f"  confidence: {prediction['confidence']:.2f}")
    print(f"  adaptation: {adaptation['parameters']}")


def test_5_get_adaptation_endpoint(client, session_id):
    """GET /game/adaptation/{id} возвращает последнее предсказание."""
    r = client.get(f"/game/adaptation/{session_id}")
    assert r.status_code == 200
    body = r.json()
    assert body["predicted_archetype"] in ["explorer", "achiever", "socializer", "killer"]
    assert "parameters" in body
    print(f"\n  GET adaptation: {body['parameters']}")


def test_6_session_end(client, session_id):
    """Сессия завершается, ended_at проставлен."""
    r = client.patch(f"/game/session/{session_id}/end")
    assert r.status_code == 200
    body = r.json()
    assert body["ended_at"] is not None
    print(f"\n  ended_at: {body['ended_at']}")


def test_7_second_predict_cycle(client):
    """Новая сессия: 20 событий → два цикла predict (на 10-м и 20-м)."""
    player = f"e2e_p2_{uuid.uuid4().hex[:6]}"
    r = client.post(f"/game/session/start?player_id={player}")
    assert r.status_code == 200
    sid = r.json()["session_id"]

    all_events = (EVENTS * 2)[:20]

    # Первый батч: 10 событий → первый predict
    batch1 = [
        {"session_id": sid, "player_id": player,
         "event_name": name, "timestamp": float(i), "parameters": params}
        for i, (name, params) in enumerate(all_events[:10])
    ]
    r1 = client.post("/telemetry/ingest", json={"events": batch1, "metadata": {}})
    assert r1.status_code == 200
    assert r1.json()["prediction"] is not None, "Первый predict на 10 событиях"

    # Второй батч: ещё 10 → второй predict
    batch2 = [
        {"session_id": sid, "player_id": player,
         "event_name": name, "timestamp": float(10 + i), "parameters": params}
        for i, (name, params) in enumerate(all_events[10:])
    ]
    r2 = client.post("/telemetry/ingest", json={"events": batch2, "metadata": {}})
    assert r2.status_code == 200
    assert r2.json()["prediction"] is not None, "Второй predict на 20 событиях"

    arch1 = r1.json()["prediction"]["predicted_archetype"]
    arch2 = r2.json()["prediction"]["predicted_archetype"]
    print(f"\n  predict #1: {arch1}")
    print(f"  predict #2: {arch2}")

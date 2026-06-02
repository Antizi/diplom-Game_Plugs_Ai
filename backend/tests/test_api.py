import os
import uuid

import pytest
from fastapi.testclient import TestClient

from app.main import app

pytestmark = pytest.mark.skipif(
    not os.getenv("TEST_DATABASE_URL") and not os.getenv("DB_HOST"),
    reason="Set TEST_DATABASE_URL or run against DB_HOST (e.g. docker postgres)",
)


@pytest.fixture
def client():
    return TestClient(app)


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"


def test_session_lifecycle(client):
    player_id = f"test_{uuid.uuid4().hex[:8]}"
    r = client.post(f"/game/session/start?player_id={player_id}&game_version=1.0")
    assert r.status_code == 200
    session_id = r.json()["session_id"]

    r = client.patch(f"/game/session/{session_id}/end")
    assert r.status_code == 200
    assert r.json()["ended_at"] is not None


def test_game_profile_and_ingest(client):
    client.put(
        "/game/profile",
        json={
            "critical_points": [{"name": "score", "weight": 1}],
            "archetypes": ["a", "b"],
            "bootstrap_actions": 2,
        },
    )

    player_id = f"p_{uuid.uuid4().hex[:8]}"
    r = client.post(f"/game/session/start?player_id={player_id}")
    session_id = r.json()["session_id"]

    events = [
        {
            "session_id": session_id,
            "player_id": player_id,
            "event_name": "jump",
            "timestamp": 1.0,
            "parameters": {"score": 5},
        },
        {
            "session_id": session_id,
            "player_id": player_id,
            "event_name": "jump",
            "timestamp": 2.0,
            "parameters": {"score": 3},
        },
    ]
    r = client.post(
        "/telemetry/ingest",
        json={"events": events, "metadata": {}},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["events_received"] == 2
    assert body.get("prediction") is not None
    assert body.get("adaptation") is not None

    r = client.get(f"/sessions/{session_id}/prediction/latest")
    assert r.status_code == 200
    assert r.json()["predicted_archetype"] is not None

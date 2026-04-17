import json
import sqlite3
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "ml_metrics.db"
BOOTSTRAP_ACTIONS = 10

app = FastAPI(title="ML Service", version="0.1.0")


class CriticalPoint(BaseModel):
    name: str = Field(..., description="Имя метрики")
    weight: float = Field(default=1.0, ge=0.0)


class GameProfileIn(BaseModel):
    game_id: str
    critical_points: List[CriticalPoint] = Field(default_factory=list)
    archetypes: List[str] = Field(default_factory=list)


class EventIn(BaseModel):
    session_id: str
    player_id: str
    event_name: str
    timestamp: float
    game_time: Optional[float] = 0.0
    parameters: Dict[str, Any] = Field(default_factory=dict)
    state: Dict[str, Any] = Field(default_factory=dict)


class TelemetryIn(BaseModel):
    game_id: str = "default_game"
    events: List[EventIn]
    metadata: Dict[str, Any] = Field(default_factory=dict)


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with get_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS game_profiles (
                game_id TEXT PRIMARY KEY,
                critical_points_json TEXT NOT NULL,
                archetypes_json TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS telemetry_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                game_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                player_id TEXT NOT NULL,
                event_name TEXT NOT NULL,
                timestamp REAL NOT NULL,
                game_time REAL NOT NULL,
                parameters_json TEXT NOT NULL,
                state_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS training_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                game_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                player_id TEXT NOT NULL,
                metric_name TEXT NOT NULL,
                metric_value REAL NOT NULL,
                weight REAL NOT NULL,
                label_archetype TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS predictions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                game_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                player_id TEXT NOT NULL,
                predicted_archetype TEXT NOT NULL,
                confidence REAL NOT NULL,
                details_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.commit()


def upsert_game_profile(payload: GameProfileIn) -> None:
    now = datetime.utcnow().isoformat()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO game_profiles(game_id, critical_points_json, archetypes_json, updated_at)
            VALUES(?, ?, ?, ?)
            ON CONFLICT(game_id) DO UPDATE SET
                critical_points_json=excluded.critical_points_json,
                archetypes_json=excluded.archetypes_json,
                updated_at=excluded.updated_at
            """,
            (
                payload.game_id,
                json.dumps([p.model_dump() for p in payload.critical_points]),
                json.dumps(payload.archetypes),
                now,
            ),
        )
        conn.commit()


def get_game_profile(game_id: str) -> Dict[str, Any]:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM game_profiles WHERE game_id = ?", (game_id,)
        ).fetchone()
    if not row:
        return {"critical_points": [], "archetypes": []}
    return {
        "critical_points": json.loads(row["critical_points_json"]),
        "archetypes": json.loads(row["archetypes_json"]),
    }


def save_events(game_id: str, events: List[EventIn]) -> None:
    now = datetime.utcnow().isoformat()
    with get_conn() as conn:
        for event in events:
            conn.execute(
                """
                INSERT INTO telemetry_events(
                    game_id, session_id, player_id, event_name, timestamp, game_time,
                    parameters_json, state_json, created_at
                )
                VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    game_id,
                    event.session_id,
                    event.player_id,
                    event.event_name,
                    event.timestamp,
                    float(event.game_time or 0.0),
                    json.dumps(event.parameters),
                    json.dumps(event.state),
                    now,
                ),
            )
        conn.commit()


def build_metrics(events: List[EventIn], critical_points: List[Dict[str, Any]]) -> Dict[str, float]:
    cp_weights = {cp["name"]: float(cp.get("weight", 1.0)) for cp in critical_points}
    metric_values: Dict[str, float] = defaultdict(float)

    limited = events[:BOOTSTRAP_ACTIONS]
    metric_values["event_count_first10"] = float(len(limited))

    for event in limited:
        metric_values[f"event::{event.event_name}"] += 1.0
        for key, value in event.parameters.items():
            if isinstance(value, (int, float)):
                metric_values[key] += float(value)

    # Поддержка весов метрик разработчика
    for key in list(metric_values.keys()):
        if key in cp_weights:
            metric_values[key] *= cp_weights[key]

    return dict(metric_values)


def save_metrics_and_predict(
    game_id: str,
    session_id: str,
    player_id: str,
    metrics: Dict[str, float],
    critical_points: List[Dict[str, Any]],
    archetypes: List[str],
) -> Dict[str, Any]:
    cp_weights = {cp["name"]: float(cp.get("weight", 1.0)) for cp in critical_points}
    now = datetime.utcnow().isoformat()

    with get_conn() as conn:
        for name, value in metrics.items():
            conn.execute(
                """
                INSERT INTO training_metrics(
                    game_id, session_id, player_id, metric_name, metric_value, weight, label_archetype, created_at
                )
                VALUES(?, ?, ?, ?, ?, ?, NULL, ?)
                """,
                (game_id, session_id, player_id, name, value, cp_weights.get(name, 1.0), now),
            )

        # Легкая стартовая эвристика вместо обученной модели
        if archetypes:
            idx = int(abs(sum(metrics.values()))) % len(archetypes)
            predicted = archetypes[idx]
            confidence = 0.55
        else:
            predicted = "unknown"
            confidence = 0.0

        details = {"metrics": metrics, "bootstrap_actions": BOOTSTRAP_ACTIONS}
        conn.execute(
            """
            INSERT INTO predictions(
                game_id, session_id, player_id, predicted_archetype, confidence, details_json, created_at
            )
            VALUES(?, ?, ?, ?, ?, ?, ?)
            """,
            (game_id, session_id, player_id, predicted, confidence, json.dumps(details), now),
        )
        conn.commit()

    return {"predicted_archetype": predicted, "confidence": confidence, "details": details}


@app.on_event("startup")
def on_startup() -> None:
    init_db()


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.post("/profiles")
def create_or_update_profile(payload: GameProfileIn) -> Dict[str, str]:
    upsert_game_profile(payload)
    return {"status": "saved", "game_id": payload.game_id}


@app.post("/telemetry/ingest")
def ingest_telemetry(payload: TelemetryIn) -> Dict[str, Any]:
    if not payload.events:
        raise HTTPException(status_code=400, detail="events is empty")

    game_id = payload.game_id or payload.metadata.get("game_id", "default_game")
    profile = get_game_profile(game_id)

    critical_points = payload.metadata.get("critical_points", profile["critical_points"])
    archetypes = payload.metadata.get("archetypes", profile["archetypes"])

    save_events(game_id, payload.events)
    metrics = build_metrics(payload.events, critical_points)
    first_event = payload.events[0]
    prediction = save_metrics_and_predict(
        game_id=game_id,
        session_id=first_event.session_id,
        player_id=first_event.player_id,
        metrics=metrics,
        critical_points=critical_points,
        archetypes=archetypes,
    )

    return {
        "status": "ingested",
        "game_id": game_id,
        "events_received": len(payload.events),
        "prediction": prediction,
    }
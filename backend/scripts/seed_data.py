#!/usr/bin/env python3
"""
Генерация тестовых данных в PostgreSQL с разметкой архетипов (predictions).

Пример:
  cd backend
  pip install -r requirements.txt
  set DB_HOST=localhost
  set DB_PASSWORD=postgres
  python scripts/seed_data.py --sessions 1000 --events-per-session 12

После seed — обучение ML:
  ..\\scripts\\train-from-db.ps1
"""
from __future__ import annotations

import argparse
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.database import SessionLocal, engine  # noqa: E402
from app import models  # noqa: E402
from app.main import _run_migrations  # noqa: E402
from app.services.features import build_features_from_events  # noqa: E402

ARCHETYPES = ["explorer", "achiever", "socializer", "killer"]
GAME_VERSION = "1.0.0-seed"
BOOTSTRAP_ACTIONS = 10

# События с перекосом под архетип (для обучения из Postgres)
ARCHETYPE_EVENT_BIAS = {
    "explorer": [
        ("item_collected", 0.45),
        ("checkpoint", 0.25),
        ("jump", 0.15),
        ("level_complete", 0.15),
    ],
    "achiever": [
        ("level_complete", 0.4),
        ("checkpoint", 0.25),
        ("jump", 0.2),
        ("item_collected", 0.15),
    ],
    "socializer": [
        ("jump", 0.45),
        ("checkpoint", 0.25),
        ("item_collected", 0.2),
        ("level_complete", 0.1),
    ],
    "killer": [
        ("enemy_killed", 0.4),
        ("damage_taken", 0.3),
        ("jump", 0.15),
        ("level_complete", 0.15),
    ],
}

CRITICAL_POINTS = [
    {"name": "score", "weight": 1.0},
    {"name": "deaths", "weight": 2.0},
    {"name": "time_sec", "weight": 1.0},
]

FEATURE_ORDER = [
    "event_count_first_n",
    "score",
    "deaths",
    "time_sec",
    "event::jump",
    "event::enemy_killed",
    "event::item_collected",
    "event::level_complete",
]


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def ensure_schema() -> None:
    models.Base.metadata.create_all(bind=engine)
    _run_migrations()


def ensure_profile(db) -> models.GameModel:
    profile = db.query(models.GameModel).order_by(models.GameModel.created_at.desc()).first()
    if profile:
        profile.critical_points = CRITICAL_POINTS
        profile.archetypes = ARCHETYPES
        profile.feature_schema = {
            "order": FEATURE_ORDER,
            "bootstrap_actions": BOOTSTRAP_ACTIONS,
        }
        db.commit()
        db.refresh(profile)
        return profile
    profile = models.GameModel(
        model_version="seed-model-1",
        game_profile_version=1,
        feature_schema_version=1,
        critical_points=CRITICAL_POINTS,
        archetypes=ARCHETYPES,
        feature_schema={
            "order": FEATURE_ORDER,
            "bootstrap_actions": BOOTSTRAP_ACTIONS,
        },
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


def _pick_event_type(archetype: str) -> str:
    weights = ARCHETYPE_EVENT_BIAS[archetype]
    types = [t for t, _ in weights]
    probs = [w for _, w in weights]
    return random.choices(types, weights=probs, k=1)[0]


def _parameters_for(archetype: str, event_type: str) -> dict:
    """Параметры, согласованные с critical_points и архетипом."""
    base = {
        "explorer": {"score": 40, "deaths": 0, "time_sec": 90},
        "achiever": {"score": 95, "deaths": 1, "time_sec": 45},
        "socializer": {"score": 55, "deaths": 0, "time_sec": 70},
        "killer": {"score": 70, "deaths": 4, "time_sec": 35},
    }[archetype]
    params = {
        "score": float(base["score"] + random.randint(-15, 15)),
        "deaths": float(max(0, base["deaths"] + random.randint(-1, 2))),
        "time_sec": float(base["time_sec"] + random.randint(-10, 20)),
    }
    if event_type == "enemy_killed":
        params["deaths"] = max(params["deaths"], 2.0)
    if event_type == "level_complete":
        params["score"] += 20.0
    return params


def _add_prediction(
    db,
    session: models.Session,
    profile: models.GameModel,
    archetype: str,
    event_dicts: list,
) -> None:
    features = build_features_from_events(
        event_dicts,
        profile.critical_points or [],
        BOOTSTRAP_ACTIONS,
    )
    adaptation = {
        "explorer": {"difficulty": 0.85, "enemy_density": 0.9},
        "achiever": {"difficulty": 1.2, "enemy_density": 1.1},
        "socializer": {"difficulty": 0.95, "enemy_density": 0.85},
        "killer": {"difficulty": 1.35, "enemy_density": 1.4},
    }.get(archetype, {"difficulty": 1.0, "enemy_density": 1.0})

    db.add(
        models.Prediction(
            session_id=session.session_id,
            player_id=session.player_id,
            model_id=profile.model_id,
            predicted_archetype=archetype,
            confidence=0.85,
            result={
                "features": features,
                "recommended_adaptation": adaptation,
                "label_source": "seed",
            },
        )
    )


def seed(sessions_count: int, events_per_session: int, players_count: int) -> None:
    ensure_schema()
    db = SessionLocal()
    try:
        profile = ensure_profile(db)
        player_ids = [f"seed_player_{i:04d}" for i in range(players_count)]

        for pid in player_ids:
            if not db.query(models.Player).filter(models.Player.player_id == pid).first():
                db.add(models.Player(player_id=pid))
        db.commit()

        batch_size = 50
        for batch_start in range(0, sessions_count, batch_size):
            batch_end = min(batch_start + batch_size, sessions_count)
            for _ in range(batch_start, batch_end):
                player_id = random.choice(player_ids)
                target_archetype = random.choice(ARCHETYPES)
                started = utcnow() - timedelta(days=random.randint(0, 30), hours=random.randint(0, 23))
                duration_min = random.randint(5, 120)
                ended = started + timedelta(minutes=duration_min)

                session = models.Session(
                    session_id=uuid.uuid4(),
                    player_id=player_id,
                    model_id=profile.model_id,
                    game_version=GAME_VERSION,
                    started_at=started,
                    ended_at=ended,
                )
                db.add(session)
                db.flush()

                event_dicts = []
                for i in range(events_per_session):
                    event_type = _pick_event_type(target_archetype)
                    params = _parameters_for(target_archetype, event_type)
                    event_dicts.append(
                        {"event_name": event_type, "parameters": params}
                    )
                    db.add(
                        models.Event(
                            session_id=session.session_id,
                            event_type=event_type,
                            payload={
                                "parameters": params,
                                "state": {"hp": random.randint(20, 100)},
                            },
                            created_at=started + timedelta(seconds=i * 5),
                        )
                    )

                _add_prediction(db, session, profile, target_archetype, event_dicts)

            db.commit()
            print(f"  sessions {batch_end}/{sessions_count}")

        print("Done.")
        print(f"  players: {players_count}")
        print(f"  sessions: {sessions_count}")
        print(f"  events: ~{sessions_count * events_per_session}")
        print(f"  predictions: {sessions_count} (labeled for ML training)")
        print("Next: .\\scripts\\train-from-db.ps1")
    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed gamedb with labeled test data")
    parser.add_argument("--sessions", type=int, default=1000)
    parser.add_argument("--events-per-session", type=int, default=12)
    parser.add_argument("--players", type=int, default=50)
    args = parser.parse_args()
    seed(args.sessions, args.events_per_session, args.players)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Генерация тестовых данных в PostgreSQL.

Пример:
  cd backend
  pip install -r requirements.txt
  set DB_HOST=localhost
  set DB_PASSWORD=postgres
  python scripts/seed_data.py --sessions 1000 --events-per-session 10
"""
from __future__ import annotations

import argparse
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Корень backend в PYTHONPATH
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.database import SessionLocal, engine  # noqa: E402
from app import models  # noqa: E402
from app.main import _run_migrations  # noqa: E402

EVENT_TYPES = [
    "jump",
    "enemy_killed",
    "item_collected",
    "damage_taken",
    "level_complete",
    "checkpoint",
]

ARCHETYPES = ["explorer", "achiever", "socializer", "killer"]
GAME_VERSION = "1.0.0-seed"


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def ensure_schema() -> None:
    models.Base.metadata.create_all(bind=engine)
    _run_migrations()


def ensure_profile(db) -> models.GameModel:
    profile = db.query(models.GameModel).order_by(models.GameModel.created_at.desc()).first()
    if profile:
        return profile
    profile = models.GameModel(
        model_version="seed-model-1",
        game_profile_version=1,
        feature_schema_version=1,
        critical_points=[{"name": "deaths", "weight": 2.0}],
        archetypes=ARCHETYPES,
        feature_schema={
            "order": ["event_count_first_n", "value", "event::jump"],
            "bootstrap_actions": 10,
        },
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


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

                for _ in range(events_per_session):
                    db.add(
                        models.Event(
                            session_id=session.session_id,
                            event_type=random.choice(EVENT_TYPES),
                            payload={
                                "parameters": {"value": random.randint(1, 100)},
                                "state": {"hp": random.randint(0, 100)},
                            },
                            created_at=started + timedelta(seconds=random.randint(0, duration_min * 60)),
                        )
                    )

            db.commit()
            print(f"  sessions {batch_end}/{sessions_count}")

        print("Done.")
        print(f"  players: {players_count}")
        print(f"  sessions: {sessions_count}")
        print(f"  events: ~{sessions_count * events_per_session}")
    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed gamedb with test data")
    parser.add_argument("--sessions", type=int, default=1000)
    parser.add_argument("--events-per-session", type=int, default=10)
    parser.add_argument("--players", type=int, default=50)
    args = parser.parse_args()
    seed(args.sessions, args.events_per_session, args.players)


if __name__ == "__main__":
    main()

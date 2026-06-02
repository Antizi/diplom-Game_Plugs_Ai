#!/usr/bin/env python3
"""
Обучение классификатора на сессиях из PostgreSQL.

Метки (по приоритету):
  1. predictions.predicted_archetype для сессии
  2. эвристика по доминирующим типам событий

Пример:
  cd backend
  set DB_HOST=localhost
  set DB_PASSWORD=postgres
  python ../ml/scripts/train_from_postgres.py

  # или из корня после seed:
  .\\scripts\\seed.ps1
  .\\scripts\\train-from-db.ps1
"""
from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

ML_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = ML_ROOT.parent / "backend"
sys.path.insert(0, str(BACKEND_ROOT))
sys.path.insert(0, str(ML_ROOT))

from app import models  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.services.features import build_features_from_events  # noqa: E402
from training.export import (  # noqa: E402
    DEFAULT_ADAPTATION,
    labels_to_indices,
    train_and_export,
    vectorize_batch,
)

MODELS_DIR = ML_ROOT / "models"
DEFAULT_ARCHETYPES = ["explorer", "achiever", "socializer", "killer"]

# Веса для псевдо-разметки, если в БД нет prediction
EVENT_ARCHETYPE_WEIGHTS = {
    "enemy_killed": "killer",
    "damage_taken": "killer",
    "item_collected": "explorer",
    "checkpoint": "explorer",
    "level_complete": "achiever",
    "jump": "socializer",
}


def _event_dicts_from_rows(events: List[models.Event]) -> List[Dict[str, Any]]:
    result = []
    for row in events:
        payload = row.payload or {}
        result.append(
            {
                "event_name": row.event_type,
                "parameters": payload.get("parameters") or {},
            }
        )
    return result


def _profile_for_session(db, session: models.Session) -> Optional[models.GameModel]:
    if session.model_id:
        return db.query(models.GameModel).filter(models.GameModel.model_id == session.model_id).first()
    return db.query(models.GameModel).order_by(models.GameModel.created_at.desc()).first()


def _bootstrap_actions(profile: models.GameModel) -> int:
    schema = profile.feature_schema or {}
    if isinstance(schema, dict):
        return int(schema.get("bootstrap_actions") or 10)
    return 10


def _infer_archetype_from_events(
    event_dicts: List[Dict[str, Any]],
    archetypes: List[str],
) -> str:
    scores: Counter[str] = Counter({a: 0.0 for a in archetypes})
    for event in event_dicts:
        mapped = EVENT_ARCHETYPE_WEIGHTS.get(event.get("event_name", ""))
        if mapped in scores:
            scores[mapped] += 1.0
        params = event.get("parameters") or {}
        for key, value in params.items():
            if isinstance(value, (int, float)):
                if key in ("deaths", "damage") and "killer" in scores:
                    scores["killer"] += float(value) * 0.1
                if key in ("score", "value") and "achiever" in scores:
                    scores["achiever"] += float(value) * 0.01
    if not scores or max(scores.values()) <= 0:
        return archetypes[0]
    return scores.most_common(1)[0][0]


def _label_for_session(
    db,
    session_id,
    event_dicts: List[Dict[str, Any]],
    archetypes: List[str],
) -> Tuple[str, str]:
    pred = (
        db.query(models.Prediction)
        .filter(models.Prediction.session_id == session_id)
        .order_by(models.Prediction.created_at.desc())
        .first()
    )
    if pred and pred.predicted_archetype and pred.predicted_archetype in archetypes:
        return pred.predicted_archetype, "prediction"
    return _infer_archetype_from_events(event_dicts, archetypes), "inferred"


def _collect_feature_order(
    feature_dicts: List[Dict[str, float]],
    profile: models.GameModel,
) -> List[str]:
    schema = profile.feature_schema or {}
    order: List[str] = []
    if isinstance(schema, dict) and schema.get("order"):
        order = list(schema["order"])
    seen = set(order)
    for features in feature_dicts:
        for key in sorted(features.keys()):
            if key not in seen:
                order.append(key)
                seen.add(key)
    if "event_count_first_n" not in seen:
        order.insert(0, "event_count_first_n")
    return order


def load_dataset(
    limit_sessions: Optional[int] = None,
    min_events: int = 10,
) -> Tuple[List[Dict[str, float]], List[str], List[str], models.GameModel]:
    db = SessionLocal()
    try:
        profile = db.query(models.GameModel).order_by(models.GameModel.created_at.desc()).first()
        if not profile:
            raise RuntimeError("No game_models row — run seed or PUT /game/profile first")

        archetypes: List[str] = list(profile.archetypes or DEFAULT_ARCHETYPES)
        if not archetypes:
            archetypes = DEFAULT_ARCHETYPES

        bootstrap = _bootstrap_actions(profile)
        min_required = max(min_events, bootstrap)

        q = db.query(models.Session).order_by(models.Session.started_at.desc())
        if limit_sessions:
            q = q.limit(limit_sessions)
        sessions = q.all()

        feature_dicts: List[Dict[str, float]] = []
        labels: List[str] = []
        label_sources: Counter[str] = Counter()

        for session in sessions:
            events = (
                db.query(models.Event)
                .filter(models.Event.session_id == session.session_id)
                .order_by(models.Event.created_at.asc())
                .all()
            )
            if len(events) < min_required:
                continue

            event_dicts = _event_dicts_from_rows(events)
            prof = _profile_for_session(db, session) or profile
            critical_points = prof.critical_points or []
            features = build_features_from_events(
                event_dicts,
                critical_points,
                bootstrap,
            )
            label, source = _label_for_session(db, session.session_id, event_dicts, archetypes)
            feature_dicts.append(features)
            labels.append(label)
            label_sources[source] += 1

        if not feature_dicts:
            raise RuntimeError(
                f"No sessions with >={min_required} events. Run: .\\scripts\\seed.ps1"
            )

        feature_order = _collect_feature_order(feature_dicts, profile)
        print(f"Sessions used: {len(feature_dicts)}")
        print(f"Label sources: {dict(label_sources)}")
        print(f"Feature order ({len(feature_order)}): {feature_order[:12]}...")
        return feature_dicts, labels, archetypes, profile
    finally:
        db.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Train ONNX model from PostgreSQL")
    parser.add_argument("--limit-sessions", type=int, default=None)
    parser.add_argument("--min-events", type=int, default=10)
    parser.add_argument(
        "--model-version",
        type=str,
        default="sklearn-rf-pg-1.0",
    )
    parser.add_argument("--models-dir", type=Path, default=MODELS_DIR)
    args = parser.parse_args()

    feature_dicts, labels, archetypes, _profile = load_dataset(
        limit_sessions=args.limit_sessions,
        min_events=args.min_events,
    )

    # Только классы, встречающиеся в данных
    present = sorted(set(labels))
    archetypes = [a for a in archetypes if a in present] + [a for a in present if a not in archetypes]

    feature_order = _collect_feature_order(feature_dicts, _profile)
    X = vectorize_batch(feature_dicts, feature_order)
    y = labels_to_indices(labels, archetypes)

    adaptation = {a: dict(DEFAULT_ADAPTATION.get(a, {})) for a in archetypes}

    train_and_export(
        X,
        y,
        feature_order,
        archetypes,
        args.models_dir,
        args.model_version,
        adaptation_by_archetype=adaptation,
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)

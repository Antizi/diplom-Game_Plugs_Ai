"""
ML-service: инференс + обучение на данных из Postgres.
Телеметрия и профили — в backend (Postgres).
"""
import os
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional

import psycopg2
import psycopg2.extras
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from predictor import MODELS_DIR, get_engine

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

DEFAULT_ARCHETYPES = ["explorer", "achiever", "socializer", "killer"]

EVENT_ARCHETYPE_WEIGHTS = {
    "enemy_killed": "killer",
    "damage_taken": "killer",
    "item_collected": "explorer",
    "checkpoint": "explorer",
    "level_complete": "achiever",
    "jump": "socializer",
}

app = FastAPI(title="ML Predict Service", version="0.4.0")


class PredictIn(BaseModel):
    session_id: str
    player_id: str
    features: Dict[str, float] = Field(default_factory=dict)
    model_version: Optional[str] = None
    archetypes: Optional[List[str]] = None


class PredictOut(BaseModel):
    predicted_archetype: str
    confidence: float
    recommended_adaptation: Dict[str, Any]
    model_version: str


class TrainOut(BaseModel):
    status: str
    samples: int
    train_accuracy: float
    test_accuracy: float
    model_version: str


@app.on_event("startup")
def _startup() -> None:
    engine = get_engine()
    if engine.model_loaded:
        print(f"ONNX model loaded: {engine.model_version}")
    else:
        print("ONNX not found — using heuristic fallback")


@app.get("/health")
def health() -> Dict[str, Any]:
    engine = get_engine()
    return {
        "status": "ok",
        "service": "ml-predict",
        "model_loaded": engine.model_loaded,
        "model_version": engine.model_version,
    }


@app.post("/predict", response_model=PredictOut)
def predict(payload: PredictIn) -> PredictOut:
    engine = get_engine()
    predicted, confidence, adaptation, version = engine.predict(
        payload.features,
        payload.archetypes,
    )
    return PredictOut(
        predicted_archetype=predicted,
        confidence=confidence,
        recommended_adaptation=adaptation,
        model_version=version,
    )


# ---------------------------------------------------------------------------
# Обучение модели на данных из Postgres
# ---------------------------------------------------------------------------

def _build_features(
    events: List[Dict[str, Any]],
    critical_points: List[Dict[str, Any]],
    bootstrap: int,
) -> Dict[str, float]:
    cp_weights = {cp["name"]: float(cp.get("weight", 1.0)) for cp in critical_points}
    metrics: Dict[str, float] = defaultdict(float)
    limited = events[:bootstrap]
    metrics["event_count_first_n"] = float(len(limited))
    for event in limited:
        metrics[f"event::{event['event_name']}"] += 1.0
        for key, value in (event.get("parameters") or {}).items():
            if isinstance(value, (int, float)):
                metrics[key] += float(value)
    for key in list(metrics.keys()):
        if key in cp_weights:
            metrics[key] *= cp_weights[key]
    return dict(metrics)


def _infer_archetype(events: List[Dict[str, Any]], archetypes: List[str]) -> str:
    scores: Counter = Counter({a: 0 for a in archetypes})
    for event in events:
        mapped = EVENT_ARCHETYPE_WEIGHTS.get(event.get("event_name", ""))
        if mapped in scores:
            scores[mapped] += 1
        for key, value in (event.get("parameters") or {}).items():
            if isinstance(value, (int, float)):
                if key in ("deaths", "damage") and "killer" in scores:
                    scores["killer"] += float(value) * 0.1
                if key in ("score", "value") and "achiever" in scores:
                    scores["achiever"] += float(value) * 0.01
    if not scores or max(scores.values()) <= 0:
        return archetypes[0]
    return scores.most_common(1)[0][0]


@app.post("/train", response_model=TrainOut, summary="Обучить модель на данных из Postgres")
def train_model() -> TrainOut:
    if not DATABASE_URL:
        raise HTTPException(status_code=503, detail="DATABASE_URL не задан в конфиге ML-сервиса")

    try:
        conn = psycopg2.connect(DATABASE_URL)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Не удалось подключиться к БД: {exc}")

    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT * FROM game_models ORDER BY created_at DESC LIMIT 1")
            profile = cur.fetchone()
            if not profile:
                raise HTTPException(
                    status_code=404,
                    detail="Профиль игры не найден. Сначала выполните PUT /game/profile.",
                )

            archetypes: List[str] = list(profile["archetypes"] or DEFAULT_ARCHETYPES) or DEFAULT_ARCHETYPES
            critical_points: List[Dict] = list(profile["critical_points"] or [])
            feature_schema = profile["feature_schema"] or {}
            bootstrap = int(feature_schema.get("bootstrap_actions") or 10)

            cur.execute("SELECT session_id FROM sessions ORDER BY started_at DESC")
            sessions = cur.fetchall()

            feature_dicts: List[Dict[str, float]] = []
            labels: List[str] = []

            for session_row in sessions:
                sid = str(session_row["session_id"])

                cur.execute(
                    "SELECT event_type, payload FROM events "
                    "WHERE session_id = %s ORDER BY created_at ASC",
                    (sid,),
                )
                event_rows = cur.fetchall()
                if len(event_rows) < bootstrap:
                    continue

                event_dicts = [
                    {
                        "event_name": row["event_type"],
                        "parameters": (row["payload"] or {}).get("parameters") or {},
                    }
                    for row in event_rows
                ]

                features = _build_features(event_dicts, critical_points, bootstrap)

                cur.execute(
                    "SELECT predicted_archetype FROM predictions "
                    "WHERE session_id = %s AND predicted_archetype IS NOT NULL "
                    "ORDER BY created_at DESC LIMIT 1",
                    (sid,),
                )
                pred_row = cur.fetchone()

                if pred_row and pred_row["predicted_archetype"] in archetypes:
                    label = pred_row["predicted_archetype"]
                else:
                    label = _infer_archetype(event_dicts, archetypes)

                feature_dicts.append(features)
                labels.append(label)
    finally:
        conn.close()

    if len(feature_dicts) < 10:
        raise HTTPException(
            status_code=422,
            detail=(
                f"Недостаточно данных: {len(feature_dicts)} сессий (нужно ≥10). "
                "Соберите больше телеметрии или запустите seed-скрипт."
            ),
        )

    from training.export import DEFAULT_ADAPTATION, labels_to_indices, train_and_export, vectorize_batch

    present = sorted(set(labels))
    archetypes = [a for a in archetypes if a in present] + [a for a in present if a not in archetypes]

    seen: set = set()
    feature_order: List[str] = []
    for fd in feature_dicts:
        for k in sorted(fd.keys()):
            if k not in seen:
                feature_order.append(k)
                seen.add(k)
    if "event_count_first_n" not in seen:
        feature_order.insert(0, "event_count_first_n")

    X = vectorize_batch(feature_dicts, feature_order)
    y = labels_to_indices(labels, archetypes)

    adaptation = {
        a: dict(DEFAULT_ADAPTATION.get(a, {"difficulty": 1.0, "enemy_density": 1.0, "loot_multiplier": 1.0}))
        for a in archetypes
    }
    model_version = f"sklearn-rf-db-{len(feature_dicts)}s"

    metrics = train_and_export(
        X, y, feature_order, archetypes,
        Path(MODELS_DIR),
        model_version,
        adaptation_by_archetype=adaptation,
    )

    # Перезагружаем движок, чтобы /predict сразу использовал новую модель
    import predictor as _predictor_module
    _predictor_module._engine = None
    _predictor_module.get_engine()

    return TrainOut(
        status="ok",
        samples=len(feature_dicts),
        train_accuracy=round(metrics["train_accuracy"], 4),
        test_accuracy=round(metrics["test_accuracy"], 4),
        model_version=model_version,
    )

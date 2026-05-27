from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import UUID

from sqlalchemy.orm import Session

from gamedb_backend import models, schemas
from gamedb_backend.config import BOOTSTRAP_ACTIONS_DEFAULT
from gamedb_backend.services.features import build_features_from_events
from gamedb_backend.services.ml_client import MLServiceError, call_predict


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _feature_schema_config(model: models.GameModel) -> Dict[str, Any]:
    schema = model.feature_schema or {}
    if isinstance(schema, dict):
        return schema
    return {}


def get_or_create_model(db: Session) -> models.GameModel:
    model = (
        db.query(models.GameModel)
        .order_by(models.GameModel.created_at.desc())
        .first()
    )
    if model:
        return model
    model = models.GameModel(
        model_version="default",
        feature_schema={"order": [], "bootstrap_actions": BOOTSTRAP_ACTIONS_DEFAULT},
    )
    db.add(model)
    db.flush()
    return model


def resolve_profile_context(
    db: Session,
    metadata: schemas.TelemetryMetadataIn,
) -> Dict[str, Any]:
    model = get_or_create_model(db)
    fs = _feature_schema_config(model)
    critical_points = metadata.critical_points or model.critical_points or []
    archetypes = metadata.archetypes or model.archetypes or []
    bootstrap = int(fs.get("bootstrap_actions") or BOOTSTRAP_ACTIONS_DEFAULT)
    feature_order = fs.get("order") or []

    return {
        "model_id": model.model_id,
        "model_version": model.model_version,
        "game_profile_version": model.game_profile_version,
        "feature_schema_version": model.feature_schema_version,
        "critical_points": critical_points,
        "archetypes": archetypes,
        "feature_order": feature_order,
        "bootstrap_actions": bootstrap,
    }


def save_telemetry_events(
    db: Session,
    events: List[schemas.TelemetryEventIn],
) -> int:
    for event in events:
        db.add(
            models.Event(
                session_id=event.session_id,
                event_type=event.event_name,
                payload={
                    "parameters": event.parameters,
                    "state": event.state,
                    "game_time": event.game_time,
                    "client_timestamp": event.timestamp,
                },
                created_at=_utcnow(),
            )
        )
    return len(events)


def count_session_events(db: Session, session_id: UUID) -> int:
    return (
        db.query(models.Event)
        .filter(models.Event.session_id == session_id)
        .count()
    )


def get_recent_session_events(
    db: Session,
    session_id: UUID,
    limit: int,
) -> List[Dict[str, Any]]:
    rows = (
        db.query(models.Event)
        .filter(models.Event.session_id == session_id)
        .order_by(models.Event.created_at.desc())
        .limit(limit)
        .all()
    )
    result = []
    for row in reversed(rows):
        data = row.payload or {}
        result.append(
            {
                "event_name": row.event_type,
                "parameters": data.get("parameters") or {},
            }
        )
    return result


def should_trigger_prediction(
    total_events: int,
    bootstrap_actions: int,
    already_predicted: bool,
) -> bool:
    return not already_predicted and total_events >= bootstrap_actions


def process_ingest(
    db: Session,
    payload: schemas.TelemetryIngestIn,
) -> schemas.TelemetryIngestOut:
    if not payload.events:
        raise ValueError("events is empty")

    ctx = resolve_profile_context(db, payload.metadata)
    first = payload.events[0]
    session_id = first.session_id
    player_id = first.player_id

    session = (
        db.query(models.Session)
        .filter(models.Session.session_id == session_id)
        .first()
    )
    if not session:
        raise LookupError("session not found")

    session.model_id = ctx["model_id"]

    save_telemetry_events(db, payload.events)
    db.flush()

    total_events = count_session_events(db, session_id)
    existing_prediction = (
        db.query(models.Prediction)
        .filter(
            models.Prediction.session_id == session_id,
            models.Prediction.predicted_archetype.isnot(None),
        )
        .order_by(models.Prediction.created_at.desc())
        .first()
    )

    prediction_out: Optional[schemas.PredictionOut] = None
    adaptation_out: Optional[schemas.AdaptationOut] = None

    if should_trigger_prediction(
        total_events,
        ctx["bootstrap_actions"],
        existing_prediction is not None,
    ):
        event_dicts = get_recent_session_events(
            db, session_id, ctx["bootstrap_actions"]
        )
        features = build_features_from_events(
            event_dicts,
            ctx["critical_points"],
            ctx["bootstrap_actions"],
        )

        try:
            ml_result = call_predict(
                session_id=str(session_id),
                player_id=player_id,
                features=features,
                archetypes=ctx["archetypes"],
            )
        except MLServiceError:
            from gamedb_backend.services.ml_client import _fallback_predict

            ml_result = _fallback_predict(features, archetypes=ctx["archetypes"])

        predicted = ml_result.get("predicted_archetype", "unknown")
        confidence = float(ml_result.get("confidence", 0.0))
        recommended = ml_result.get("recommended_adaptation") or {}

        prediction_row = models.Prediction(
            session_id=session_id,
            player_id=player_id,
            model_id=ctx["model_id"],
            predicted_archetype=predicted,
            confidence=confidence,
            result={
                "features": features,
                "recommended_adaptation": recommended,
                "raw": ml_result,
            },
        )
        db.add(prediction_row)

        prediction_out = schemas.PredictionOut(
            predicted_archetype=predicted,
            confidence=confidence,
            model_id=ctx["model_id"],
        )
        adaptation_out = schemas.AdaptationOut(
            parameters=recommended,
            predicted_archetype=predicted,
            confidence=confidence,
            model_id=ctx["model_id"],
            source=payload.metadata.model_mode or "prediction",
        )

    db.commit()

    return schemas.TelemetryIngestOut(
        events_received=len(payload.events),
        prediction=prediction_out,
        adaptation=adaptation_out,
    )

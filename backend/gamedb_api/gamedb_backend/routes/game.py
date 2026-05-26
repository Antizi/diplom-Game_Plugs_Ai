from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from gamedb_backend import models, schemas
from gamedb_backend.deps import get_db
from gamedb_backend.services.ingest import get_or_create_model

router = APIRouter(prefix="/game", tags=["game"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


@router.post(
    "/session/start",
    response_model=schemas.Session,
    summary="Начать новую игровую сессию",
)
def start_session(
    player_id: str,
    game_version: Optional[str] = None,
    db: Session = Depends(get_db),
):
    player = db.query(models.Player).filter(models.Player.player_id == player_id).first()
    if not player:
        player = models.Player(player_id=player_id)
        db.add(player)
        db.commit()
        db.refresh(player)

    model = get_or_create_model(db)
    model_id = model.model_id

    new_session = models.Session(
        player_id=player_id,
        game_version=game_version,
        model_id=model_id,
        started_at=_utcnow(),
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    return new_session


@router.patch(
    "/session/{session_id}/end",
    response_model=schemas.Session,
    summary="Завершить игровую сессию",
)
def end_session(session_id: UUID, db: Session = Depends(get_db)):
    session = db.query(models.Session).filter(models.Session.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Сессия не найдена")

    if session.ended_at is None:
        session.ended_at = _utcnow()
        db.commit()
        db.refresh(session)
    return session


@router.get(
    "/adaptation/{session_id}",
    response_model=schemas.AdaptationOut,
    summary="Получить параметры адаптации для сессии",
)
def get_adaptation(session_id: UUID, db: Session = Depends(get_db)):
    prediction = (
        db.query(models.Prediction)
        .filter(models.Prediction.session_id == session_id)
        .order_by(models.Prediction.created_at.desc())
        .first()
    )
    if not prediction:
        raise HTTPException(status_code=404, detail="Параметры адаптации для этой сессии не найдены")
    result = prediction.result or {}
    return schemas.AdaptationOut(
        parameters=result.get("recommended_adaptation") or {},
        predicted_archetype=prediction.predicted_archetype,
        confidence=float(prediction.confidence) if prediction.confidence is not None else None,
        model_id=prediction.model_id,
    )

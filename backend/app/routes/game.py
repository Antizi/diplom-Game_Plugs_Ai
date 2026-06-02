import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app import models, schemas
from app.config import MODELS_DIR
from app.deps import get_db
from app.services.ingest import get_or_create_model

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
    new_session = models.Session(
        player_id=player_id,
        game_version=game_version,
        model_id=model.model_id,
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


@router.put(
    "/profile",
    response_model=schemas.GameProfileOut,
    summary="Создать или обновить профиль модели",
)
def upsert_game_profile(
    payload: schemas.GameProfileUpsertIn,
    db: Session = Depends(get_db),
):
    profile = (
        db.query(models.GameModel)
        .filter(models.GameModel.model_version == payload.model_version)
        .first()
    )
    critical_points = [cp.model_dump() for cp in payload.critical_points]
    feature_schema = {
        "order": payload.feature_order,
        "bootstrap_actions": payload.bootstrap_actions,
    }

    if profile:
        profile.game_profile_version = (
            payload.game_profile_version or profile.game_profile_version + 1
        )
        profile.critical_points = critical_points
        profile.archetypes = payload.archetypes
        profile.feature_schema_version = payload.feature_schema_version
        profile.feature_schema = feature_schema
    else:
        profile = models.GameModel(
            model_version=payload.model_version,
            game_profile_version=payload.game_profile_version or 1,
            critical_points=critical_points,
            archetypes=payload.archetypes,
            feature_schema_version=payload.feature_schema_version,
            feature_schema=feature_schema,
        )
        db.add(profile)

    db.commit()
    db.refresh(profile)
    return profile


@router.get(
    "/profile",
    response_model=schemas.GameProfileOut,
    summary="Получить актуальный профиль модели",
)
def get_game_profile(db: Session = Depends(get_db)):
    profile = (
        db.query(models.GameModel)
        .order_by(models.GameModel.created_at.desc())
        .first()
    )
    if not profile:
        raise HTTPException(status_code=404, detail="Game model/profile not found")
    return profile


@router.get(
    "/model/manifest",
    response_model=schemas.ModelManifestOut,
    summary="Манифест ONNX для офлайн-режима",
)
def get_model_manifest(db: Session = Depends(get_db)):
    row = (
        db.query(models.GameModel)
        .order_by(models.GameModel.created_at.desc())
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Model not registered for this game")
    onnx = row.onnx or {}
    return schemas.ModelManifestOut(
        model_version=row.model_version,
        game_profile_version=row.game_profile_version,
        feature_schema_version=row.feature_schema_version,
        format=onnx.get("format", "onnx"),
        sha256=onnx.get("sha256"),
        download_url=f"/game/model/download?version={row.model_version}",
        created_at=row.created_at,
    )


@router.get(
    "/model/download",
    summary="Скачать ONNX-модель",
)
def download_model(
    version: str,
    db: Session = Depends(get_db),
):
    row = (
        db.query(models.GameModel)
        .filter(models.GameModel.model_version == version)
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Model version not found")

    onnx = row.onnx or {}
    storage_path = onnx.get("storage_path")
    if storage_path:
        path = Path(storage_path)
    else:
        path = MODELS_DIR / version / "model.onnx"

    if not path.is_file():
        raise HTTPException(status_code=404, detail="Model file not found on server")

    return FileResponse(
        path,
        media_type="application/octet-stream",
        filename=f"{version}.onnx",
    )


def register_model_file(
    db: Session,
    model_version: str,
    file_path: Path,
    feature_schema_version: int = 1,
) -> models.GameModel:
    """Регистрация ONNX-файла (используется скриптами обучения)."""
    sha = hashlib.sha256(file_path.read_bytes()).hexdigest()
    row = models.GameModel(
        model_version=model_version,
        feature_schema_version=feature_schema_version,
        onnx={
            "format": "onnx",
            "sha256": sha,
            "storage_path": str(file_path),
        },
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row

from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.config import ML_SERVICE_URL
from app.deps import get_db
from app.services.ingest import get_or_create_model

router = APIRouter(prefix="/game", tags=["game"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


@router.post(
    "/session/start",
    response_model=schemas.Session,
    summary="Начать новую игровую сессию",
    description=(
        "Создаёт запись игрока (если не существует) и открывает новую сессию. "
        "Вызывается плагином при `Analytics.start_new_game()`. "
        "Возвращает `session_id` (UUID), который нужно передавать во все последующие запросы."
    ),
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
    description=(
        "Проставляет `ended_at` для сессии. Идемпотентен: повторный вызов возвращает "
        "уже закрытую сессию без изменений. Вызывается плагином при `Analytics.end_game()`."
    ),
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
    description=(
        "Возвращает последнее ML-предсказание для сессии в виде параметров адаптации "
        "(`difficulty`, `enemy_density`, `loot_multiplier`). "
        "Адаптация появляется после того, как число событий в сессии достигает `bootstrap_actions`. "
        "404 — если предсказаний ещё нет."
    ),
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
    description=(
        "Сохраняет ML-профиль игры: список событий (`feature_order`), критические метрики "
        "(`critical_points` с весами), архетипы игроков и `bootstrap_actions`. "
        "Вызывается из панели редактора Godot при нажатии «Синхронизировать профиль». "
        "Upsert по `model_version`: если профиль с таким именем уже есть — обновляется "
        "и становится активным для последующих ingest-запросов."
    ),
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
        # Делаем обновлённый профиль «активным»: get_or_create_model берёт latest по created_at
        profile.created_at = _utcnow()
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
    description=(
        "Возвращает последний активный профиль (по времени обновления): "
        "архетипы, критические точки, feature_order и bootstrap_actions. "
        "Используется для отладки и в панели редактора Godot."
    ),
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


@router.post(
    "/train",
    response_model=schemas.TrainOut,
    summary="Запустить обучение ML-модели на данных из Postgres",
    description=(
        "Проксирует запрос в ML-сервис (`POST /train`), который читает сессии и события "
        "из Postgres, строит датасет, обучает RandomForest, экспортирует ONNX-модель "
        "и перезагружает её без рестарта контейнера. "
        "Требует ≥ 10 сессий с достаточным числом событий в БД. "
        "Вызывается из панели редактора Godot кнопкой «Обучить модель» или вручную."
    ),
)
def trigger_training():
    if not ML_SERVICE_URL:
        raise HTTPException(status_code=503, detail="ML_SERVICE_URL не задан")
    try:
        with httpx.Client(timeout=300.0) as client:
            resp = client.post(f"{ML_SERVICE_URL.rstrip('/')}/train")
            resp.raise_for_status()
            return resp.json()
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text[:300] if exc.response else str(exc)
        raise HTTPException(status_code=502, detail=f"ML ошибка: {detail}")
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"ML недоступен: {exc}")

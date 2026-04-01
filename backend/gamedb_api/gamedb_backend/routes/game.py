from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from uuid import UUID, uuid4

from gamedb_backend import schemas, models
from gamedb_backend.database import SessionLocal

router = APIRouter(prefix="/game", tags=["game"])

# Зависимость для получения сессии БД
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ==================== Сессии ====================

@router.post(
    "/session/start",
    response_model=schemas.Session,
    summary="Начать новую игровую сессию",
    description="Создаёт новую сессию для указанного игрока. Возвращает session_id."
)
def start_session(
    player_id: str,
    game_version: Optional[str] = None,
    db: Session = Depends(get_db)
):
    # Проверяем, существует ли игрок, если нет – создаём (опционально)
    player = db.query(models.Player).filter(models.Player.player_id == player_id).first()
    if not player:
        # Автоматически регистрируем нового игрока
        player = models.Player(player_id=player_id)
        db.add(player)
        db.commit()
        db.refresh(player)

    # Создаём новую сессию
    new_session = models.Session(
        player_id=player_id,
        game_version=game_version,
        started_at=datetime.utcnow()
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    return new_session


@router.patch(
    "/session/{session_id}/end",
    response_model=schemas.Session,
    summary="Завершить игровую сессию",
    description="Устанавливает время окончания сессии, если она ещё не завершена. Если сессия уже завершена, просто возвращает её текущее состояние."
)
def end_session(
        session_id: UUID,
        db: Session = Depends(get_db)
):
    session = db.query(models.Session).filter(models.Session.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Сессия не найдена")

    # Устанавливаем время окончания только если сессия ещё не завершена
    if session.ended_at is None:
        session.ended_at = datetime.utcnow()
        db.commit()
        db.refresh(session)

    # Возвращаем сессию (в любом случае)
    return session


# ==================== События ====================

@router.post(
    "/events",
    response_model=List[schemas.Event],
    summary="Отправить пачку событий",
    description="Принимает массив событий и сохраняет их в БД. Все события должны принадлежать одной сессии."
)
def create_events(
    events: List[schemas.EventCreate],
    db: Session = Depends(get_db)
):
    if not events:
        raise HTTPException(status_code=400, detail="Список событий пуст")

    # Проверяем, что все события относятся к одной сессии (опционально)
    session_id = events[0].session_id
    for ev in events:
        if ev.session_id != session_id:
            raise HTTPException(status_code=400, detail="Все события должны быть из одной сессии")

    # Проверяем, что сессия существует
    session = db.query(models.Session).filter(models.Session.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Сессия не найдена")

    # Создаём объекты событий
    db_events = []
    for ev in events:
        db_event = models.Event(
            session_id=ev.session_id,
            event_type=ev.event_type,
            event_data=ev.event_data,
            created_at=ev.created_at or datetime.utcnow()
        )
        db.add(db_event)
        db_events.append(db_event)
    db.commit()
    # Обновляем объекты, чтобы получить event_id
    for db_event in db_events:
        db.refresh(db_event)
    return db_events


# ==================== Адаптация ====================

@router.get(
    "/adaptation/{session_id}",
    response_model=schemas.AdaptationState,
    summary="Получить параметры адаптации для сессии",
    description="Возвращает текущие параметры адаптации, связанные с сессией (из таблицы adaptation_state)."
)
def get_adaptation(
    session_id: UUID,
    db: Session = Depends(get_db)
):
    adaptation = db.query(models.AdaptationState).filter(
        models.AdaptationState.session_id == session_id
    ).first()
    if not adaptation:
        # Если параметров нет, можно вернуть пустой объект или 404
        # Возвращаем 404, чтобы клиент понимал, что параметры ещё не заданы
        raise HTTPException(status_code=404, detail="Параметры адаптации для этой сессии не найдены")
    return adaptation


print("✅ game.py: зарегистрированные пути:", [route.path for route in router.routes])
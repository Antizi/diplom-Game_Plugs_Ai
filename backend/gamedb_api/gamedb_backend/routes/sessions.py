from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID

from gamedb_backend import schemas, models
from gamedb_backend.database import SessionLocal

router = APIRouter(prefix="/sessions", tags=["sessions"])


# Зависимость для получения сессии БД
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get(
    "/",
    response_model=List[schemas.Session],
    summary="Список игровых сессий",
    description="""
    Возвращает список всех игровых сессий с возможностью пагинации.

    Параметры:
    - **skip** – количество пропускаемых записей (для постраничного вывода)
    - **limit** – максимальное количество записей в ответе

    Каждая сессия содержит информацию об игроке, времени начала и конца,
    версии игры.
    """,
)
def read_sessions(
        skip: int = Query(0, ge=0, description="Сколько записей пропустить"),
        limit: int = Query(100, ge=1, le=1000, description="Максимальное количество записей"),
        db: Session = Depends(get_db)
):
    sessions = db.query(models.Session).offset(skip).limit(limit).all()
    return sessions


@router.get(
    "/{session_id}",
    response_model=schemas.Session,
    summary="Детали конкретной сессии",
    description="Возвращает полную информацию об одной сессии по её UUID.",
    responses={
        404: {"description": "Сессия не найдена"}
    }
)
def read_session(
        session_id: UUID,
        db: Session = Depends(get_db)
):
    session = db.query(models.Session).filter(models.Session.session_id == session_id).first()
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return session
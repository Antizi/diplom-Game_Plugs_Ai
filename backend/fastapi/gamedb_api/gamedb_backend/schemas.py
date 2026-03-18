from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID
from typing import Optional, Dict, Any

# Player schemas
class PlayerBase(BaseModel):
    player_id: str = Field(..., description="Уникальный идентификатор игрока", example="player_123")

class PlayerCreate(PlayerBase):
    pass

class Player(PlayerBase):
    created_at: datetime = Field(..., description="Дата и время создания профиля")
    last_session_id: Optional[UUID] = Field(None, description="ID последней сессии игрока")
    total_playtime: Optional[float] = Field(None, description="Общее время игры в секундах")

    class Config:
        from_attributes = True


# Session schemas
class SessionBase(BaseModel):
    player_id: str = Field(..., description="ID игрока, которому принадлежит сессия", example="player_123")
    game_version: Optional[str] = Field(None, description="Версия игры", example="1.0.0")

class SessionCreate(SessionBase):
    pass

class Session(SessionBase):
    session_id: UUID = Field(..., description="Уникальный UUID сессии")
    started_at: datetime = Field(..., description="Время начала сессии")
    ended_at: Optional[datetime] = Field(None, description="Время окончания сессии (если сессия завершена)")

    class Config:
        from_attributes = True


# Event schemas
class EventBase(BaseModel):
    session_id: UUID = Field(..., description="ID сессии, в которой произошло событие")
    event_type: str = Field(..., description="Тип события", example="enemy_killed")
    event_data: Optional[Dict[str, Any]] = Field(None, description="Дополнительные данные события в формате JSON", example={"enemy": "goblin", "position": {"x": 10, "y": 20}})

class EventCreate(EventBase):
    pass

class Event(EventBase):
    event_id: int = Field(..., description="Уникальный идентификатор события")
    created_at: datetime = Field(..., description="Время события")

    class Config:
        from_attributes = True
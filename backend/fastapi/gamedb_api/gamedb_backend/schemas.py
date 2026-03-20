from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID
from typing import Optional, Dict, Any, List

# ---------- Player ----------
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


# ---------- Session ----------
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


# ---------- Event ----------
class EventBase(BaseModel):
    session_id: UUID = Field(..., description="ID сессии, в которой произошло событие")
    event_type: str = Field(..., description="Тип события", example="enemy_killed")
    event_data: Optional[Dict[str, Any]] = Field(None, description="Дополнительные данные события в формате JSON", example={"enemy": "goblin", "position": {"x": 10, "y": 20}})
    created_at: Optional[datetime] = Field(None, description="Время события (если не указано, будет проставлено сервером)")

class EventCreate(EventBase):
    pass

class Event(EventBase):
    event_id: int = Field(..., description="Уникальный идентификатор события")
    created_at: datetime = Field(..., description="Время события")

    class Config:
        from_attributes = True


# ---------- Session Features ----------
class SessionFeatureBase(BaseModel):
    session_id: UUID
    feature_name: str
    feature_value: float

class SessionFeatureCreate(SessionFeatureBase):
    pass

class SessionFeature(SessionFeatureBase):
    feature_id: int
    calculated_at: datetime

    class Config:
        from_attributes = True


# ---------- Predictions ----------
class PredictionBase(BaseModel):
    session_id: UUID
    player_id: str
    prediction_type: str
    prediction_value: Dict[str, Any]
    model_version: Optional[str] = None

class PredictionCreate(PredictionBase):
    pass

class Prediction(PredictionBase):
    prediction_id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ---------- Adaptation State ----------
class AdaptationStateBase(BaseModel):
    session_id: UUID
    player_id: str
    parameters: Dict[str, Any] = Field(..., description="Текущие параметры адаптации", example={"difficulty": 2, "enemy_density": 1.5})
    expires_at: Optional[datetime] = Field(None, description="Время истечения действия параметров")

class AdaptationStateCreate(AdaptationStateBase):
    pass

class AdaptationState(AdaptationStateBase):
    adaptation_id: int
    updated_at: datetime

    class Config:
        from_attributes = True


# ---------- Adaptation History ----------
class AdaptationHistoryBase(BaseModel):
    session_id: UUID
    player_id: str
    parameters: Dict[str, Any]

class AdaptationHistoryCreate(AdaptationHistoryBase):
    pass

class AdaptationHistory(AdaptationHistoryBase):
    history_id: int
    applied_at: datetime

    class Config:
        from_attributes = True


# ---------- HTTP Validation Error (для документации) ----------
class ValidationErrorDetail(BaseModel):
    loc: List[str]
    msg: str
    type: str

class HTTPValidationError(BaseModel):
    detail: List[ValidationErrorDetail]


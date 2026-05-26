from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class APIModel(BaseModel):
    model_config = ConfigDict(protected_namespaces=())


# ---------- Session ----------
class SessionBase(APIModel):
    player_id: str
    game_version: Optional[str] = None
    model_id: Optional[int] = None


class Session(SessionBase):
    model_config = ConfigDict(from_attributes=True, protected_namespaces=())

    session_id: UUID
    started_at: datetime
    ended_at: Optional[datetime] = None


# ---------- Telemetry ----------
class TelemetryEventIn(APIModel):
    session_id: UUID
    player_id: str
    event_name: str
    timestamp: float
    game_time: Optional[float] = 0.0
    parameters: Dict[str, Any] = Field(default_factory=dict)
    state: Dict[str, Any] = Field(default_factory=dict)


class TelemetryMetadataIn(APIModel):
    critical_points: Optional[List[Dict[str, Any]]] = None
    archetypes: Optional[List[str]] = None
    model_mode: Optional[str] = Field(None, description="cloud | local")
    feature_schema_version: Optional[int] = None


class TelemetryIngestIn(APIModel):
    events: List[TelemetryEventIn]
    metadata: TelemetryMetadataIn = Field(default_factory=TelemetryMetadataIn)


class PredictionOut(APIModel):
    predicted_archetype: str
    confidence: float
    model_id: Optional[int] = None


class AdaptationOut(APIModel):
    parameters: Dict[str, Any]
    predicted_archetype: Optional[str] = None
    confidence: Optional[float] = None
    model_id: Optional[int] = None
    source: str = "prediction"


class TelemetryIngestOut(APIModel):
    events_received: int
    prediction: Optional[PredictionOut] = None
    adaptation: Optional[AdaptationOut] = None


# ---------- Game model (профиль + версии) ----------
class CriticalPointIn(APIModel):
    name: str
    weight: float = Field(default=1.0, ge=0.0)


class GameProfileUpsertIn(APIModel):
    model_version: str = "default"
    game_profile_version: Optional[int] = None
    feature_order: List[str] = Field(default_factory=list)
    critical_points: List[CriticalPointIn] = Field(default_factory=list)
    archetypes: List[str] = Field(default_factory=list)
    feature_schema_version: int = 1
    bootstrap_actions: int = Field(default=10, ge=1, le=1000)


class GameProfileOut(APIModel):
    model_config = ConfigDict(from_attributes=True, protected_namespaces=())

    model_id: int
    model_version: str
    game_profile_version: int
    feature_schema_version: int
    critical_points: List[Any]
    archetypes: List[Any]
    feature_schema: Dict[str, Any] = Field(default_factory=dict)


class ModelManifestOut(APIModel):
    model_version: str
    game_profile_version: int
    feature_schema_version: int
    format: str = "onnx"
    sha256: Optional[str] = None
    download_url: str
    created_at: datetime


# ---------- Predictions ----------
class PredictionRecordOut(APIModel):
    model_config = ConfigDict(from_attributes=True, protected_namespaces=())

    prediction_id: int
    session_id: UUID
    player_id: str
    model_id: Optional[int] = None
    predicted_archetype: Optional[str] = None
    confidence: Optional[float] = None
    result: Optional[Dict[str, Any]] = None
    created_at: datetime



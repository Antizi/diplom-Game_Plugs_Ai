import uuid

from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.sql import func

from app.database import Base


class Player(Base):
    __tablename__ = "players"

    player_id = Column(String(255), primary_key=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class GameModel(Base):
    """Версии модели + профиль игры (архетипы, критические точки, схема признаков)."""

    __tablename__ = "game_models"

    model_id = Column(BigInteger, primary_key=True, autoincrement=True)
    model_version = Column(String(50), nullable=False)
    game_profile_version = Column(Integer, nullable=False, default=1)
    feature_schema_version = Column(Integer, nullable=False, default=1)
    critical_points = Column(JSONB, nullable=False, default=list)
    archetypes = Column(JSONB, nullable=False, default=list)
    # order признаков + bootstrap_actions для ingest
    feature_schema = Column(JSONB, nullable=False, default=dict)
    # опционально: ONNX для офлайн (path, sha256)
    onnx = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("model_version", name="uq_game_models_version"),
        Index("idx_game_models_created", "created_at"),
    )


class Session(Base):
    __tablename__ = "sessions"

    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    player_id = Column(String(255), ForeignKey("players.player_id"), nullable=False)
    model_id = Column(BigInteger, ForeignKey("game_models.model_id"), nullable=True)
    game_version = Column(String(50), nullable=True)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True), nullable=True)


class Event(Base):
    __tablename__ = "events"

    event_id = Column(BigInteger, primary_key=True, autoincrement=True)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.session_id", ondelete="CASCADE"))
    event_type = Column(String(100), nullable=False)
    payload = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_events_session_id", "session_id"),
        Index("idx_events_created_at", "created_at"),
    )


class Prediction(Base):
    __tablename__ = "predictions"

    prediction_id = Column(BigInteger, primary_key=True, autoincrement=True)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.session_id"), nullable=False)
    player_id = Column(String(255), ForeignKey("players.player_id"), nullable=False)
    model_id = Column(BigInteger, ForeignKey("game_models.model_id"), nullable=True)
    predicted_archetype = Column(String(100), nullable=True)
    confidence = Column(Numeric, nullable=True)
    # features + recommended_adaptation + raw ML ответ
    result = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

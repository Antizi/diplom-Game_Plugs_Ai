from sqlalchemy import Column, String, Integer, Float, DateTime, JSON, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from gamedb_backend.database import Base
import uuid

class Player(Base):
    __tablename__ = "players"

    player_id = Column(String(255), primary_key=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_session_id = Column(UUID(as_uuid=True), nullable=True)
    total_playtime = Column(Float)  # INTERVAL в Python можно представить как число (секунды) или использовать Interval, но для простоты оставим Float


class Session(Base):
    __tablename__ = "sessions"

    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    player_id = Column(String(255), ForeignKey("players.player_id"), nullable=False)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True), nullable=True)
    game_version = Column(String(50))

    # связь с игроком (опционально)
    # player = relationship("Player", back_populates="sessions")


class Event(Base):
    __tablename__ = "events"

    event_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.session_id"))
    event_type = Column(String(100), nullable=False)
    event_data = Column(JSON)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Индексы (уже созданы в БД, здесь для полноты)
    __table_args__ = (
        Index("idx_events_session_id", "session_id"),
        Index("idx_events_created_at", "created_at"),
    )
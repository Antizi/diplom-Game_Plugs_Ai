from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from gamedb_backend import models, schemas
from gamedb_backend.deps import get_db

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.get(
    "/{session_id}/prediction/latest",
    response_model=schemas.PredictionRecordOut,
    summary="Последнее предсказание для сессии",
)
def get_latest_prediction(session_id: UUID, db: Session = Depends(get_db)):
    prediction = (
        db.query(models.Prediction)
        .filter(models.Prediction.session_id == session_id)
        .order_by(models.Prediction.created_at.desc())
        .first()
    )
    if not prediction:
        raise HTTPException(status_code=404, detail="Prediction not found")
    return prediction

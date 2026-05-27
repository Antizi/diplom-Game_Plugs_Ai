from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from gamedb_backend import schemas
from gamedb_backend.deps import get_db
from gamedb_backend.services.ingest import process_ingest

router = APIRouter(prefix="/telemetry", tags=["telemetry"])


@router.post(
    "/ingest",
    response_model=schemas.TelemetryIngestOut,
    summary="Единый ingest телеметрии",
    description=(
        "Сохраняет события, при достижении bootstrap-порога считает признаки, "
        "вызывает ML-service и возвращает prediction/adaptation."
    ),
)
def ingest_telemetry(
    payload: schemas.TelemetryIngestIn,
    db: Session = Depends(get_db),
):
    try:
        return process_ingest(db, payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="ingest failed") from exc

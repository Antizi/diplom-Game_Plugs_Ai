"""
ML-service: только инференс. Телеметрия и профили — в backend (Postgres).
"""
from typing import Any, Dict, List, Optional

from fastapi import FastAPI
from pydantic import BaseModel, Field

from predictor import get_engine

app = FastAPI(title="ML Predict Service", version="0.3.0")


class PredictIn(BaseModel):
    session_id: str
    player_id: str
    features: Dict[str, float] = Field(default_factory=dict)
    model_version: Optional[str] = None
    archetypes: Optional[List[str]] = None


class PredictOut(BaseModel):
    predicted_archetype: str
    confidence: float
    recommended_adaptation: Dict[str, Any]
    model_version: str


@app.on_event("startup")
def _startup() -> None:
    engine = get_engine()
    if engine.model_loaded:
        print(f"ONNX model loaded: {engine.model_version}")
    else:
        print("ONNX not found — using heuristic fallback")


@app.get("/health")
def health() -> Dict[str, Any]:
    engine = get_engine()
    return {
        "status": "ok",
        "service": "ml-predict",
        "model_loaded": engine.model_loaded,
        "model_version": engine.model_version,
    }


@app.post("/predict", response_model=PredictOut)
def predict(payload: PredictIn) -> PredictOut:
    engine = get_engine()
    predicted, confidence, adaptation, version = engine.predict(
        payload.features,
        payload.archetypes,
    )
    return PredictOut(
        predicted_archetype=predicted,
        confidence=confidence,
        recommended_adaptation=adaptation,
        model_version=version,
    )

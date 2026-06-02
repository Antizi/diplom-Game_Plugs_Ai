"""
ML-service: только инференс. Телеметрия и профили — в backend (Postgres).
"""
from typing import Any, Dict, List, Optional

from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="ML Predict Service", version="0.2.0")

DEFAULT_ARCHETYPES = ["explorer", "achiever", "socializer", "killer"]


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


def _predict(features: Dict[str, float], archetypes: List[str]) -> PredictOut:
    score = abs(sum(features.values())) if features else 0.0
    if not archetypes:
        archetypes = DEFAULT_ARCHETYPES
    idx = int(score) % len(archetypes)
    return PredictOut(
        predicted_archetype=archetypes[idx],
        confidence=0.55 + min(0.35, score * 0.01),
        recommended_adaptation={
            "difficulty": 1 + (idx % 3),
            "enemy_density": 1.0 + idx * 0.2,
            "loot_multiplier": 1.0 + (idx % 2) * 0.15,
        },
        model_version="ml-heuristic-0.2",
    )


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok", "service": "ml-predict"}


@app.post("/predict", response_model=PredictOut)
def predict(payload: PredictIn) -> PredictOut:
    archetypes = payload.archetypes or DEFAULT_ARCHETYPES
    return _predict(payload.features, archetypes)

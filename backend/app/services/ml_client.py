from typing import Any, Dict, Optional

import httpx

from app.config import ML_PREDICT_ENABLED, ML_SERVICE_URL


class MLServiceError(Exception):
    pass


def call_predict(
    session_id: str,
    player_id: str,
    features: Dict[str, float],
    model_version: Optional[str] = None,
    archetypes: Optional[list] = None,
    timeout: float = 10.0,
) -> Dict[str, Any]:
    if not ML_PREDICT_ENABLED or not ML_SERVICE_URL:
        return _fallback_predict(features, archetypes=archetypes)

    payload = {
        "session_id": session_id,
        "player_id": player_id,
        "features": features,
        "model_version": model_version,
        "archetypes": archetypes,
    }
    try:
        with httpx.Client(timeout=timeout) as client:
            response = client.post(f"{ML_SERVICE_URL.rstrip('/')}/predict", json=payload)
            response.raise_for_status()
            return response.json()
    except httpx.HTTPError as exc:
        raise MLServiceError(str(exc)) from exc


def _fallback_predict(
    features: Dict[str, float],
    archetypes: Optional[list] = None,
) -> Dict[str, Any]:
    """Локальная эвристика, если ML-service недоступен."""
    score = abs(sum(features.values())) if features else 0.0
    archetypes = archetypes or ["explorer", "achiever", "socializer"]
    if not archetypes:
        archetypes = ["unknown"]
    idx = int(score) % len(archetypes)
    return {
        "predicted_archetype": archetypes[idx],
        "confidence": 0.5,
        "recommended_adaptation": {
            "difficulty": 1 + (idx % 3),
            "enemy_density": 1.0 + idx * 0.2,
        },
        "model_version": "heuristic-0.1",
    }

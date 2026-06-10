"""Загрузка ONNX-модели и инференс; fallback — эвристика."""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parent
MODELS_DIR = Path(os.getenv("MODELS_DIR", str(ROOT / "models")))
ONNX_PATH = Path(os.getenv("MODEL_ONNX_PATH", str(MODELS_DIR / "classifier.onnx")))
META_PATH = Path(os.getenv("MODEL_META_PATH", str(MODELS_DIR / "model_meta.json")))

DEFAULT_ARCHETYPES = ["explorer", "achiever", "socializer", "killer"]

DEFAULT_ADAPTATION = {
    "explorer": {"difficulty": 0.85, "enemy_density": 0.9, "loot_multiplier": 1.2},
    "achiever": {"difficulty": 1.2, "enemy_density": 1.1, "loot_multiplier": 1.0},
    "socializer": {"difficulty": 0.95, "enemy_density": 0.85, "loot_multiplier": 1.15},
    "killer": {"difficulty": 1.35, "enemy_density": 1.4, "loot_multiplier": 0.95},
}


class PredictorEngine:
    def __init__(self) -> None:
        self._session = None
        self._meta: Dict[str, Any] = {}
        self._load()

    @property
    def model_loaded(self) -> bool:
        return self._session is not None

    @property
    def model_version(self) -> str:
        if self._meta.get("model_version"):
            return str(self._meta["model_version"])
        return "ml-heuristic-0.2"

    def _load(self) -> None:
        if not ONNX_PATH.is_file() or not META_PATH.is_file():
            return
        try:
            import onnxruntime as ort
        except ImportError:
            return

        self._meta = json.loads(META_PATH.read_text(encoding="utf-8"))
        self._session = ort.InferenceSession(
            str(ONNX_PATH),
            providers=["CPUExecutionProvider"],
        )

    def _vectorize(self, features: Dict[str, float]) -> np.ndarray:
        order: List[str] = self._meta.get("feature_order", [])

        if not order:
            logger.warning("feature_order пуст в model_meta.json — используем отсортированные ключи features")
            order = sorted(features.keys())

        missing = [k for k in order if k not in features]
        extra = [k for k in features if k not in order]

        if missing:
            logger.warning("features отсутствуют во входных данных (будут 0.0): %s", missing)
        if extra:
            logger.warning("features не входят в feature_order и будут проигнорированы: %s", extra)
        if missing and len(missing) == len(order):
            logger.error(
                "ВСЕ features отсутствуют — предсказание выполняется из нулевого вектора. "
                "Проверьте согласованность critical_points в профиле игры и модели."
            )

        row = [float(features.get(name, 0.0)) for name in order]
        return np.array([row], dtype=np.float32)

    def _resolve_archetypes(self, archetypes: Optional[List[str]]) -> List[str]:
        if archetypes:
            return archetypes
        meta_arch = self._meta.get("archetypes")
        if meta_arch:
            return list(meta_arch)
        return DEFAULT_ARCHETYPES

    def _adaptation_for(self, archetype: str) -> Dict[str, Any]:
        by_arch = self._meta.get("adaptation_by_archetype") or DEFAULT_ADAPTATION
        if archetype in by_arch:
            return dict(by_arch[archetype])
        return {"difficulty": 1.0, "enemy_density": 1.0, "loot_multiplier": 1.0}

    def predict(
        self,
        features: Dict[str, float],
        archetypes: Optional[List[str]] = None,
    ) -> Tuple[str, float, Dict[str, Any], str]:
        archetypes = self._resolve_archetypes(archetypes)

        if self._session is not None:
            input_name = self._session.get_inputs()[0].name
            vec = self._vectorize(features)
            outputs = self._session.run(None, {input_name: vec})
            probs = outputs[1][0] if len(outputs) > 1 else None
            label = int(outputs[0][0])

            meta_arch: List[str] = self._meta.get("archetypes", DEFAULT_ARCHETYPES)
            if 0 <= label < len(meta_arch):
                predicted = meta_arch[label]
            elif 0 <= label < len(archetypes):
                predicted = archetypes[label]
            else:
                predicted = archetypes[label % len(archetypes)]

            if predicted not in archetypes and archetypes:
                predicted = archetypes[label % len(archetypes)]

            if probs is not None:
                prob_values = list(probs.values()) if isinstance(probs, dict) else list(probs)
                confidence = float(max(prob_values))
                confidence = min(1.0, max(0.0, confidence))
            else:
                confidence = 0.7
            return (
                predicted,
                confidence,
                self._adaptation_for(predicted),
                self.model_version,
            )

        return self._heuristic(features, archetypes)

    def _heuristic(
        self,
        features: Dict[str, float],
        archetypes: List[str],
    ) -> Tuple[str, float, Dict[str, Any], str]:
        score = abs(sum(features.values())) if features else 0.0
        if not archetypes:
            archetypes = DEFAULT_ARCHETYPES
        idx = int(score) % len(archetypes)
        predicted = archetypes[idx]
        return (
            predicted,
            0.55 + min(0.35, score * 0.01),
            self._adaptation_for(predicted),
            "ml-heuristic-0.2",
        )


_engine: Optional[PredictorEngine] = None


def get_engine() -> PredictorEngine:
    global _engine
    if _engine is None:
        _engine = PredictorEngine()
    return _engine

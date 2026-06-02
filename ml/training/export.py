"""Общая логика обучения классификатора и экспорта ONNX."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Sequence

import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType

DEFAULT_ADAPTATION = {
    "explorer": {"difficulty": 0.85, "enemy_density": 0.9, "loot_multiplier": 1.2},
    "achiever": {"difficulty": 1.2, "enemy_density": 1.1, "loot_multiplier": 1.0},
    "socializer": {"difficulty": 0.95, "enemy_density": 0.85, "loot_multiplier": 1.15},
    "killer": {"difficulty": 1.35, "enemy_density": 1.4, "loot_multiplier": 0.95},
}


def train_and_export(
    X: np.ndarray,
    y: np.ndarray,
    feature_order: List[str],
    archetypes: List[str],
    models_dir: Path,
    model_version: str,
    adaptation_by_archetype: Dict[str, Dict[str, Any]] | None = None,
) -> Dict[str, float]:
    models_dir.mkdir(parents=True, exist_ok=True)
    onnx_path = models_dir / "classifier.onnx"
    meta_path = models_dir / "model_meta.json"

    if len(X) < 10:
        raise ValueError(f"Too few samples for training: {len(X)}")

    adaptation_by_archetype = adaptation_by_archetype or {
        a: dict(DEFAULT_ADAPTATION.get(a, {"difficulty": 1.0, "enemy_density": 1.0, "loot_multiplier": 1.0}))
        for a in archetypes
    }

    stratify = y if len(np.unique(y)) > 1 else None
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=stratify
    )

    clf = RandomForestClassifier(n_estimators=128, max_depth=16, random_state=42)
    clf.fit(X_train, y_train)

    train_acc = float(clf.score(X_train, y_train))
    test_acc = float(clf.score(X_test, y_test)) if len(X_test) else train_acc

    initial_type = FloatTensorType([None, len(feature_order)])
    onnx_model = convert_sklearn(clf, initial_types=[("features", initial_type)])
    onnx_path.write_bytes(onnx_model.SerializeToString())

    meta = {
        "model_version": model_version,
        "feature_order": feature_order,
        "archetypes": archetypes,
        "adaptation_by_archetype": adaptation_by_archetype,
        "metrics": {"train_accuracy": train_acc, "test_accuracy": test_acc, "samples": len(X)},
    }
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    print(f"Model saved: {onnx_path}")
    print(f"Metadata: {meta_path}")
    print(f"Samples: {len(X)}, train_acc={train_acc:.3f}, test_acc={test_acc:.3f}")
    return {"train_accuracy": train_acc, "test_accuracy": test_acc, "samples": float(len(X))}


def vectorize_batch(
    feature_dicts: Sequence[Dict[str, float]],
    feature_order: List[str],
) -> np.ndarray:
    rows = []
    for features in feature_dicts:
        rows.append([float(features.get(name, 0.0)) for name in feature_order])
    return np.array(rows, dtype=np.float32)


def labels_to_indices(labels: Sequence[str], archetypes: List[str]) -> np.ndarray:
    index = {name: i for i, name in enumerate(archetypes)}
    return np.array([index[label] for label in labels], dtype=np.int64)

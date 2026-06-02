#!/usr/bin/env python3
"""Обучает классификатор на синтетике (fallback без Postgres)."""
from __future__ import annotations

import random
import sys
from pathlib import Path

import numpy as np

ML_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ML_ROOT))

from training.export import DEFAULT_ADAPTATION, train_and_export, vectorize_batch, labels_to_indices

MODELS_DIR = ML_ROOT / "models"

FEATURE_ORDER = [
    "event_count_first_n",
    "time_sec",
    "hints_used",
    "deaths",
    "score",
    "event::jump",
    "event::puzzle_completed",
    "event::enemy_killed",
]

ARCHETYPES = ["explorer", "achiever", "socializer", "killer"]


def _sample_features(archetype: str, rng: random.Random) -> dict[str, float]:
    base = {
        "explorer": (5, 80, 0, 1, 30, 2, 4, 1),
        "achiever": (8, 40, 1, 2, 90, 1, 6, 3),
        "socializer": (6, 60, 0, 1, 50, 3, 2, 1),
        "killer": (7, 30, 2, 5, 70, 2, 3, 8),
    }
    centers = base[archetype]
    values = [max(0.0, c + rng.uniform(-2, 2)) for c in centers]
    return {name: values[i] for i, name in enumerate(FEATURE_ORDER)}


def main() -> int:
    rng = random.Random(42)
    np_rng = np.random.default_rng(42)

    feature_dicts = []
    labels = []
    per_class = 400
    for archetype in ARCHETYPES:
        for _ in range(per_class):
            feature_dicts.append(_sample_features(archetype, rng))
            labels.append(archetype)

    X = vectorize_batch(feature_dicts, FEATURE_ORDER)
    y = labels_to_indices(labels, ARCHETYPES)
    perm = np_rng.permutation(len(y))
    X, y = X[perm], y[perm]

    train_and_export(
        X,
        y,
        FEATURE_ORDER,
        ARCHETYPES,
        MODELS_DIR,
        "sklearn-rf-synthetic-1.0",
        adaptation_by_archetype=DEFAULT_ADAPTATION,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

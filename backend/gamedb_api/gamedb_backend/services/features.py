from collections import defaultdict
from typing import Any, Dict, List


def build_features_from_events(
    events: List[Dict[str, Any]],
    critical_points: List[Dict[str, Any]],
    bootstrap_actions: int,
) -> Dict[str, float]:
    """Агрегирует признаки из первых N событий (feature_schema_version=1)."""
    cp_weights = {cp["name"]: float(cp.get("weight", 1.0)) for cp in critical_points}
    metrics: Dict[str, float] = defaultdict(float)

    limited = events[:bootstrap_actions]
    metrics["event_count_first_n"] = float(len(limited))

    for event in limited:
        metrics[f"event::{event['event_name']}"] += 1.0
        params = event.get("parameters") or {}
        for key, value in params.items():
            if isinstance(value, (int, float)):
                metrics[key] += float(value)

    for key in list(metrics.keys()):
        if key in cp_weights:
            metrics[key] *= cp_weights[key]

    return dict(metrics)

from app.services.features import build_features_from_events


def test_build_features_counts_events():
    events = [
        {"event_name": "jump", "parameters": {"score": 10}},
        {"event_name": "jump", "parameters": {"score": 5}},
        {"event_name": "damage", "parameters": {}},
    ]
    features = build_features_from_events(events, critical_points=[], bootstrap_actions=10)
    assert features["event_count_first_n"] == 3.0
    assert features["event::jump"] == 2.0
    assert features["score"] == 15.0


def test_critical_point_weight_applied():
    events = [{"event_name": "x", "parameters": {"deaths": 2}}]
    cps = [{"name": "deaths", "weight": 3.0}]
    features = build_features_from_events(events, cps, bootstrap_actions=10)
    assert features["deaths"] == 6.0

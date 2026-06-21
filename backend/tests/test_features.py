from app.services.features import build_features_from_events
from app.services.ingest import should_trigger_prediction


def test_should_trigger_every_n_events():
    # Первое предсказание при 10 событиях
    assert should_trigger_prediction(10, 10, 0) is True
    # Второе — при 20
    assert should_trigger_prediction(20, 10, 1) is True
    # 15 событий — уже было 1 предсказание, второго ещё нет
    assert should_trigger_prediction(15, 10, 1) is False
    # До порога — нет предсказания
    assert should_trigger_prediction(9, 10, 0) is False
    # После первого — при 19 событиях второго ещё нет
    assert should_trigger_prediction(19, 10, 1) is False


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

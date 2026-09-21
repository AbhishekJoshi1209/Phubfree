"""
Tests for phubb_free/etl/unify.py.
"""

import pandas as pd
import pytest
from phubb_free.etl.unify import UNIFIED_SCHEMA, unify_events


def _make_sample_df(user_id: str, count: int = 5) -> pd.DataFrame:
    """Helper to create a valid unified dataframe."""
    return pd.DataFrame({
        "timestamp": [1000.0 + i * 60 for i in range(count)],
        "user_id": [user_id] * count,
        "event_type": ["unlock"] * count,
        "app_name": [None] * count,
        "rssi": [None] * count,
        "response_latency_sec": [None] * count,
        "hour_of_day": [10] * count,
        "day_of_week": [1] * count,
    })


def test_unify_events_success():
    df1 = _make_sample_df("u1", 3)
    df2 = _make_sample_df("u2", 4)
    result = unify_events([df1, df2])

    assert len(result) == 7
    assert list(result["user_id"].unique()) == ["u1", "u2"]
    for col in UNIFIED_SCHEMA:
        assert col in result.columns


def test_unify_events_deduplication():
    df1 = _make_sample_df("u1", 3)
    # duplicate of df1
    df2 = _make_sample_df("u1", 3)
    result = unify_events([df1, df2])

    assert len(result) == 3


def test_unify_events_sorting():
    df = pd.DataFrame({
        "timestamp": [300.0, 100.0, 200.0],
        "user_id": ["u2", "u1", "u1"],
        "event_type": ["unlock", "unlock", "unlock"],
        "app_name": [None, None, None],
        "rssi": [None, None, None],
        "response_latency_sec": [None, None, None],
        "hour_of_day": [1, 1, 1],
        "day_of_week": [0, 0, 0],
    })
    result = unify_events([df])
    # Should be sorted by (user_id, timestamp) -> ("u1", 100.0), ("u1", 200.0), ("u2", 300.0)
    assert list(result["user_id"]) == ["u1", "u1", "u2"]
    assert list(result["timestamp"]) == [100.0, 200.0, 300.0]


def test_unify_events_missing_column():
    df = _make_sample_df("u1", 3).drop(columns=["hour_of_day"])
    with pytest.raises(ValueError, match="Missing columns"):
        unify_events([df])


def test_unify_events_drops_extra_columns():
    df = _make_sample_df("u1", 3)
    df["extra_column"] = 123
    result = unify_events([df])
    assert "extra_column" not in result.columns
    assert len(result.columns) == len(UNIFIED_SCHEMA)

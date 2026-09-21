"""
Validation tests for the generated Stage 1 parquet artifacts.
"""

import numpy as np
import pandas as pd
from phubb_free.config import UNIFIED_EVENTS_FILE, FEATURES_LABELED_FILE
from phubb_free.etl.unify import UNIFIED_SCHEMA


def test_unified_events_parquet_exists_and_valid():
    assert UNIFIED_EVENTS_FILE.exists(), f"Missing {UNIFIED_EVENTS_FILE}"
    df = pd.read_parquet(UNIFIED_EVENTS_FILE)
    assert len(df) > 0

    # Validate columns
    for col in UNIFIED_SCHEMA:
        assert col in df.columns, f"Missing column {col} in unified events"

    # Validate event types
    valid_events = {"unlock", "app_switch", "notification", "proximity"}
    actual_events = set(df["event_type"].unique())
    assert actual_events.issubset(valid_events), f"Unexpected events: {actual_events - valid_events}"

    # Validate user prefixes
    prefixes = set(df["user_id"].str.split("_").str[0].unique())
    assert {"cns", "sl", "lj"}.issubset(prefixes)


def test_features_labeled_parquet_exists_and_valid():
    assert FEATURES_LABELED_FILE.exists(), f"Missing {FEATURES_LABELED_FILE}"
    df = pd.read_parquet(FEATURES_LABELED_FILE)
    assert len(df) > 0

    expected_cols = [
        "timestamp", "user_id", "event_type",
        "unlock_freq_1h", "app_switch_rate_1h",
        "notif_count_1h", "notif_resp_latency_mean_1h", "notif_resp_latency_median_1h",
        "proximity_flag", "proximity_density_1h",
        "hour_of_day", "day_of_week", "is_weekend",
        "phubbing",
    ]
    assert list(df.columns) == expected_cols

    # Phubbing labels must be binary {0, 1}
    unique_labels = set(df["phubbing"].unique())
    assert unique_labels == {0, 1}, f"Expected {{0, 1}}, got {unique_labels}"

    # Hour of day must be in 0..23
    assert df["hour_of_day"].between(0, 23).all()

    # Day of week must be in 0..6
    assert df["day_of_week"].between(0, 6).all()

    # Non-negative frequencies
    assert (df["unlock_freq_1h"] >= 0).all()
    assert (df["proximity_density_1h"] >= 0).all()

    # Latencies (where not null) must be non-negative
    latencies = df["notif_resp_latency_mean_1h"].dropna()
    assert (latencies >= 0).all()

    # No infinite values in numeric columns
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    for col in numeric_cols:
        assert not np.isinf(df[col]).any(), f"Infinite values found in {col}"

"""
Tests for phubb_free/features/feature_engineering.py.
"""

import numpy as np
import pandas as pd
from phubb_free.config import EVENT_UNLOCK, EVENT_NOTIFICATION, EVENT_PROXIMITY
from phubb_free.features.feature_engineering import (
    _count_events_in_window,
    _check_proximity,
    _latency_stats_in_window,
    compute_features_for_user,
)


def test_count_events_in_window():
    query_ts = np.array([100.0, 200.0, 300.0])
    event_ts = np.array([50.0, 100.0, 150.0, 200.0, 250.0])
    counts = _count_events_in_window(query_ts, event_ts, window_sec=100)
    assert list(counts) == [2, 3, 2]


def test_check_proximity():
    prox_ts = np.array([1000.0, 5000.0])
    query_ts = np.array([900.0, 1700.0, 4900.0])
    flags = _check_proximity(query_ts, prox_ts, window_sec=600)
    assert list(flags) == [True, False, True]


def test_latency_stats_in_window():
    query_ts = np.array([1000.0, 2000.0])
    event_ts = np.array([800.0, 900.0])
    latency_vals = np.array([10.0, 20.0])
    means, medians = _latency_stats_in_window(query_ts, event_ts, latency_vals, window_sec=500)
    assert means[0] == 15.0
    assert medians[0] == 15.0
    assert np.isnan(means[1])
    assert np.isnan(medians[1])


def test_compute_features_for_user_proximity_only():
    df = pd.DataFrame({
        "timestamp": [100.0, 200.0],
        "user_id": ["u_prox", "u_prox"],
        "event_type": [EVENT_PROXIMITY, EVENT_PROXIMITY],
        "app_name": [None, None],
        "rssi": [-65, -70],
        "response_latency_sec": [None, None],
        "hour_of_day": [12, 12],
        "day_of_week": [2, 2],
    })
    res = compute_features_for_user(df)
    assert len(res) == 0


def test_compute_features_for_user_phubbing_label():
    df = pd.DataFrame({
        "timestamp": [1000.0, 1050.0, 5000.0],
        "user_id": ["u1", "u1", "u1"],
        "event_type": [EVENT_UNLOCK, EVENT_PROXIMITY, EVENT_UNLOCK],
        "app_name": [None, None, None],
        "rssi": [None, -60, None],
        "response_latency_sec": [None, None, None],
        "hour_of_day": [14, 14, 15],
        "day_of_week": [3, 3, 3],
    })
    res = compute_features_for_user(df)
    assert len(res) == 2
    assert list(res["phubbing"]) == [1, 0]
    assert list(res["proximity_flag"]) == [True, False]

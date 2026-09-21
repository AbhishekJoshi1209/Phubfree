"""
Feature Engineering & Proxy Label Construction for Phubb-Free.

This module takes the unified events table (produced by the ETL pipeline) and
computes per-user rolling features plus the proxy phubbing label.

═══════════════════════════════════════════════════════════════════════════════
PROXY LABEL METHODOLOGY — READ THIS CAREFULLY
═══════════════════════════════════════════════════════════════════════════════

*** THIS IS A CONSTRUCTED PROXY LABEL, NOT LITERAL GROUND TRUTH. ***

No public dataset contains a direct "phubbing" annotation. The label is
engineered as follows:

    A phone-interaction event (unlock / app_switch / notification response)
    is labeled phubbing=1 if a proximity event (Bluetooth co-presence with
    another person) is active for that user within a configurable time window
    around the phone-interaction event.

    Otherwise phubbing=0.

This is a reasonable proxy because phubbing = "using your phone while someone
is physically present." But it has known limitations:

    1. False positives: the user might be *showing* something on their phone
       to the nearby person (legitimate shared use, not phubbing).
    2. False negatives: someone might be nearby but outside BT range, or
       their device might not be detected.
    3. Population mismatch: the three datasets are from different populations.
       A user's proximity events and phone-interaction events may come from
       different source datasets. We address this by:
       (a) Computing features independently per-user within each dataset.
       (b) For users who have BOTH proximity and phone-interaction events
           (primarily StudentLife users, who have both phonelock and BT data),
           the proxy label is directly meaningful.
       (c) For users with only one signal type (e.g., CNS users who only
           have proximity events), we can still compute proximity-pattern
           features but cannot assign a phubbing label. These users are
           excluded from the labeled training set but their feature
           distributions inform the model's understanding of proximity.

This must be documented as a constructed proxy label, not literal ground
truth, in any report or presentation.
═══════════════════════════════════════════════════════════════════════════════

FEATURES COMPUTED:
    1. unlock_freq_1h        — count of unlock events in trailing 1-hour window
    2. app_switch_rate_1h    — count of app_switch events in trailing 1-hour window
    3. notif_count_1h        — count of notification events in trailing 1-hour
    4. notif_resp_latency_mean_1h  — mean notification response latency (seconds)
    5. notif_resp_latency_median_1h — median notification response latency
    6. proximity_flag        — boolean: any proximity event in the surrounding window
    7. proximity_density_1h  — count of proximity events in trailing 1-hour window
    8. hour_of_day           — 0-23
    9. day_of_week           — 0-6 (Monday=0)
   10. is_weekend            — boolean (Saturday=5 or Sunday=6)
   11. phubbing              — PROXY LABEL: 1 if phone-interaction during co-presence
"""

import pandas as pd
import numpy as np

from phubb_free.config import (
    FEATURE_WINDOW_SEC,
    DATA_OUTPUT_DIR,
    FEATURES_LABELED_FILE,
    EVENT_UNLOCK,
    EVENT_APP_SWITCH,
    EVENT_NOTIFICATION,
    EVENT_PROXIMITY,
)

# How far (seconds) a proximity event can be from a phone-interaction event
# and still count as "co-present." This creates a window around phone events
# within which we look for proximity evidence.
PROXIMITY_WINDOW_SEC = 600  # 10 minutes


def _rolling_count(timestamps: np.ndarray, window_sec: int) -> np.ndarray:
    """
    For each timestamp, count how many other timestamps fall within
    [t - window_sec, t]. Uses a sliding-window approach (O(n) after sort).
    """
    n = len(timestamps)
    if n == 0:
        return np.array([], dtype=np.int32)

    ts_sorted = np.sort(timestamps)
    counts = np.empty(n, dtype=np.int32)
    left = 0

    for right in range(n):
        while ts_sorted[left] < ts_sorted[right] - window_sec:
            left += 1
        counts[right] = right - left + 1  # includes self

    # Map back to original order
    sort_idx = np.argsort(timestamps)
    result = np.empty(n, dtype=np.int32)
    result[sort_idx] = counts
    return result


def compute_features_for_user(user_events: pd.DataFrame, window_sec: int = FEATURE_WINDOW_SEC) -> pd.DataFrame:
    """
    Compute rolling features and the proxy phubbing label for a single user.

    Parameters
    ----------
    user_events : pd.DataFrame
        All events for one user_id, with unified schema columns.
    window_sec : int
        Rolling window size in seconds for frequency features.

    Returns
    -------
    pd.DataFrame
        One row per phone-interaction event (unlock / app_switch / notification),
        with computed features and the proxy phubbing label.
        Proximity-only users return an empty DataFrame.
    """
    user_events = user_events.sort_values("timestamp").reset_index(drop=True)

    # ── Split events by type ──────────────────────────────────────────────
    unlocks = user_events[user_events["event_type"] == EVENT_UNLOCK]
    app_switches = user_events[user_events["event_type"] == EVENT_APP_SWITCH]
    notifications = user_events[user_events["event_type"] == EVENT_NOTIFICATION]
    proximities = user_events[user_events["event_type"] == EVENT_PROXIMITY]

    # ── Phone-interaction events = the rows we want to label ──────────────
    phone_events = user_events[
        user_events["event_type"].isin([EVENT_UNLOCK, EVENT_APP_SWITCH, EVENT_NOTIFICATION])
    ].copy()

    if len(phone_events) == 0:
        # This user has only proximity events (e.g., CNS-only users).
        # They contribute to proximity-pattern understanding but can't be labeled.
        return pd.DataFrame()

    phone_ts = phone_events["timestamp"].values

    # ── Feature 1: unlock frequency in trailing window ────────────────────
    if len(unlocks) > 0:
        unlock_ts = unlocks["timestamp"].values
        phone_events["unlock_freq_1h"] = _count_events_in_window(
            query_ts=phone_ts, event_ts=unlock_ts, window_sec=window_sec
        )
    else:
        phone_events["unlock_freq_1h"] = 0

    # ── Feature 2: app-switch rate in trailing window ─────────────────────
    if len(app_switches) > 0:
        switch_ts = app_switches["timestamp"].values
        phone_events["app_switch_rate_1h"] = _count_events_in_window(
            query_ts=phone_ts, event_ts=switch_ts, window_sec=window_sec
        )
    else:
        phone_events["app_switch_rate_1h"] = 0

    # ── Feature 3: notification count in trailing window ──────────────────
    if len(notifications) > 0:
        notif_ts = notifications["timestamp"].values
        phone_events["notif_count_1h"] = _count_events_in_window(
            query_ts=phone_ts, event_ts=notif_ts, window_sec=window_sec
        )
    else:
        phone_events["notif_count_1h"] = 0

    # ── Features 4-5: notification response latency stats ─────────────────
    if len(notifications) > 0:
        notif_with_latency = notifications.dropna(subset=["response_latency_sec"])
        if len(notif_with_latency) > 0:
            latency_ts = notif_with_latency["timestamp"].values
            latency_vals = notif_with_latency["response_latency_sec"].values.astype(np.float64)
            mean_lat, median_lat = _latency_stats_in_window(
                query_ts=phone_ts, event_ts=latency_ts,
                latency_vals=latency_vals, window_sec=window_sec
            )
            phone_events["notif_resp_latency_mean_1h"] = mean_lat
            phone_events["notif_resp_latency_median_1h"] = median_lat
        else:
            phone_events["notif_resp_latency_mean_1h"] = np.nan
            phone_events["notif_resp_latency_median_1h"] = np.nan
    else:
        phone_events["notif_resp_latency_mean_1h"] = np.nan
        phone_events["notif_resp_latency_median_1h"] = np.nan

    # ── Feature 6: proximity flag (binary) ────────────────────────────────
    # Is there ANY proximity event within ±PROXIMITY_WINDOW_SEC of this event?
    if len(proximities) > 0:
        prox_ts = np.sort(proximities["timestamp"].values)
        phone_events["proximity_flag"] = _check_proximity(
            query_ts=phone_ts, prox_ts=prox_ts, window_sec=PROXIMITY_WINDOW_SEC
        )
    else:
        phone_events["proximity_flag"] = False

    # ── Feature 7: proximity density in trailing window ───────────────────
    if len(proximities) > 0:
        phone_events["proximity_density_1h"] = _count_events_in_window(
            query_ts=phone_ts, event_ts=proximities["timestamp"].values,
            window_sec=window_sec
        )
    else:
        phone_events["proximity_density_1h"] = 0

    # ── Features 8-10: temporal context (already in data, just ensure) ────
    phone_events["is_weekend"] = phone_events["day_of_week"].isin([5, 6])

    # ── PROXY LABEL: phubbing ─────────────────────────────────────────────
    # A phone-interaction event during co-presence = proxy phubbing moment.
    # See module docstring for full methodology and caveats.
    phone_events["phubbing"] = phone_events["proximity_flag"].astype(int)

    # ── Select output columns ─────────────────────────────────────────────
    output_cols = [
        "timestamp", "user_id", "event_type",
        "unlock_freq_1h", "app_switch_rate_1h",
        "notif_count_1h", "notif_resp_latency_mean_1h", "notif_resp_latency_median_1h",
        "proximity_flag", "proximity_density_1h",
        "hour_of_day", "day_of_week", "is_weekend",
        "phubbing",
    ]
    return phone_events[output_cols]


def _count_events_in_window(
    query_ts: np.ndarray, event_ts: np.ndarray, window_sec: int
) -> np.ndarray:
    """
    For each query timestamp, count how many event timestamps fall within
    [query_t - window_sec, query_t].
    """
    event_sorted = np.sort(event_ts)
    counts = np.empty(len(query_ts), dtype=np.int32)
    for i, qt in enumerate(query_ts):
        lo = np.searchsorted(event_sorted, qt - window_sec, side="left")
        hi = np.searchsorted(event_sorted, qt, side="right")
        counts[i] = hi - lo
    return counts


def _latency_stats_in_window(
    query_ts: np.ndarray,
    event_ts: np.ndarray,
    latency_vals: np.ndarray,
    window_sec: int,
) -> tuple[np.ndarray, np.ndarray]:
    """
    For each query timestamp, compute mean and median of latency values
    for events within [query_t - window_sec, query_t].
    """
    sort_idx = np.argsort(event_ts)
    event_sorted = event_ts[sort_idx]
    latency_sorted = latency_vals[sort_idx]

    means = np.full(len(query_ts), np.nan, dtype=np.float64)
    medians = np.full(len(query_ts), np.nan, dtype=np.float64)

    for i, qt in enumerate(query_ts):
        lo = np.searchsorted(event_sorted, qt - window_sec, side="left")
        hi = np.searchsorted(event_sorted, qt, side="right")
        if hi > lo:
            window_lats = latency_sorted[lo:hi]
            means[i] = np.mean(window_lats)
            medians[i] = np.median(window_lats)

    return means, medians


def _check_proximity(
    query_ts: np.ndarray, prox_ts: np.ndarray, window_sec: int
) -> np.ndarray:
    """
    For each query timestamp, check if ANY proximity event exists within
    [query_t - window_sec, query_t + window_sec].
    """
    flags = np.zeros(len(query_ts), dtype=bool)
    for i, qt in enumerate(query_ts):
        lo = np.searchsorted(prox_ts, qt - window_sec, side="left")
        hi = np.searchsorted(prox_ts, qt + window_sec, side="right")
        flags[i] = hi > lo
    return flags


def compute_all_features(unified_events: pd.DataFrame) -> pd.DataFrame:
    """
    Compute features and proxy labels for all users in the unified events table.

    Parameters
    ----------
    unified_events : pd.DataFrame
        Output of the unifier (all datasets combined).

    Returns
    -------
    pd.DataFrame
        Feature table with one row per phone-interaction event, including
        the proxy phubbing label.
    """
    print("\n[Features] Computing per-user rolling features ...")
    user_ids = unified_events["user_id"].unique()
    print(f"[Features]   Processing {len(user_ids)} users ...")

    feature_dfs = []
    skipped_prox_only = 0

    for i, uid in enumerate(user_ids):
        if (i + 1) % 100 == 0 or (i + 1) == len(user_ids):
            print(f"[Features]   Progress: {i + 1}/{len(user_ids)} users")

        user_df = unified_events[unified_events["user_id"] == uid]
        features = compute_features_for_user(user_df)

        if len(features) == 0:
            skipped_prox_only += 1
            continue

        feature_dfs.append(features)

    if skipped_prox_only > 0:
        print(f"[Features]   Skipped {skipped_prox_only} proximity-only users (no phone events)")

    if not feature_dfs:
        raise ValueError("[Features] No users produced feature rows — check ETL output")

    result = pd.concat(feature_dfs, ignore_index=True)

    # ── Summary statistics ────────────────────────────────────────────────
    print(f"\n[Features] === Feature Table Summary ===")
    print(f"  Total rows:           {len(result):,}")
    print(f"  Unique users:         {result['user_id'].nunique()}")
    print(f"  Phubbing label dist:  {result['phubbing'].value_counts().to_dict()}")
    pct = result["phubbing"].mean() * 100
    print(f"  Phubbing rate:        {pct:.1f}%")
    print(f"  Feature statistics:")
    feature_cols = [
        "unlock_freq_1h", "app_switch_rate_1h", "notif_count_1h",
        "notif_resp_latency_mean_1h", "proximity_density_1h",
    ]
    for col in feature_cols:
        if col in result.columns:
            vals = result[col].dropna()
            if len(vals) > 0:
                print(f"    {col}: mean={vals.mean():.2f}, median={vals.median():.2f}, "
                      f"std={vals.std():.2f}, min={vals.min():.2f}, max={vals.max():.2f}")

    return result


def save_features(df: pd.DataFrame, path=None) -> None:
    """Save the feature table to Parquet."""
    path = path or FEATURES_LABELED_FILE
    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    df.to_parquet(str(path), index=False, engine="pyarrow")
    print(f"\n[Features] Saved feature table to: {path}")
    print(f"  File size: {path.stat().st_size / 1024:.1f} KB")

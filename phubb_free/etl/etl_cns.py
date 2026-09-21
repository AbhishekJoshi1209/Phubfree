"""
ETL — Copenhagen Networks Study (CNS) Bluetooth proximity data.

SOURCE: https://figshare.com/articles/dataset/The_Copenhagen_Networks_Study_interaction_data/7267433
FORMAT: bt_symmetric.csv — columns: timestamp, user_a, user_b, rssi
        timestamp = relative seconds from study start (300s / 5-min epochs)
        user_b == -1 → empty scan (no device detected)
        user_b == -2 → non-experiment device detected

ROLE IN PHUBB-FREE:
    Provides the *proximity / social-context signal* — used to learn what
    Bluetooth co-presence patterns look like when "another person is physically
    nearby right now."

    We keep ONLY valid user-to-user scans (user_b ≥ 0) and apply the RSSI
    co-presence threshold to produce proximity events.

METHODOLOGY NOTE:
    CNS timestamps are relative (seconds from study start), NOT Unix epoch.
    We ASSUME timestamp=0 corresponds to midnight for deriving hour_of_day.
    Since we only use time-of-day as a contextual feature (not absolute calendar
    time), and this dataset's users are a SEPARATE population from the other two
    datasets, this assumption affects only CNS-internal time-of-day patterns.

    This dataset does NOT contain any phubbing labels. It is used solely to
    model one signal type (Bluetooth proximity patterns). The phubbing proxy
    label is constructed downstream by compositing independently-learned
    patterns from all three datasets.
"""

import pandas as pd
import numpy as np

from phubb_free.config import (
    CNS_BT_FILE,
    RSSI_COPRESENCE_THRESHOLD,
    USER_PREFIX_CNS,
    EVENT_PROXIMITY,
)


def load_cns_proximity(
    rssi_threshold: int = RSSI_COPRESENCE_THRESHOLD,
    sample_frac: float | None = None,
) -> pd.DataFrame:
    """
    Load CNS Bluetooth symmetric scan data and produce proximity events
    in the unified Phubb-Free schema.

    Parameters
    ----------
    rssi_threshold : int
        Minimum RSSI (dBm) to consider as co-presence. Default -75 dBm.
    sample_frac : float or None
        If set, randomly sample this fraction of the raw data before processing
        (useful for development/testing on the ~98 MB file).

    Returns
    -------
    pd.DataFrame
        Columns: timestamp, user_id, event_type, app_name, rssi,
                 response_latency_sec, hour_of_day, day_of_week
    """
    print("[CNS] Loading bt_symmetric.csv ...")

    # First row is a comment header: "# timestamp, user_a, user_b, rssi"
    df = pd.read_csv(
        CNS_BT_FILE,
        skiprows=1,
        header=None,
        names=["timestamp", "user_a", "user_b", "rssi"],
        dtype={"timestamp": np.int64, "user_a": np.int64, "user_b": np.int64, "rssi": np.int64},
    )
    print(f"[CNS]   Raw rows loaded: {len(df):,}")

    if sample_frac is not None:
        df = df.sample(frac=sample_frac, random_state=42)
        print(f"[CNS]   Sampled to {len(df):,} rows ({sample_frac:.0%})")

    # ── Filter: keep only valid user-to-user scans ────────────────────────
    # user_b == -1 → empty scan, user_b == -2 → non-experiment device
    df = df[df["user_b"] >= 0].copy()
    print(f"[CNS]   After filtering non-user scans: {len(df):,}")

    # ── Apply RSSI co-presence threshold ──────────────────────────────────
    # RSSI is negative; closer to 0 = stronger = closer.
    # Keep only scans where signal is strong enough to indicate physical proximity.
    df = df[df["rssi"] >= rssi_threshold].copy()
    print(f"[CNS]   After RSSI >= {rssi_threshold} dBm filter: {len(df):,}")

    # ── Derive time-of-day context ────────────────────────────────────────
    # CNS timestamps are relative seconds from study start.
    # Assumption: timestamp=0 = midnight (see module docstring).
    SECONDS_PER_DAY = 86400
    SECONDS_PER_HOUR = 3600
    df["hour_of_day"] = ((df["timestamp"] % SECONDS_PER_DAY) // SECONDS_PER_HOUR).astype(np.int8)
    df["day_of_week"] = ((df["timestamp"] // SECONDS_PER_DAY) % 7).astype(np.int8)

    # ── Map to unified schema ─────────────────────────────────────────────
    # Each row represents: "user_a detected user_b nearby at this timestamp."
    # We emit one proximity event per user_a (the observer).
    unified = pd.DataFrame({
        "timestamp": df["timestamp"].values,
        "user_id": USER_PREFIX_CNS + "_" + df["user_a"].astype(str),
        "event_type": EVENT_PROXIMITY,
        "app_name": pd.NA,           # Not applicable for proximity events
        "rssi": df["rssi"].values,
        "response_latency_sec": pd.NA,  # Not applicable
        "hour_of_day": df["hour_of_day"].values,
        "day_of_week": df["day_of_week"].values,
    })

    # Use nullable integer types for cleanliness
    unified["rssi"] = unified["rssi"].astype("Int16")
    unified["response_latency_sec"] = unified["response_latency_sec"].astype("Float64")

    print(f"[CNS]   Output rows: {len(unified):,}")
    print(f"[CNS]   Unique users: {unified['user_id'].nunique()}")
    return unified


if __name__ == "__main__":
    # Quick standalone test
    df = load_cns_proximity(sample_frac=0.01)
    print("\nSample output:")
    print(df.head(10).to_string())
    print("\nSchema:")
    print(df.dtypes.to_string())

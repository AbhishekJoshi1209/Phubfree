"""
ETL — Dartmouth StudentLife dataset (phone lock & Bluetooth sensing).

SOURCE: https://studentlife.cs.dartmouth.edu/  (mirror: Zenodo 3529253)
        Loaded here from .Rds files via the CRAN `studentlife` R package export.
FORMAT: phonelock.Rds — columns: start_timestamp, end_timestamp, uid
                        timestamps are Unix epoch (seconds)
        bluetooth.Rds — columns: timestamp, MAC, class_id, level (RSSI), uid

ROLE IN PHUBB-FREE:
    Provides the *baseline unlock / app-switch rhythm* signal — used to learn
    each user's typical phone-interaction pattern so the downstream model can
    detect deviations that correlate with phubbing.

    Also provides a secondary proximity signal from Bluetooth scans (though
    without a study-participant mapping like CNS, so BT proximity here means
    "any nearby BT device," not specifically another study participant).

METHODOLOGY NOTES:
    1. "App-switch" events are APPROXIMATED: two consecutive unlock sessions
       whose start_timestamps are < APP_SWITCH_GAP_THRESHOLD_SEC apart are
       treated as a rapid re-unlock (proxy for switching apps). No direct
       app-switch log exists in StudentLife.
    2. Bluetooth scans here detect arbitrary nearby BT devices (MAC addresses),
       not necessarily other study participants. We still use RSSI ≥ threshold
       as a proximity signal, but it's noisier than CNS's participant-only scans.
    3. This dataset is from a SEPARATE population than CNS and Ljubljana.
       We are NOT merging at the individual level — only learning signal
       patterns independently.
"""

import pandas as pd
import numpy as np
import pyreadr

from phubb_free.config import (
    STUDENTLIFE_PHONELOCK,
    STUDENTLIFE_BLUETOOTH,
    RSSI_COPRESENCE_THRESHOLD,
    APP_SWITCH_GAP_THRESHOLD_SEC,
    USER_PREFIX_STUDENTLIFE,
    EVENT_UNLOCK,
    EVENT_APP_SWITCH,
    EVENT_PROXIMITY,
)


def _load_rds(path) -> pd.DataFrame:
    """Read an .Rds file and return the single DataFrame inside it."""
    result = pyreadr.read_r(str(path))
    # pyreadr returns a dict; .Rds files contain exactly one object
    return list(result.values())[0]


def load_studentlife_unlock() -> pd.DataFrame:
    """
    Load StudentLife phonelock data → unlock and app-switch events.

    Returns
    -------
    pd.DataFrame
        Unified schema rows for EVENT_UNLOCK and EVENT_APP_SWITCH.
    """
    print("[StudentLife] Loading phonelock.Rds ...")
    df = _load_rds(STUDENTLIFE_PHONELOCK)
    print(f"[StudentLife]   Raw unlock sessions: {len(df):,}")

    # Rename for clarity
    df = df.rename(columns={"start_timestamp": "ts_start", "end_timestamp": "ts_end"})
    df["uid"] = df["uid"].astype(str)

    # Sort by user, then session start time
    df = df.sort_values(["uid", "ts_start"]).reset_index(drop=True)

    # ── Emit unlock events (one per session) ──────────────────────────────
    unlock_rows = []
    app_switch_rows = []

    for uid, group in df.groupby("uid"):
        user_id = f"{USER_PREFIX_STUDENTLIFE}_{uid}"
        starts = group["ts_start"].values

        for i, ts in enumerate(starts):
            unlock_rows.append({
                "timestamp": ts,
                "user_id": user_id,
                "event_type": EVENT_UNLOCK,
            })

            # ── Detect rapid re-unlocks as app-switch proxy ───────────
            # If this unlock started within APP_SWITCH_GAP_THRESHOLD_SEC
            # of the previous session's start, treat it as an app-switch.
            if i > 0 and (ts - starts[i - 1]) < APP_SWITCH_GAP_THRESHOLD_SEC:
                app_switch_rows.append({
                    "timestamp": ts,
                    "user_id": user_id,
                    "event_type": EVENT_APP_SWITCH,
                })

    events = pd.DataFrame(unlock_rows + app_switch_rows)
    print(f"[StudentLife]   Unlock events: {len(unlock_rows):,}")
    print(f"[StudentLife]   App-switch proxy events: {len(app_switch_rows):,}")

    # ── Derive time-of-day context from Unix timestamps ───────────────────
    dt = pd.to_datetime(events["timestamp"], unit="s", utc=True)
    events["hour_of_day"] = dt.dt.hour.astype(np.int8)
    events["day_of_week"] = dt.dt.dayofweek.astype(np.int8)

    # ── Fill unified schema columns ───────────────────────────────────────
    events["app_name"] = pd.NA
    events["rssi"] = pd.NA
    events["response_latency_sec"] = pd.NA

    # Cast nullable columns
    events["rssi"] = events["rssi"].astype("Int16")
    events["response_latency_sec"] = events["response_latency_sec"].astype("Float64")

    return events


def load_studentlife_bluetooth(
    rssi_threshold: int = RSSI_COPRESENCE_THRESHOLD,
) -> pd.DataFrame:
    """
    Load StudentLife Bluetooth scan data → proximity events.

    Parameters
    ----------
    rssi_threshold : int
        Minimum RSSI to consider as co-presence.

    Returns
    -------
    pd.DataFrame
        Unified schema rows for EVENT_PROXIMITY.
    """
    print("[StudentLife] Loading bluetooth.Rds ...")
    df = _load_rds(STUDENTLIFE_BLUETOOTH)
    print(f"[StudentLife]   Raw BT scan rows: {len(df):,}")

    # The 'level' column contains RSSI values
    df = df.rename(columns={"level": "rssi_raw"})
    df["rssi_raw"] = pd.to_numeric(df["rssi_raw"], errors="coerce")

    # Drop NaN RSSI
    df = df.dropna(subset=["rssi_raw"])

    # Apply co-presence threshold
    df = df[df["rssi_raw"] >= rssi_threshold].copy()
    print(f"[StudentLife]   After RSSI >= {rssi_threshold} dBm: {len(df):,}")

    # Deduplicate: one proximity event per (user, timestamp) regardless of
    # how many BT devices were detected. We keep the strongest (max) RSSI.
    df["uid"] = df["uid"].astype(str)
    grouped = (
        df.groupby(["uid", "timestamp"])
        .agg(rssi=("rssi_raw", "max"))
        .reset_index()
    )
    print(f"[StudentLife]   Deduplicated proximity events: {len(grouped):,}")

    # ── Map to unified schema ─────────────────────────────────────────────
    dt = pd.to_datetime(grouped["timestamp"], unit="s", utc=True)

    unified = pd.DataFrame({
        "timestamp": grouped["timestamp"].values,
        "user_id": USER_PREFIX_STUDENTLIFE + "_" + grouped["uid"],
        "event_type": EVENT_PROXIMITY,
        "app_name": pd.NA,
        "rssi": grouped["rssi"].astype("Int16"),
        "response_latency_sec": pd.NA,
        "hour_of_day": dt.dt.hour.values.astype(np.int8),
        "day_of_week": dt.dt.dayofweek.values.astype(np.int8),
    })
    unified["response_latency_sec"] = unified["response_latency_sec"].astype("Float64")

    print(f"[StudentLife]   Output proximity rows: {len(unified):,}")
    return unified


def load_studentlife_all(
    rssi_threshold: int = RSSI_COPRESENCE_THRESHOLD,
) -> pd.DataFrame:
    """
    Load all StudentLife data (unlock + app-switch + proximity) and return
    a single unified-schema DataFrame.
    """
    unlock_df = load_studentlife_unlock()
    bt_df = load_studentlife_bluetooth(rssi_threshold=rssi_threshold)

    combined = pd.concat([unlock_df, bt_df], ignore_index=True)
    combined = combined.sort_values(["user_id", "timestamp"]).reset_index(drop=True)

    print(f"[StudentLife] Combined events: {len(combined):,}")
    print(f"[StudentLife] Unique users: {combined['user_id'].nunique()}")
    return combined


if __name__ == "__main__":
    df = load_studentlife_all()
    print("\nSample output:")
    print(df.head(15).to_string())
    print("\nEvent type distribution:")
    print(df["event_type"].value_counts().to_string())

"""
ETL — University of Ljubljana Mobile Notification Behaviour Dataset.

SOURCE: https://gitlab.fri.uni-lj.si/lrk/notif-context-dataset
FORMAT: Tab-delimited files in data/ directory:
        Notifications.tab — device_id, notification_id, notification_from, date, action
        Screen.tab        — device_id, notification_id, screen (Locked/Unlocked)
        Bluetooth.tab     — device_id, notification_id, name (BT device name)

ROLE IN PHUBB-FREE:
    Provides the *notification-triggered usage signal* — used to learn how
    quickly users respond to notifications (response latency), and the screen
    state / BT environment at the moment of each notification.

METHODOLOGY NOTES:
    1. The Notifications.tab file does NOT contain a 'response_time' column.
       Response latency must be COMPUTED by joining Posted events to their
       corresponding Clicked/Removed events via the notification_from FK.
       Some joins produce negative response times (clock skew); these are
       filtered out.

    2. Screen.tab is keyed by (device_id, notification_id) and tells us
       whether the screen was locked or unlocked when the notification arrived.
       We treat "Unlocked" state at notification time as an unlock event.

    3. Bluetooth.tab gives BT device names detected near each notification
       event. We use "≥ 1 BT device detected" as a binary proximity signal
       (no RSSI values are available in this dataset).

    4. Only 12 of the 19 users have matched Posted→Response notification
       pairs. We keep all 19 users' Posted notifications for unlock-frequency
       features, but response_latency_sec is only available for 12.

    5. This dataset is from a SEPARATE population than CNS and StudentLife.
"""

import pandas as pd
import numpy as np

from phubb_free.config import (
    LJUBLJANA_NOTIFICATIONS,
    LJUBLJANA_SCREEN,
    LJUBLJANA_BLUETOOTH,
    USER_PREFIX_LJUBLJANA,
    EVENT_UNLOCK,
    EVENT_NOTIFICATION,
    EVENT_PROXIMITY,
)


def _load_tab(path) -> pd.DataFrame:
    """Read a tab-delimited file."""
    return pd.read_csv(str(path), sep="\t")


def load_ljubljana_notifications() -> pd.DataFrame:
    """
    Load Ljubljana notification data → notification events with computed
    response latency, plus unlock events from screen state.

    Returns
    -------
    pd.DataFrame
        Unified schema rows for EVENT_NOTIFICATION and EVENT_UNLOCK.
    """
    print("[Ljubljana] Loading Notifications.tab ...")
    notif = _load_tab(LJUBLJANA_NOTIFICATIONS)
    print(f"[Ljubljana]   Raw notification rows: {len(notif):,}")
    print(f"[Ljubljana]   Action distribution:")
    for action, count in notif["action"].value_counts().items():
        print(f"[Ljubljana]     {action}: {count:,}")

    # ── Compute response latency ──────────────────────────────────────────
    # Split into Posted and Response (Clicked/Removed) subsets
    posted = (
        notif[notif["action"] == "Posted"][["notification_id", "date", "device_id"]]
        .rename(columns={"date": "posted_ts"})
    )
    responses = (
        notif[notif["action"] != "Posted"][["notification_from", "date", "action", "device_id"]]
        .rename(columns={"date": "response_ts", "notification_from": "notification_id"})
    )

    # Join Posted → Response via notification_id
    matched = responses.merge(posted[["notification_id", "posted_ts"]], on="notification_id", how="inner")
    matched["response_latency_ms"] = matched["response_ts"] - matched["posted_ts"]
    matched["response_latency_sec"] = matched["response_latency_ms"] / 1000.0

    # Filter out negative response times (clock skew artifacts)
    n_negative = (matched["response_latency_sec"] < 0).sum()
    if n_negative > 0:
        print(f"[Ljubljana]   Filtering {n_negative} rows with negative response time (clock skew)")
        matched = matched[matched["response_latency_sec"] >= 0].copy()

    print(f"[Ljubljana]   Matched notification-response pairs: {len(matched):,}")

    # ── Build notification events ─────────────────────────────────────────
    # Use the POSTED timestamp as the event time (when the notification arrived)
    notif_events = pd.DataFrame({
        "timestamp": matched["posted_ts"].values / 1000.0,  # ms → seconds (Unix epoch)
        "user_id": USER_PREFIX_LJUBLJANA + "_" + matched["device_id"].astype(str),
        "event_type": EVENT_NOTIFICATION,
        "app_name": pd.NA,  # App name not available in this dataset
        "rssi": pd.NA,
        "response_latency_sec": matched["response_latency_sec"].values,
        "response_action": matched["action"].values,  # Extra: Clicked vs Removed
    })

    # ── Also create notification events for Posted-only (no response) ────
    # These contribute to notification frequency features even without latency
    unmatched_posted = posted[~posted["notification_id"].isin(matched["notification_id"])]
    posted_only_events = pd.DataFrame({
        "timestamp": unmatched_posted["posted_ts"].values / 1000.0,
        "user_id": USER_PREFIX_LJUBLJANA + "_" + unmatched_posted["device_id"].astype(str),
        "event_type": EVENT_NOTIFICATION,
        "app_name": pd.NA,
        "rssi": pd.NA,
        "response_latency_sec": pd.NA,  # No response recorded
        "response_action": pd.NA,
    })
    print(f"[Ljubljana]   Posted-only notifications (no response): {len(posted_only_events):,}")

    all_notif = pd.concat([notif_events, posted_only_events], ignore_index=True)

    # ── Load screen state for unlock events ───────────────────────────────
    print("[Ljubljana] Loading Screen.tab ...")
    screen = _load_tab(LJUBLJANA_SCREEN)
    print(f"[Ljubljana]   Screen state rows: {len(screen):,}")

    # Join screen state with notification timestamps
    # Screen.tab is keyed by (device_id, notification_id)
    # We need timestamps from Notifications.tab
    screen_with_ts = screen.merge(
        notif[["device_id", "notification_id", "date"]],
        on=["device_id", "notification_id"],
        how="inner",
    )

    # Keep only "Unlocked" — these indicate the phone was actively being used
    unlocked = screen_with_ts[screen_with_ts["screen"] == "Unlocked"].copy()
    print(f"[Ljubljana]   Unlocked screen events: {len(unlocked):,}")

    unlock_events = pd.DataFrame({
        "timestamp": unlocked["date"].values / 1000.0,
        "user_id": USER_PREFIX_LJUBLJANA + "_" + unlocked["device_id"].astype(str),
        "event_type": EVENT_UNLOCK,
        "app_name": pd.NA,
        "rssi": pd.NA,
        "response_latency_sec": pd.NA,
        "response_action": pd.NA,
    })

    combined = pd.concat([all_notif, unlock_events], ignore_index=True)

    # Drop the extra response_action column (not in unified schema)
    combined = combined.drop(columns=["response_action"], errors="ignore")

    # ── Derive time-of-day context ────────────────────────────────────────
    dt = pd.to_datetime(combined["timestamp"], unit="s", utc=True)
    combined["hour_of_day"] = dt.dt.hour.astype(np.int8)
    combined["day_of_week"] = dt.dt.dayofweek.astype(np.int8)

    # Cast nullable columns
    combined["rssi"] = combined["rssi"].astype("Int16")
    combined["response_latency_sec"] = combined["response_latency_sec"].astype("Float64")

    return combined


def load_ljubljana_bluetooth() -> pd.DataFrame:
    """
    Load Ljubljana Bluetooth context data → proximity events.

    NOTE: This dataset does NOT provide RSSI values for BT scans.
    We use "≥ 1 BT device detected at notification time" as a binary
    proximity signal. The rssi field is set to NA.

    Returns
    -------
    pd.DataFrame
        Unified schema rows for EVENT_PROXIMITY.
    """
    print("[Ljubljana] Loading Bluetooth.tab ...")
    bt = _load_tab(LJUBLJANA_BLUETOOTH)
    print(f"[Ljubljana]   Raw BT context rows: {len(bt):,}")

    # Each row = one BT device detected near one notification.
    # Deduplicate to one proximity event per (device_id, notification_id).
    bt_dedup = bt.drop_duplicates(subset=["device_id", "notification_id"])
    print(f"[Ljubljana]   Deduplicated BT proximity events: {len(bt_dedup):,}")

    # Need timestamps — join with Notifications.tab
    notif = _load_tab(LJUBLJANA_NOTIFICATIONS)
    bt_with_ts = bt_dedup.merge(
        notif[["device_id", "notification_id", "date"]],
        on=["device_id", "notification_id"],
        how="inner",
    )
    print(f"[Ljubljana]   BT events with timestamps: {len(bt_with_ts):,}")

    dt = pd.to_datetime(bt_with_ts["date"] / 1000.0, unit="s", utc=True)

    proximity_events = pd.DataFrame({
        "timestamp": bt_with_ts["date"].values / 1000.0,
        "user_id": USER_PREFIX_LJUBLJANA + "_" + bt_with_ts["device_id"].astype(str),
        "event_type": EVENT_PROXIMITY,
        "app_name": pd.NA,
        "rssi": pd.NA,  # No RSSI available in Ljubljana BT data
        "response_latency_sec": pd.NA,
        "hour_of_day": dt.dt.hour.values.astype(np.int8),
        "day_of_week": dt.dt.dayofweek.values.astype(np.int8),
    })

    proximity_events["rssi"] = proximity_events["rssi"].astype("Int16")
    proximity_events["response_latency_sec"] = proximity_events["response_latency_sec"].astype("Float64")

    print(f"[Ljubljana]   Output proximity rows: {len(proximity_events):,}")
    return proximity_events


def load_ljubljana_all() -> pd.DataFrame:
    """
    Load all Ljubljana data (notifications + unlock + proximity) and return
    a single unified-schema DataFrame.
    """
    notif_df = load_ljubljana_notifications()
    bt_df = load_ljubljana_bluetooth()

    combined = pd.concat([notif_df, bt_df], ignore_index=True)
    combined = combined.sort_values(["user_id", "timestamp"]).reset_index(drop=True)

    print(f"[Ljubljana] Combined events: {len(combined):,}")
    print(f"[Ljubljana] Unique users: {combined['user_id'].nunique()}")
    return combined


if __name__ == "__main__":
    df = load_ljubljana_all()
    print("\nSample output:")
    print(df.head(15).to_string())
    print("\nEvent type distribution:")
    print(df["event_type"].value_counts().to_string())

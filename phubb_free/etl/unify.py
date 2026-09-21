"""
ETL — Unifier: combine all three dataset ETL outputs into one events table.

METHODOLOGY NOTE:
    The three datasets (CNS, StudentLife, Ljubljana) are from DIFFERENT,
    NON-OVERLAPPING user populations. We are NOT claiming to merge them at
    the individual level.

    Each dataset independently models one signal type:
      - CNS → Bluetooth proximity patterns
      - StudentLife → unlock / app-switch baseline rhythms
      - Ljubljana → notification-triggered usage patterns

    The unified table concatenates all events with namespaced user IDs
    (cns_*, sl_*, lj_*) so that downstream feature engineering can compute
    per-user statistics within each population, and the combined feature
    space trains a single classifier that generalizes across signal types.
"""

import pandas as pd

from phubb_free.config import DATA_OUTPUT_DIR, UNIFIED_EVENTS_FILE


# ── Canonical column order and types ──────────────────────────────────────
UNIFIED_SCHEMA = {
    "timestamp": "float64",
    "user_id": "string",
    "event_type": "string",
    "app_name": "string",
    "rssi": "Int16",
    "response_latency_sec": "Float64",
    "hour_of_day": "int8",
    "day_of_week": "int8",
}


def unify_events(dataframes: list[pd.DataFrame]) -> pd.DataFrame:
    """
    Concatenate multiple unified-schema DataFrames, validate schema,
    deduplicate, sort, and return a single clean events table.

    Parameters
    ----------
    dataframes : list of pd.DataFrame
        Each must have the columns defined in UNIFIED_SCHEMA.

    Returns
    -------
    pd.DataFrame
        Combined, validated, sorted events table.
    """
    print("\n[Unify] Concatenating datasets ...")
    combined = pd.concat(dataframes, ignore_index=True)
    print(f"[Unify]   Total rows after concat: {len(combined):,}")

    # ── Schema validation ─────────────────────────────────────────────────
    expected_cols = set(UNIFIED_SCHEMA.keys())
    actual_cols = set(combined.columns)
    missing = expected_cols - actual_cols
    extra = actual_cols - expected_cols

    if missing:
        raise ValueError(f"[Unify] Missing columns: {missing}")
    if extra:
        print(f"[Unify]   Dropping unexpected columns: {extra}")
        combined = combined[list(UNIFIED_SCHEMA.keys())]

    # ── Enforce types ─────────────────────────────────────────────────────
    for col, dtype in UNIFIED_SCHEMA.items():
        try:
            combined[col] = combined[col].astype(dtype)
        except (TypeError, ValueError) as e:
            print(f"[Unify]   WARNING: Could not cast '{col}' to {dtype}: {e}")

    # ── Deduplicate ───────────────────────────────────────────────────────
    n_before = len(combined)
    combined = combined.drop_duplicates()
    n_dropped = n_before - len(combined)
    if n_dropped > 0:
        print(f"[Unify]   Dropped {n_dropped:,} duplicate rows")

    # ── Sort ──────────────────────────────────────────────────────────────
    combined = combined.sort_values(["user_id", "timestamp"]).reset_index(drop=True)

    # ── Summary ───────────────────────────────────────────────────────────
    print(f"\n[Unify] === Unified Events Summary ===")
    print(f"  Total events:  {len(combined):,}")
    print(f"  Unique users:  {combined['user_id'].nunique()}")
    print(f"  Event types:")
    for etype, count in combined["event_type"].value_counts().items():
        print(f"    {etype}: {count:,}")
    print(f"  Dataset breakdown (by user prefix):")
    combined["_prefix"] = combined["user_id"].str.split("_").str[0]
    for prefix, group in combined.groupby("_prefix"):
        print(f"    {prefix}: {len(group):,} events, {group['user_id'].nunique()} users")
    combined = combined.drop(columns=["_prefix"])

    return combined


def save_unified_events(df: pd.DataFrame, path=None) -> None:
    """Save the unified events table to Parquet."""
    path = path or UNIFIED_EVENTS_FILE
    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    df.to_parquet(str(path), index=False, engine="pyarrow")
    print(f"\n[Unify] Saved unified events to: {path}")
    print(f"  File size: {path.stat().st_size / 1024 / 1024:.1f} MB")

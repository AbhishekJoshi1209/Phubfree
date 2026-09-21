"""
Phubb-Free — Stage 1 Orchestrator: ETL → Unify → Feature Engineering.

Run this script to execute the complete Stage 1 pipeline:

    python -m phubb_free.run_stage1

Or:

    python phubb_free/run_stage1.py

Output files (in data/):
    - unified_events.parquet   — all events in unified schema
    - features_labeled.parquet — feature table with proxy phubbing labels

═══════════════════════════════════════════════════════════════════════════════
IMPORTANT METHODOLOGY REMINDERS (for coursework write-up / report):

1. The three datasets (CNS, StudentLife, Ljubljana) are from DIFFERENT,
   NON-OVERLAPPING user populations. We are NOT merging at the individual
   level. Each dataset independently models one signal type. The combined
   feature space trains a single downstream classifier.

2. The "phubbing" label is a CONSTRUCTED PROXY, not ground truth. A phone-
   interaction event during a Bluetooth co-presence window is the proxy
   positive label. This should be clearly documented as such in any report.

3. No raw behavioral data leaves this pipeline. All outputs are derived
   numeric features and binary labels — consistent with the project's
   privacy-first design constraint.
═══════════════════════════════════════════════════════════════════════════════
"""

import sys
import time
from pathlib import Path

# Ensure project root is on sys.path so script can be run directly or as a module
_PROJECT_ROOT = str(Path(__file__).resolve().parent.parent)
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

from phubb_free.etl.etl_cns import load_cns_proximity
from phubb_free.etl.etl_studentlife import load_studentlife_all
from phubb_free.etl.etl_ljubljana import load_ljubljana_all
from phubb_free.etl.unify import unify_events, save_unified_events
from phubb_free.features.feature_engineering import compute_all_features, save_features


def main():
    """Run the full Stage 1 pipeline."""
    print("=" * 72)
    print("  Phubb-Free -- Stage 1: ETL + Feature Engineering Pipeline")
    print("=" * 72)

    overall_start = time.time()

    # ══════════════════════════════════════════════════════════════════════
    # STEP 1: Run ETL for each dataset
    # ══════════════════════════════════════════════════════════════════════
    print("\n" + "-" * 72)
    print("  STEP 1/3: Extract-Transform-Load (ETL)")
    print("-" * 72)

    # 1a. Copenhagen Networks Study — proximity signal
    t0 = time.time()
    print("\n>> Dataset 1/3: Copenhagen Networks Study (CNS)")
    cns_df = load_cns_proximity()
    print(f"  [TIME] CNS ETL completed in {time.time() - t0:.1f}s")

    # 1b. Dartmouth StudentLife — unlock/app-switch + BT proximity
    t0 = time.time()
    print("\n>> Dataset 2/3: Dartmouth StudentLife")
    sl_df = load_studentlife_all()
    print(f"  [TIME] StudentLife ETL completed in {time.time() - t0:.1f}s")

    # 1c. Ljubljana — notifications + screen + BT context
    t0 = time.time()
    print("\n>> Dataset 3/3: University of Ljubljana Notifications")
    lj_df = load_ljubljana_all()
    print(f"  [TIME] Ljubljana ETL completed in {time.time() - t0:.1f}s")

    # ══════════════════════════════════════════════════════════════════════
    # STEP 2: Unify into a single events table
    # ══════════════════════════════════════════════════════════════════════
    print("\n" + "-" * 72)
    print("  STEP 2/3: Unify Events")
    print("-" * 72)

    t0 = time.time()
    unified = unify_events([cns_df, sl_df, lj_df])
    save_unified_events(unified)
    print(f"  [TIME] Unification completed in {time.time() - t0:.1f}s")

    # ══════════════════════════════════════════════════════════════════════
    # STEP 3: Feature engineering + proxy label construction
    # ══════════════════════════════════════════════════════════════════════
    print("\n" + "-" * 72)
    print("  STEP 3/3: Feature Engineering + Proxy Labeling")
    print("-" * 72)

    t0 = time.time()
    features = compute_all_features(unified)
    save_features(features)
    print(f"  [TIME] Feature engineering completed in {time.time() - t0:.1f}s")

    # ══════════════════════════════════════════════════════════════════════
    # VALIDATION REPORT
    # ══════════════════════════════════════════════════════════════════════
    print("\n" + "=" * 72)
    print("  VALIDATION REPORT")
    print("=" * 72)

    # Schema check
    expected_feature_cols = [
        "timestamp", "user_id", "event_type",
        "unlock_freq_1h", "app_switch_rate_1h",
        "notif_count_1h", "notif_resp_latency_mean_1h", "notif_resp_latency_median_1h",
        "proximity_flag", "proximity_density_1h",
        "hour_of_day", "day_of_week", "is_weekend",
        "phubbing",
    ]
    actual_cols = list(features.columns)
    schema_ok = actual_cols == expected_feature_cols
    print(f"\n  Schema validation: {'[PASS]' if schema_ok else '[FAIL]'}")
    if not schema_ok:
        print(f"    Expected: {expected_feature_cols}")
        print(f"    Got:      {actual_cols}")

    # Missing values
    print(f"\n  Missing values per column:")
    for col in features.columns:
        n_miss = features[col].isna().sum()
        pct = n_miss / len(features) * 100 if len(features) > 0 else 0
        if n_miss > 0:
            print(f"    {col}: {n_miss:,} ({pct:.1f}%)")

    # Class balance
    if "phubbing" in features.columns:
        vc = features["phubbing"].value_counts()
        print(f"\n  Proxy label distribution:")
        print(f"    phubbing=0 (no co-presence):  {vc.get(0, 0):,}")
        print(f"    phubbing=1 (co-presence):     {vc.get(1, 0):,}")
        ratio = vc.get(1, 0) / max(vc.get(0, 0), 1)
        print(f"    Imbalance ratio (1:0):        1:{1/ratio:.1f}" if ratio > 0 else "    No positive labels!")

    # Sample rows
    print(f"\n  Sample feature rows:")
    print(features.head(5).to_string())

    elapsed = time.time() - overall_start
    print(f"\n{'=' * 72}")
    print(f"  Stage 1 pipeline completed in {elapsed:.1f}s")
    print(f"{'=' * 72}")

    return features


if __name__ == "__main__":
    main()

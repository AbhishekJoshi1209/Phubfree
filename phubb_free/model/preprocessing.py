"""
Phubb-Free — Stage 2: Feature Preprocessing for Model Training.

Handles:
    - NaN imputation for notification-response latency features
    - Boolean → int casting
    - User-level stratified train/test splitting (no leakage)
    - StandardScaler fitting and persistence

IMPORTANT: The user-level split ensures that ALL events from a given user_id
appear in either the train set or the test set, never both. This prevents
information leakage from a user's temporal usage patterns.
"""

import numpy as np
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler
import joblib

from phubb_free.config import SCALER_FILE, MODELS_DIR

# ─── Feature columns used by the model ────────────────────────────────────────
# These are the numeric features the classifier trains on.
# Excludes: timestamp, user_id, event_type (identifiers, not features).
FEATURE_COLUMNS = [
    "unlock_freq_1h",
    "app_switch_rate_1h",
    "notif_count_1h",
    "notif_resp_latency_mean_1h",
    "notif_resp_latency_median_1h",
    "hour_of_day",
    "day_of_week",
    "is_weekend",
]

LABEL_COLUMN = "phubbing"

# Sentinel value for missing notification-response latency.
# This is NOT a data artifact — it's a meaningful signal: "no notification
# was responded to in this window." Using -1 rather than median imputation
# because "no notification" is semantically different from "average response."
LATENCY_SENTINEL = -1.0


def preprocess(
    df: pd.DataFrame,
    test_size: float = 0.2,
    random_state: int = 42,
) -> dict:
    """
    Preprocess the feature table for model training.

    Parameters
    ----------
    df : pd.DataFrame
        The features_labeled parquet loaded as a DataFrame.
    test_size : float
        Fraction of users to hold out for testing.
    random_state : int
        Random seed for reproducibility.

    Returns
    -------
    dict with keys:
        X_train, X_test       — scaled feature arrays (np.ndarray)
        y_train, y_test       — label arrays (np.ndarray)
        train_users, test_users — lists of user_ids in each split
        feature_names          — ordered list of feature column names
        scaler                 — the fitted StandardScaler
    """
    print("\n[Preprocessing] Starting feature preprocessing ...")

    # ── 1. Fill NaN in latency columns with sentinel ──────────────────────
    latency_cols = ["notif_resp_latency_mean_1h", "notif_resp_latency_median_1h"]
    n_nan_before = df[latency_cols].isna().sum().sum()
    df = df.copy()
    for col in latency_cols:
        df[col] = df[col].fillna(LATENCY_SENTINEL)
    print(f"[Preprocessing]   Filled {n_nan_before:,} NaN values in latency columns with sentinel={LATENCY_SENTINEL}")

    # ── 2. Cast booleans to int ───────────────────────────────────────────
    for col in ["proximity_flag", "is_weekend"]:
        df[col] = df[col].astype(int)

    # ── 3. User-level train/test split ────────────────────────────────────
    # GroupShuffleSplit ensures ALL events from a given user_id go to the
    # same set. This prevents temporal information leakage.
    groups = df["user_id"].values
    gss = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
    train_idx, test_idx = next(gss.split(df, groups=groups))

    train_df = df.iloc[train_idx]
    test_df = df.iloc[test_idx]

    train_users = sorted(train_df["user_id"].unique().tolist())
    test_users = sorted(test_df["user_id"].unique().tolist())

    # Verify no user leakage
    overlap = set(train_users) & set(test_users)
    assert len(overlap) == 0, f"User leakage detected! Overlapping users: {overlap}"

    print(f"[Preprocessing]   Train: {len(train_df):,} events from {len(train_users)} users")
    print(f"[Preprocessing]   Test:  {len(test_df):,} events from {len(test_users)} users")
    print(f"[Preprocessing]   User leakage check: PASSED (0 overlapping users)")

    # ── 4. Extract feature matrices and labels ────────────────────────────
    X_train = train_df[FEATURE_COLUMNS].values.astype(np.float64)
    X_test = test_df[FEATURE_COLUMNS].values.astype(np.float64)
    y_train = train_df[LABEL_COLUMN].values.astype(np.int32)
    y_test = test_df[LABEL_COLUMN].values.astype(np.int32)

    print(f"[Preprocessing]   Train label dist: 0={np.sum(y_train == 0):,}, 1={np.sum(y_train == 1):,} "
          f"({np.mean(y_train) * 100:.1f}% positive)")
    print(f"[Preprocessing]   Test label dist:  0={np.sum(y_test == 0):,}, 1={np.sum(y_test == 1):,} "
          f"({np.mean(y_test) * 100:.1f}% positive)")

    # ── 5. Fit StandardScaler on training data only ───────────────────────
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)

    print(f"[Preprocessing]   StandardScaler fitted on train data ({len(FEATURE_COLUMNS)} features)")

    # ── 6. Save scaler for downstream use (on-device inference) ───────────
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(scaler, str(SCALER_FILE))
    print(f"[Preprocessing]   Scaler saved to: {SCALER_FILE}")

    return {
        "X_train": X_train,
        "X_test": X_test,
        "y_train": y_train,
        "y_test": y_test,
        "train_users": train_users,
        "test_users": test_users,
        "feature_names": FEATURE_COLUMNS,
        "scaler": scaler,
    }

"""
Tests for Phubb-Free Stage 2: Preprocessing, Training, TFLite Export.

Tests cover:
    1. Preprocessing — NaN fill, user-level split, scaler
    2. Model training — runs without error on synthetic data
    3. User leakage — no user appears in both train and test
"""

import numpy as np
import pandas as pd
import pytest

from phubb_free.model.preprocessing import (
    preprocess,
    FEATURE_COLUMNS,
    LABEL_COLUMN,
    LATENCY_SENTINEL,
)


# ─── Fixtures ─────────────────────────────────────────────────────────────────

def _make_synthetic_feature_df(n_users: int = 10, events_per_user: int = 50) -> pd.DataFrame:
    """
    Create a synthetic DataFrame mimicking the features_labeled.parquet schema.
    """
    rng = np.random.RandomState(42)
    rows = []
    for u in range(n_users):
        for _ in range(events_per_user):
            row = {
                "timestamp": 1.5e9 + rng.randint(0, 86400 * 30),
                "user_id": f"test_user_{u:03d}",
                "event_type": rng.choice(["unlock", "app_switch", "notification"]),
                "unlock_freq_1h": rng.randint(0, 30),
                "app_switch_rate_1h": rng.randint(0, 10),
                "notif_count_1h": rng.randint(0, 20),
                "notif_resp_latency_mean_1h": rng.choice([np.nan, rng.uniform(10, 500)]),
                "notif_resp_latency_median_1h": rng.choice([np.nan, rng.uniform(5, 300)]),
                "proximity_flag": rng.choice([True, False]),
                "proximity_density_1h": rng.randint(0, 15),
                "hour_of_day": rng.randint(0, 24),
                "day_of_week": rng.randint(0, 7),
                "is_weekend": rng.choice([True, False]),
                "phubbing": rng.choice([0, 1]),
            }
            rows.append(row)
    return pd.DataFrame(rows)


@pytest.fixture
def synthetic_df():
    return _make_synthetic_feature_df()


# ─── Preprocessing Tests ─────────────────────────────────────────────────────

class TestPreprocessing:
    """Test the preprocessing pipeline."""

    def test_nan_filled_with_sentinel(self, synthetic_df):
        """NaN latency values should be filled with the sentinel value."""
        result = preprocess(synthetic_df)
        X_train = result["X_train"]
        X_test = result["X_test"]
        # No NaN should remain
        assert not np.any(np.isnan(X_train)), "Train data contains NaN after preprocessing"
        assert not np.any(np.isnan(X_test)), "Test data contains NaN after preprocessing"

    def test_user_level_split_no_leakage(self, synthetic_df):
        """No user_id should appear in both train and test sets."""
        result = preprocess(synthetic_df)
        train_users = set(result["train_users"])
        test_users = set(result["test_users"])
        overlap = train_users & test_users
        assert len(overlap) == 0, f"User leakage! Users in both sets: {overlap}"

    def test_all_users_accounted_for(self, synthetic_df):
        """Every user should end up in either train or test."""
        result = preprocess(synthetic_df)
        all_users = set(synthetic_df["user_id"].unique())
        split_users = set(result["train_users"]) | set(result["test_users"])
        assert all_users == split_users, "Some users are missing from the split"

    def test_feature_count_matches(self, synthetic_df):
        """Output feature count should match FEATURE_COLUMNS."""
        result = preprocess(synthetic_df)
        assert result["X_train"].shape[1] == len(FEATURE_COLUMNS)
        assert result["X_test"].shape[1] == len(FEATURE_COLUMNS)

    def test_scaler_is_fitted(self, synthetic_df):
        """The scaler should be fitted (have mean_ and scale_ attributes)."""
        result = preprocess(synthetic_df)
        scaler = result["scaler"]
        assert hasattr(scaler, "mean_"), "Scaler not fitted (no mean_)"
        assert hasattr(scaler, "scale_"), "Scaler not fitted (no scale_)"
        assert len(scaler.mean_) == len(FEATURE_COLUMNS)

    def test_train_test_sizes_reasonable(self, synthetic_df):
        """Train should be ~80% and test ~20% of data."""
        result = preprocess(synthetic_df, test_size=0.2)
        total = len(result["X_train"]) + len(result["X_test"])
        test_frac = len(result["X_test"]) / total
        # Allow some slack since it's user-level split
        assert 0.05 < test_frac < 0.5, f"Test fraction {test_frac:.2f} seems off"

    def test_labels_are_binary(self, synthetic_df):
        """Labels should only contain 0 and 1."""
        result = preprocess(synthetic_df)
        unique_train = set(np.unique(result["y_train"]))
        unique_test = set(np.unique(result["y_test"]))
        assert unique_train.issubset({0, 1}), f"Unexpected train labels: {unique_train}"
        assert unique_test.issubset({0, 1}), f"Unexpected test labels: {unique_test}"


# ─── Model Training Tests ────────────────────────────────────────────────────

class TestModelTraining:
    """Test that models train without error on synthetic data."""

    def test_logistic_regression_trains(self, synthetic_df):
        """LR should train successfully on preprocessed data."""
        from sklearn.linear_model import LogisticRegression

        result = preprocess(synthetic_df)
        model = LogisticRegression(max_iter=100, random_state=42)
        model.fit(result["X_train"], result["y_train"])

        # Should produce valid predictions
        preds = model.predict(result["X_test"])
        assert len(preds) == len(result["y_test"])
        assert set(np.unique(preds)).issubset({0, 1})

    def test_gbt_trains(self, synthetic_df):
        """HistGradientBoostingClassifier should train successfully."""
        from sklearn.ensemble import HistGradientBoostingClassifier

        result = preprocess(synthetic_df)
        model = HistGradientBoostingClassifier(
            max_iter=10, max_depth=3, random_state=42
        )
        model.fit(result["X_train"], result["y_train"])

        preds = model.predict(result["X_test"])
        assert len(preds) == len(result["y_test"])

    def test_predict_proba_valid_range(self, synthetic_df):
        """predict_proba outputs should be in [0, 1]."""
        from sklearn.linear_model import LogisticRegression

        result = preprocess(synthetic_df)
        model = LogisticRegression(max_iter=100, random_state=42)
        model.fit(result["X_train"], result["y_train"])

        proba = model.predict_proba(result["X_test"])
        assert np.all(proba >= 0) and np.all(proba <= 1), "Probabilities out of range"
        # Should sum to ~1 per row
        row_sums = proba.sum(axis=1)
        np.testing.assert_allclose(row_sums, 1.0, atol=1e-6)

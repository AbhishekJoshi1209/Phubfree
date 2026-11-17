"""Tests for phubb_free.export_app_assets."""

import json

import joblib
import numpy as np
import pytest
from sklearn.linear_model import LogisticRegression

from phubb_free.export_app_assets import export_app_assets
from phubb_free.model.preprocessing import LATENCY_SENTINEL


@pytest.fixture
def model_dir(tmp_path):
    rng = np.random.default_rng(0)
    X = rng.normal(size=(50, 3))
    y = (X[:, 0] > 0).astype(int)
    model = LogisticRegression().fit(X, y)
    joblib.dump(model, tmp_path / "best_model.joblib")
    (tmp_path / "model_metadata.json").write_text(json.dumps({
        "feature_names": ["a", "b", "c"],
        "scaler_mean": [0.0, 0.0, 0.0],
        "scaler_scale": [1.0, 1.0, 1.0],
        "default_threshold": 0.5,
    }))
    (tmp_path / "phubbing_detector.tflite").write_bytes(b"TFL3")
    return tmp_path, model


def _export(tmp_path):
    return export_app_assets(
        metadata_file=tmp_path / "model_metadata.json",
        tflite_file=tmp_path / "phubbing_detector.tflite",
        model_file=tmp_path / "best_model.joblib",
        assets_dir=tmp_path / "app_assets",
    )


def test_backfills_weights_and_copies_identical_files(model_dir):
    tmp_path, model = model_dir
    dest = _export(tmp_path)

    src = (tmp_path / "model_metadata.json").read_bytes()
    assert (dest / "model_metadata.json").read_bytes() == src
    assert (dest / "phubbing_detector.tflite").read_bytes() == b"TFL3"

    meta = json.loads(src)
    np.testing.assert_allclose(meta["weights"], model.coef_.ravel())
    assert meta["bias"] == pytest.approx(float(model.intercept_[0]))
    assert meta["latency_sentinel"] == LATENCY_SENTINEL


def test_rejects_dimension_mismatch(model_dir):
    tmp_path, _ = model_dir
    meta_file = tmp_path / "model_metadata.json"
    meta = json.loads(meta_file.read_text())
    meta["scaler_mean"] = [0.0, 0.0]
    meta_file.write_text(json.dumps(meta))
    with pytest.raises(ValueError, match="scaler_mean"):
        _export(tmp_path)

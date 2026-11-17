"""
Export the trained model into the Flutter app's assets.

    python -m phubb_free.export_app_assets

1. Ensures ``models/model_metadata.json`` carries the logistic-regression
   ``weights``, ``bias`` and ``latency_sentinel`` the app needs for pure-Dart
   inference (backfilled from ``best_model.joblib`` if Stage 2 predates them).
2. Copies ``model_metadata.json`` and ``phubbing_detector.tflite`` into
   ``phubb_free_app/assets/models/`` so the two copies can never drift apart.
   Never hand-edit the copies in the app; re-run this script instead.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from phubb_free.config import (
    MODEL_METADATA_FILE,
    PROJECT_ROOT,
    SKLEARN_BEST_MODEL_FILE,
    TFLITE_MODEL_FILE,
)
from phubb_free.model.preprocessing import LATENCY_SENTINEL

APP_ASSETS_DIR = PROJECT_ROOT / "phubb_free_app" / "assets" / "models"


def ensure_inference_params(metadata: dict, model_file: Path) -> dict:
    """Return metadata with weights/bias/latency_sentinel filled in."""
    out = dict(metadata)
    if "weights" not in out or "bias" not in out:
        import joblib

        model = joblib.load(model_file)
        if not hasattr(model, "coef_"):
            raise ValueError(
                f"{model_file.name} is not a linear model; the app's pure-Dart "
                "inference only supports logistic regression."
            )
        out["weights"] = model.coef_.ravel().tolist()
        out["bias"] = float(model.intercept_.ravel()[0])
    out["latency_sentinel"] = LATENCY_SENTINEL

    n = len(out["feature_names"])
    for key in ("weights", "scaler_mean", "scaler_scale"):
        if len(out[key]) != n:
            raise ValueError(f"{key} has {len(out[key])} values, expected {n}")
    return out


def export_app_assets(
    metadata_file: Path = MODEL_METADATA_FILE,
    tflite_file: Path = TFLITE_MODEL_FILE,
    model_file: Path = SKLEARN_BEST_MODEL_FILE,
    assets_dir: Path = APP_ASSETS_DIR,
) -> Path:
    metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
    metadata = ensure_inference_params(metadata, model_file)
    metadata_file.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    assets_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(metadata_file, assets_dir / metadata_file.name)
    shutil.copyfile(tflite_file, assets_dir / tflite_file.name)
    return assets_dir


def main() -> None:
    dest = export_app_assets()
    print(f"[Export] Model metadata + TFLite copied to {dest}")


if __name__ == "__main__":
    main()

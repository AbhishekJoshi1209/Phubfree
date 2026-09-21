"""
Phubb-Free - Stage 2 Orchestrator: Preprocess → Train → Evaluate → Export.

Run this script to execute the complete Stage 2 pipeline:

    python -m phubb_free.run_stage2

Or:

    python phubb_free/run_stage2.py

Prerequisites:
    - Stage 1 must have been run first (produces data/features_labeled.parquet)

Output files (in models/):
    - logistic_regression.joblib        - Trained LR model
    - gradient_boosted_trees.joblib     - Trained GBT model
    - best_model.joblib                 - Copy of selected best model
    - scaler.joblib                     - StandardScaler for feature normalization
    - phubbing_detector.tflite          - TFLite model for on-device inference
    - model_metadata.json               - Feature names, scaler params, threshold
    - evaluation_report.txt             - Full classification reports
    - confusion_matrix.png              - Confusion matrix heatmap
    - roc_curve.png                     - ROC curves comparison
    - feature_importance.png            - Feature importance chart

═══════════════════════════════════════════════════════════════════════════════
IMPORTANT - PROXY LABEL CAVEAT:
All evaluation metrics measure performance against a CONSTRUCTED PROXY label
(phone-interaction during BT co-presence = "phubbing moment"). This is NOT
ground-truth phubbing. The model is a reasonable starting point for on-device
personalization - not a definitive phubbing detector.
═══════════════════════════════════════════════════════════════════════════════
"""

import sys
import time
from pathlib import Path

# Ensure project root is on sys.path so script can be run directly or as a module
_PROJECT_ROOT = str(Path(__file__).resolve().parent.parent)
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

import pandas as pd

from phubb_free.config import FEATURES_LABELED_FILE, MODELS_DIR
from phubb_free.model.preprocessing import preprocess
from phubb_free.model.train import train_and_evaluate
from phubb_free.model.export_tflite import export_to_tflite


def main():
    """Run the full Stage 2 pipeline."""
    print("=" * 72)
    print("  Phubb-Free - Stage 2: Model Training, Evaluation & TFLite Export")
    print("=" * 72)

    overall_start = time.time()

    # ══════════════════════════════════════════════════════════════════════
    # STEP 1: Load Stage 1 output
    # ══════════════════════════════════════════════════════════════════════
    print(f"\n{'-' * 72}")
    print("  STEP 1/4: Load Feature Table")
    print(f"{'-' * 72}")

    if not FEATURES_LABELED_FILE.exists():
        print(f"[ERROR] Feature file not found: {FEATURES_LABELED_FILE}")
        print("  → Run Stage 1 first: python -m phubb_free.run_stage1")
        sys.exit(1)

    df = pd.read_parquet(str(FEATURES_LABELED_FILE))
    print(f"[Load] Loaded {len(df):,} rows x {len(df.columns)} columns from {FEATURES_LABELED_FILE}")
    print(f"[Load] Users: {df['user_id'].nunique()}, Phubbing rate: {df['phubbing'].mean() * 100:.1f}%")

    # ══════════════════════════════════════════════════════════════════════
    # STEP 2: Preprocess features
    # ══════════════════════════════════════════════════════════════════════
    print(f"\n{'-' * 72}")
    print("  STEP 2/4: Preprocess Features")
    print(f"{'-' * 72}")

    t0 = time.time()
    preprocessed = preprocess(df)
    print(f"  [TIME] Preprocessing completed in {time.time() - t0:.1f}s")

    # ══════════════════════════════════════════════════════════════════════
    # STEP 3: Train, evaluate, and select best model
    # ══════════════════════════════════════════════════════════════════════
    print(f"\n{'-' * 72}")
    print("  STEP 3/4: Train & Evaluate Models")
    print(f"{'-' * 72}")

    t0 = time.time()
    results = train_and_evaluate(preprocessed)
    print(f"  [TIME] Training + evaluation completed in {time.time() - t0:.1f}s")

    # ══════════════════════════════════════════════════════════════════════
    # STEP 4: Export best model to TFLite
    # ══════════════════════════════════════════════════════════════════════
    print(f"\n{'-' * 72}")
    print("  STEP 4/4: Export to TensorFlow Lite")
    print(f"{'-' * 72}")

    t0 = time.time()
    export_to_tflite(
        best_model=results["best_model"],
        best_model_name=results["best_model_name"],
        X_test=preprocessed["X_test"],
        feature_names=preprocessed["feature_names"],
    )
    print(f"  [TIME] TFLite export completed in {time.time() - t0:.1f}s")

    # ══════════════════════════════════════════════════════════════════════
    # FINAL SUMMARY
    # ══════════════════════════════════════════════════════════════════════
    elapsed = time.time() - overall_start

    print(f"\n{'=' * 72}")
    print("  STAGE 2 - FINAL SUMMARY")
    print(f"{'=' * 72}")
    print(f"  * Selected model:  {results['best_model_name']}")
    print(f"  * LR  metrics:     F1={results['metrics_lr']['f1']:.4f}, AUC={results['metrics_lr']['auc_roc']:.4f}")
    print(f"  * GBT metrics:     F1={results['metrics_gbt']['f1']:.4f}, AUC={results['metrics_gbt']['auc_roc']:.4f}")
    print(f"\n  Output files in {MODELS_DIR}/:")

    if MODELS_DIR.exists():
        for f in sorted(MODELS_DIR.iterdir()):
            size = f.stat().st_size
            if size > 1024 * 1024:
                size_str = f"{size / 1024 / 1024:.1f} MB"
            elif size > 1024:
                size_str = f"{size / 1024:.1f} KB"
            else:
                size_str = f"{size} B"
            print(f"    {f.name:40s} {size_str:>10s}")

    print(f"\n  Total time: {elapsed:.1f}s")
    print(f"{'=' * 72}")
    print("  *** REMINDER: All metrics are against a CONSTRUCTED PROXY LABEL ***")
    print(f"{'=' * 72}")

    return results


if __name__ == "__main__":
    main()

"""
Phubb-Free — Centralized configuration: dataset paths, constants, thresholds.

All paths are relative to the project root (the parent of this package).
"""

from pathlib import Path

# ─── Project root ────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent

# ─── Raw dataset paths ───────────────────────────────────────────────────────
DATASETS_DIR = PROJECT_ROOT / "datasets"

# 1. Copenhagen Networks Study (CNS)
#    700+ university students, 4 weeks, BT proximity at 5-min resolution.
#    Columns: timestamp (relative seconds), user_a, user_b, rssi
#    user_b == -1 → empty scan; user_b == -2 → non-experiment device
CNS_DIR = DATASETS_DIR / "01_copenhagen_networks" / "7267433"
CNS_BT_FILE = CNS_DIR / "bt_symmetric.csv"

# 2. Dartmouth StudentLife
#    48 students, 10 weeks, passive phone sensing.
#    phonelock.Rds: start_timestamp, end_timestamp, uid (Unix epoch seconds)
#    bluetooth.Rds: timestamp, MAC, class_id, level (RSSI), uid
STUDENTLIFE_DIR = DATASETS_DIR / "02_studentlife_dartmouth" / "dataset_rds" / "dataset_rds"
STUDENTLIFE_SENSING_DIR = STUDENTLIFE_DIR / "sensing"
STUDENTLIFE_PHONELOCK = STUDENTLIFE_SENSING_DIR / "phonelock.Rds"
STUDENTLIFE_BLUETOOTH = STUDENTLIFE_SENSING_DIR / "bluetooth.Rds"

# 3. University of Ljubljana Notification Behaviour Dataset
#    19 users, 2 weeks, notification arrival/response/context data.
#    Notifications.tab: device_id, notification_id, notification_from, date (ms), action
#    Screen.tab: device_id, notification_id, screen (Locked/Unlocked)
#    Bluetooth.tab: device_id, notification_id, name
LJUBLJANA_DIR = DATASETS_DIR / "03_notification_context" / "notif-context-dataset-master" / "data"
LJUBLJANA_NOTIFICATIONS = LJUBLJANA_DIR / "Notifications.tab"
LJUBLJANA_SCREEN = LJUBLJANA_DIR / "Screen.tab"
LJUBLJANA_BLUETOOTH = LJUBLJANA_DIR / "Bluetooth.tab"

# ─── Output paths ────────────────────────────────────────────────────────────
DATA_OUTPUT_DIR = PROJECT_ROOT / "data"
UNIFIED_EVENTS_FILE = DATA_OUTPUT_DIR / "unified_events.parquet"
FEATURES_LABELED_FILE = DATA_OUTPUT_DIR / "features_labeled.parquet"

# ─── Stage 2: Model output paths ─────────────────────────────────────────────
MODELS_DIR = PROJECT_ROOT / "models"
SKLEARN_LR_MODEL_FILE = MODELS_DIR / "logistic_regression.joblib"
SKLEARN_GBT_MODEL_FILE = MODELS_DIR / "gradient_boosted_trees.joblib"
SKLEARN_BEST_MODEL_FILE = MODELS_DIR / "best_model.joblib"
SCALER_FILE = MODELS_DIR / "scaler.joblib"
TFLITE_MODEL_FILE = MODELS_DIR / "phubbing_detector.tflite"
MODEL_METADATA_FILE = MODELS_DIR / "model_metadata.json"
EVALUATION_REPORT_FILE = MODELS_DIR / "evaluation_report.txt"

# ─── Signal processing constants ─────────────────────────────────────────────

# RSSI threshold for "co-presence": a Bluetooth signal ≥ this value (closer to 0
# = stronger signal) indicates another person is physically nearby.
# -75 dBm is approximately 1-3 meters depending on device/environment.
RSSI_COPRESENCE_THRESHOLD = -75  # dBm

# Rolling feature window size (seconds).
FEATURE_WINDOW_SEC = 3600  # 1 hour

# Rapid-unlock threshold: two consecutive unlock sessions starting within this
# many seconds are treated as an "app_switch" proxy event, since no dataset
# provides direct app-switch logs.
APP_SWITCH_GAP_THRESHOLD_SEC = 30

# ─── User-ID namespace prefixes ──────────────────────────────────────────────
# Each dataset's users get a unique prefix to prevent ID collision when
# the three populations are combined into one feature table.
# These are SEPARATE populations — we are NOT merging at the individual level.
USER_PREFIX_CNS = "cns"
USER_PREFIX_STUDENTLIFE = "sl"
USER_PREFIX_LJUBLJANA = "lj"

# ─── Unified event types ─────────────────────────────────────────────────────
EVENT_UNLOCK = "unlock"
EVENT_APP_SWITCH = "app_switch"
EVENT_NOTIFICATION = "notification"
EVENT_PROXIMITY = "proximity"

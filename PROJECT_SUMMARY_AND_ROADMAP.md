# Phubb-Free — Complete Project Summary & Continuation Guide

> **Purpose of this document:** This is a comprehensive, copy-pasteable handoff document for any AI or developer to understand the entire Phubb-Free project, its current state, architecture, every implemented component, and all remaining work. Read this fully before making any changes.

---

## 1. PROJECT OVERVIEW

**Phubb-Free** is a **privacy-first, on-device AI system** that detects and reduces **"phubbing"** (phone-snubbing) during real-life social interactions. It passively monitors phone usage patterns and delivers gentle behavioral nudges when it predicts the user is ignoring someone physically nearby in favor of their phone.

### Core Design Principles
- **100% On-Device:** All data processing, ML inference, and personalization happen locally. Zero cloud uploads.
- **Personalized AI:** Learns what "normal" phone usage looks like for each specific user (not a one-size-fits-all rule).
- **Lightweight:** Uses a custom-exported TFLite model (732 bytes) for continuous inference without battery drain.
- **Proxy Label Methodology:** Since "phubbing" is subjective and no ground-truth dataset exists, the system uses a **constructed proxy label**: any phone interaction (unlock, app switch, notification response) occurring while another person's Bluetooth signal is detected nearby. This is documented as a proxy, not ground truth, throughout the entire codebase.

### Tech Stack
- **ML Pipeline:** Python 3.12+, pandas, scikit-learn, pyarrow, pyreadr, flatbuffers, matplotlib, seaborn
- **Mobile App:** Flutter (Dart), SDK ^3.13.4
- **State Management:** Provider (ChangeNotifier pattern)
- **Charts:** fl_chart ^0.70.2
- **Persistence:** shared_preferences ^2.3.4
- **Fonts:** Google Fonts (Fraunces serif + Inter sans-serif)
- **Model Format:** TensorFlow Lite flatbuffer (custom pure-Python exporter, no TF C++ runtime needed)

---

## 2. PROJECT ARCHITECTURE — 4 STAGES

```
Stage 1: Data Engineering ✅ COMPLETE
Stage 2: AI Model Training ✅ COMPLETE
Stage 3: Mobile App Interface ⚠️ PARTIALLY COMPLETE (UI done, real sensors NOT wired)
Stage 4: On-Device Personalization ❌ NOT STARTED
```

---

## 3. REPOSITORY STRUCTURE

```
Phubfree/
├── .gitignore
├── README.md
├── .vscode/settings.json
│
├── datasets/                          # Raw data (gitignored, ~2GB total)
│   ├── 01_copenhagen_networks/        # CNS: 700+ students, BT proximity
│   ├── 02_studentlife_dartmouth/      # StudentLife: 48 students, phone sensing
│   └── 03_notification_context/       # Ljubljana: 19 users, notification behavior
│
├── data/                              # Processed outputs (tracked in git)
│   ├── unified_events.parquet         # Stage 1 output: all events, unified schema
│   └── features_labeled.parquet       # Stage 1 output: feature table + proxy labels
│
├── models/                            # Stage 2 outputs (tracked in git)
│   ├── best_model.joblib              # Selected model (LR, 895B)
│   ├── logistic_regression.joblib     # LR sklearn model (895B)
│   ├── gradient_boosted_trees.joblib  # GBT sklearn model (731KB)
│   ├── scaler.joblib                  # StandardScaler (807B)
│   ├── phubbing_detector.tflite       # TFLite flatbuffer (732B)
│   ├── model_metadata.json            # Feature names, scaler params, weights, bias
│   ├── evaluation_report.txt          # Full classification metrics
│   ├── confusion_matrix.png           # Side-by-side confusion matrices
│   ├── roc_curve.png                  # ROC curves comparison
│   └── feature_importance.png         # LR coefficient analysis
│
├── phubb_free/                        # Python ML pipeline package
│   ├── __init__.py
│   ├── config.py                      # Centralized paths, constants, thresholds
│   ├── run_stage1.py                  # Stage 1 orchestrator
│   ├── run_stage2.py                  # Stage 2 orchestrator
│   ├── etl/
│   │   ├── __init__.py
│   │   ├── etl_cns.py                # Copenhagen Networks Study ETL
│   │   ├── etl_studentlife.py         # Dartmouth StudentLife ETL
│   │   ├── etl_ljubljana.py           # Ljubljana Notifications ETL
│   │   └── unify.py                   # Merge all 3 datasets into unified schema
│   ├── features/
│   │   ├── __init__.py
│   │   └── feature_engineering.py     # Rolling window features + proxy label
│   └── model/
│       ├── __init__.py
│       ├── preprocessing.py           # NaN fill, user-level split, StandardScaler
│       ├── train.py                   # LR + GBT training, evaluation, plots
│       └── export_tflite.py           # Custom pure-Python TFLite flatbuffer builder
│
├── tests/                             # Python test suite
│   ├── __init__.py
│   ├── test_config.py
│   ├── test_data_validation.py
│   ├── test_features.py
│   ├── test_model.py
│   └── test_unify.py
│
└── phubb_free_app/                    # Flutter mobile application
    ├── pubspec.yaml
    ├── assets/
    │   └── models/
    │       ├── phubbing_detector.tflite    # Copied from models/
    │       └── model_metadata.json         # Includes weights, bias, scaler params
    └── lib/
        ├── main.dart                       # App entry, MultiProvider setup
        ├── data/
        │   ├── phub_event.dart             # PhubEvent, PhubEventType, DaySummary, AppSocialUsage
        │   └── phubbing_repository.dart    # Mock data source (generates fake events)
        ├── models/
        │   └── sensor_event.dart           # SensorEvent, SensorEventType (legacy/unused)
        ├── screens/
        │   ├── app_shell.dart              # Bottom nav with IndexedStack
        │   ├── home_screen.dart            # Hero number, 7-day chart, metrics, activity feed
        │   ├── insights_screen.dart        # 7/30-day charts, trend, top apps
        │   ├── onboarding_screen.dart      # 3-page permission walkthrough
        │   └── settings_screen.dart        # Theme, sensitivity, nudge style, quiet hours, whitelist
        ├── services/
        │   ├── mock_sensor_feed.dart        # Legacy mock sensor stream
        │   ├── nudge_service.dart           # Nudge delivery (haptic, overlay), cooldown, quiet hours
        │   ├── permission_service.dart      # Mock permission grants
        │   ├── phub_inference_service.dart   # Pure-Dart LR inference (loads model_metadata.json)
        │   └── rolling_window_aggregator.dart # 1-hour sliding window → 8-feature vector
        ├── state/
        │   ├── settings_controller.dart     # All user prefs with SharedPreferences persistence
        │   └── theme_controller.dart        # System/Light/Dark theme with persistence
        ├── theme/
        │   ├── app_colors.dart              # "Moss & Stone" palette (light + dark)
        │   ├── app_spacing.dart             # 4/8-grid spacing tokens
        │   ├── app_text_styles.dart         # Fraunces serif + Inter sans typography
        │   └── app_theme.dart               # Full ThemeData builder
        ├── ui/                              # ⚠️ LEGACY — older UI prototype (not used in main app)
        │   ├── theme.dart                   # Old neon dark theme
        │   └── screens/
        │       ├── home_screen.dart         # Old mock-sensor home screen
        │       └── permissions_screen.dart  # Old permissions screen
        └── widgets/
            ├── nudge_overlay.dart           # Slide-down animated nudge banner
            └── shared_widgets.dart          # MetricCard, StatusTag, SectionHeader, PrivacyBadge, EmptyState
```

---

## 4. STAGE 1 — DATA ENGINEERING (✅ COMPLETE)

### What it does
Transforms three raw smartphone telemetry datasets into a unified feature table with a proxy phubbing label.

### Three Datasets (SEPARATE populations, NOT merged at individual level)

| Dataset | Source | Users | Duration | Signal Type | File Format |
|---------|--------|-------|----------|-------------|-------------|
| **Copenhagen Networks Study (CNS)** | figshare.com/7267433 | 700+ students | 4 weeks | BT proximity (user-to-user, 5-min epochs) | CSV (bt_symmetric.csv, ~98MB) |
| **Dartmouth StudentLife** | studentlife.cs.dartmouth.edu | 48 students | 10 weeks | Phone lock/unlock + BT proximity | .Rds (phonelock.Rds, bluetooth.Rds) |
| **University of Ljubljana** | gitlab.fri.uni-lj.si | 19 users | 2 weeks | Notification arrival/response + screen state + BT | Tab-delimited (.tab) |

### Unified Event Schema
All datasets are transformed to this schema before concatenation:
```
timestamp: float64 (Unix epoch seconds, or relative for CNS)
user_id: string (prefixed: "cns_*", "sl_*", "lj_*")
event_type: string ("unlock", "app_switch", "notification", "proximity")
app_name: string (nullable)
rssi: Int16 (nullable, dBm)
response_latency_sec: Float64 (nullable, seconds)
hour_of_day: int8 (0-23)
day_of_week: int8 (0-6, Monday=0)
```

### Key ETL Logic
- **CNS:** Filters user_b >= 0 (valid scans only), applies RSSI >= -75 dBm threshold, derives hour/day from relative timestamps (assumes t=0 = midnight).
- **StudentLife:** Reads .Rds via pyreadr. Unlock events from phonelock.Rds. App-switch proxy: two unlocks < 30s apart. BT proximity: deduplicates per (user, timestamp), keeps max RSSI.
- **Ljubljana:** Computes response latency by joining Posted→Clicked/Removed via notification_from FK. Filters negative latencies (clock skew). Screen "Unlocked" state = unlock event. BT proximity is binary (no RSSI available).

### Feature Engineering (10 features + 1 proxy label)
Computed per-user with 1-hour rolling windows:

| Feature | Description |
|---------|-------------|
| `unlock_freq_1h` | Count of unlock events in trailing 1-hour window |
| `app_switch_rate_1h` | Count of app-switch events in trailing 1-hour window |
| `notif_count_1h` | Count of notification events in trailing 1-hour window |
| `notif_resp_latency_mean_1h` | Mean notification response latency (sec) in window |
| `notif_resp_latency_median_1h` | Median notification response latency (sec) in window |
| `proximity_flag` | Boolean: any proximity event within ±10 min of this event |
| `proximity_density_1h` | Count of proximity events in trailing 1-hour window |
| `hour_of_day` | 0-23 |
| `day_of_week` | 0-6 (Monday=0) |
| `is_weekend` | Boolean (Saturday=5, Sunday=6) |
| **`phubbing`** | **PROXY LABEL: 1 if phone-interaction during BT co-presence, else 0** |

### Output Files
- `data/unified_events.parquet` — All events in unified schema
- `data/features_labeled.parquet` — Feature table with proxy labels

### How to Run
```bash
python -m phubb_free.run_stage1
```

---

## 5. STAGE 2 — MODEL TRAINING (✅ COMPLETE)

### Pipeline Steps
1. **Load** `features_labeled.parquet`
2. **Preprocess:** NaN fill latency columns with sentinel -1.0, cast booleans to int, `GroupShuffleSplit` user-level train/test split (80/20), `StandardScaler` fit on train only
3. **Train:** Logistic Regression (balanced class weights, lbfgs, C=1.0, max_iter=1000) + HistGradientBoostingClassifier (max_iter=200, max_depth=6, early_stopping)
4. **Evaluate:** Accuracy, Precision, Recall, F1, AUC-ROC, confusion matrices, ROC curves, feature importance
5. **Select:** Higher F1 wins; if within 2% F1, prefer LR for simpler TFLite export
6. **Export:** Custom pure-Python TFLite flatbuffer builder (no TF C++ runtime needed)

### Model Performance (against PROXY label)

| Model | Accuracy | Precision | Recall | F1 | AUC-ROC |
|-------|----------|-----------|--------|-----|---------|
| **Logistic Regression** ✅ | 0.5672 | 0.5163 | 0.6429 | **0.5727** | **0.5900** |
| Gradient-Boosted Trees | 0.5515 | 0.5026 | 0.5728 | 0.5354 | 0.5560 |

**Selected:** Logistic Regression (LR F1 within 2% of GBT; prefer simpler model for TFLite)

### Training Data Split
- **Train:** 33,718 events from 49 users
- **Test:** 19,554 events from 13 users
- **User leakage check:** PASSED (0 overlapping users)

### 8 Model Input Features (the model does NOT use proximity_flag or proximity_density)
```python
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
```

### Learned Model Parameters
```json
{
  "weights": [0.773, 0.0, -0.160, -0.777, 0.723, -0.028, 0.219, -0.124],
  "bias": 0.0265,
  "scaler_mean": [11.17, 0.0, 16.14, 551.74, 421.20, 13.87, 3.02, 0.27],
  "scaler_scale": [14.35, 1.0, 19.55, 4327.76, 4266.92, 5.98, 1.97, 0.44],
  "default_threshold": 0.5
}
```

### TFLite Export Mechanism
The LR model is exported to TFLite by **directly constructing a FlatBuffer** using `schema_py_generated.py` from the TensorFlow package (pure Python, no C++ runtime). The TFLite graph is:
```
input [1, 8] → FULLY_CONNECTED(weights, bias) → [1, 1] → LOGISTIC → output [1, 1]
```
This is **mathematically identical** to `sigmoid(X @ coef_.T + intercept_)`. The export was validated: max prediction diff between sklearn and manual sigmoid = < 1e-5.

### Output Files
- `models/phubbing_detector.tflite` (732 bytes)
- `models/model_metadata.json` (weights, bias, scaler_mean, scaler_scale, feature_names)
- `models/best_model.joblib`, `logistic_regression.joblib`, `gradient_boosted_trees.joblib`
- `models/scaler.joblib`
- `models/evaluation_report.txt`
- `models/confusion_matrix.png`, `roc_curve.png`, `feature_importance.png`

### How to Run
```bash
python -m phubb_free.run_stage2
```

---

## 6. STAGE 3 — FLUTTER MOBILE APP (⚠️ PARTIALLY COMPLETE)

### What IS Built

#### App Architecture
```
main.dart → MultiProvider tree → AppEntry (onboarding gate) → AppShell (bottom nav)
                                                                ├── HomeScreen
                                                                ├── InsightsScreen
                                                                └── SettingsScreen
```

#### Provider Tree (6 providers)
```dart
MultiProvider(providers: [
  ChangeNotifierProvider.value(ThemeController),        // System/Light/Dark theme
  ChangeNotifierProvider.value(SettingsController),     // All user prefs
  ChangeNotifierProvider.value(PhubbingRepository),     // Data source + mock events
  ChangeNotifierProvider(PermissionService),            // Mock permissions
  Provider<PhubInferenceService>.value(inferenceService), // ML model
  ChangeNotifierProvider.value(NudgeService),           // Nudge delivery
])
```

#### Screens (All Fully Implemented)

1. **OnboardingScreen** — 3-page PageView explaining Usage Access, Bluetooth, Notification permissions. Each page shows permission purpose, privacy detail, grant button, and "granted" check. Skippable. Re-openable from Settings. Persisted via SharedPreferences.

2. **HomeScreen** — Full dashboard with:
   - App bar with theme toggle and profile avatar
   - Hero number (animated counter of today's phubbing moments)
   - Yesterday comparison text
   - 7-day bar chart (fl_chart)
   - 2×2 metrics grid: Nudges today, Phone-free social time, Longest stretch, Unlocks near people
   - Monitoring toggle (Active/Paused switch)
   - Activity feed (expandable event tiles with details: package, RSSI, response latency, nearby person)
   - "View all" bottom sheet for full activity list
   - Profile bottom sheet
   - Privacy badge footer

3. **InsightsScreen** — Analytics with:
   - 7/30-day period toggle
   - Weekly trend summary (up/down percentage)
   - Bar chart for selected period
   - "Top Apps During Social Moments" ranked list
   - Privacy badge footer

4. **SettingsScreen** — Full settings with:
   - **Appearance:** System/Light/Dark theme selector (3-way toggle)
   - **Nudge Sensitivity:** Slider (0.0–1.0) mapping to model threshold (0.70–0.30)
   - **Nudge Style:** Vibration / Silent notification / Off
   - **Quiet Hours:** Time pickers (default 10 PM – 7 AM)
   - **App Whitelist:** Default [Maps, Phone, Camera], add/remove
   - **Your Data:** Export (placeholder), Delete all data (with confirmation dialog)
   - **About:** Version, privacy statement, re-run onboarding

#### Services (All Implemented)

1. **PhubInferenceService** — Pure-Dart logistic regression inference:
   - Loads weights, bias, scaler_mean, scaler_scale from `assets/models/model_metadata.json`
   - `predictProbability(List<double> rawFeatures)` → 0.0–1.0
   - Implements: z = (x - mean) / scale → logit = Σ(wᵢ·zᵢ) + bias → sigmoid(logit)
   - `buildFeatureVector()` static helper to assemble 8 features from sensor observations
   - **Does NOT use the .tflite file** — inference is pure Dart math from the JSON weights

2. **RollingWindowAggregator** — 1-hour sliding window buffer:
   - `record(PhubEvent)` — adds to buffer, evicts old entries
   - Exposes: `unlockCount`, `appSwitchCount`, `notifCount`, `notifRespLatencyMean`, `notifRespLatencyMedian`
   - `buildFeatures()` → 8-element raw feature vector
   - `currentProbability(PhubInferenceService)` → model probability

3. **NudgeService** — Central nudge delivery:
   - `evaluate(event, probability, settings)` → bool (whether nudge fired)
   - Respects: sensitivity threshold, quiet hours, app whitelist, 2-min cooldown, nudge style
   - Sensitivity → threshold mapping: `threshold = 0.70 - 0.40 * sensitivity`
   - Delivery: haptic (double light impact) + animated overlay banner
   - Overlay: auto-dismiss after 4 seconds, tap to dismiss
   - Rotating message templates (generic + app-specific)
   - History (last 100 nudges)

4. **PermissionService** — **MOCK ONLY** (delays 1 second, then sets granted=true)

5. **PhubbingRepository** — **MOCK DATA SOURCE** that:
   - Generates random PhubEvents every 3–8 seconds
   - Feeds each event into `RollingWindowAggregator`
   - Scores the window with `PhubInferenceService` (real model) if attached
   - Maintains event list (last 50), daily summaries (30 days), top apps (hardcoded)
   - Streams events via `StreamController<PhubEvent>.broadcast()`
   - Exposes `lastProbability`, `isMonitoring`, `today`, `yesterday`, `weeklyTrend`

#### Data Models

```dart
// PhubEvent — a single phone-interaction event
class PhubEvent {
  String id, appName, appPackage;
  PhubEventType type;  // unlock, appSwitch, notification
  DateTime timestamp;
  bool nearbyPersonDetected;
  int? rssi, responseLatencySec;
  String get friendlyText;      // human-readable description
  bool get isPossiblePhubbing;  // == nearbyPersonDetected
}

// DaySummary — daily aggregates for charts
class DaySummary {
  DateTime date;
  int phubMoments, nudgesSent, unlocksNearPeople;
  Duration phoneFreeTime, longestStretch;
}

// AppSocialUsage — app rankings
class AppSocialUsage { String appName; int count; }
```

#### Design System ("Moss & Stone" Theme)

| Token | Light | Dark |
|-------|-------|------|
| Background | #F5F4EE (warm cream) | #1A1C1A (deep forest) |
| Surface | #FFFFFF | #232622 |
| Border | #DFDFD4 | #363A35 |
| Text Primary | #1B1E1A | #EFF1EA |
| Text Secondary | #646A60 | #A3A99E |
| Accent | #2F6B4F (moss green) | #7FC4A0 |
| Accent Soft | #DCE9E0 | #27382F |
| Positive | #3D7A4F | #8CC79D |
| Warning | #B7791F | #E0B45C |
| Error | #B3392F | #E57A70 |

**Typography:** Fraunces (serif) for hero numbers and headings; Inter (sans) for body/UI text.
**Spacing:** 4/8 grid (xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48).
**Radii:** sm=8, md=12, lg=16.

#### NudgeOverlay Widget
Animated slide-down banner that appears over all content:
- Glassmorphic gradient card with accent tint
- Pulse dot + message text + close icon
- AnimatedPositioned + AnimatedOpacity
- Auto-dismiss timer (4 sec)

#### Legacy UI Files (in `lib/ui/`)
There is an older UI prototype under `lib/ui/` with a neon dark theme (`AppTheme.accentPurple`, `AppTheme.accentCyan`), a simpler home screen using `MockSensorFeed`, and a basic permissions screen. **These are NOT used in the current app** — the current app uses `lib/screens/`, `lib/theme/`, and `lib/widgets/`. The `lib/ui/` directory can be safely deleted.

---

## 7. WHAT IS NOT BUILT — REMAINING WORK

### Stage 3 Gaps (Mobile App — Must Complete)

#### 7.1. REAL SENSOR COLLECTION (Critical — entire backend is mock)
The `PhubbingRepository` currently generates **random fake events**. The following real Android/iOS sensor integrations are needed:

| Sensor | What to Implement | Android API | iOS API |
|--------|-------------------|-------------|---------|
| **Screen unlock** | Detect screen on/off events | `UsageStatsManager` or `ACTION_SCREEN_ON/OFF` broadcast receiver | `UIApplication.didBecomeActiveNotification` |
| **App switches** | Detect foreground app changes | `UsageStatsManager.queryUsageStats()` | Not available on iOS (use app lifecycle events as proxy) |
| **Bluetooth proximity** | Scan for nearby BLE devices | `BluetoothLeScanner` | `CoreBluetooth CBCentralManager` |
| **Notification listener** | Detect notification arrival/response | `NotificationListenerService` | `UNUserNotificationCenter` |

**Flutter packages to consider:**
- `flutter_blue_plus` or `flutter_reactive_ble` for BLE scanning
- `usage_stats` for Android usage statistics
- `flutter_local_notifications` for notification access
- Platform channels for `NotificationListenerService` (Android) and `UsageStatsManager`

**Key implementation note:** The `RollingWindowAggregator` and `PhubInferenceService` are already wired up and working. You need to replace `PhubbingRepository._generateEvent()` with real sensor data while keeping the same `PhubEvent` interface.

#### 7.2. REAL PERMISSIONS (Critical)
`PermissionService` is currently **fully mocked** (just delays 1 second, sets granted=true). Need to implement:
- `PACKAGE_USAGE_STATS` permission (requires opening Android Settings)
- `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION` (for BLE)
- `BIND_NOTIFICATION_LISTENER_SERVICE` (requires opening Android Settings)

**Flutter packages:** `permission_handler` for standard permissions, platform channels for special permissions.

#### 7.3. BACKGROUND SERVICE (Critical)
Currently the app only works while in the foreground. Need a persistent background service that:
- Runs continuously (Android foreground service with notification)
- Collects sensor data even when app is backgrounded/closed
- Feeds events into the rolling window aggregator
- Triggers nudges when phubbing is detected

**Flutter packages:** `flutter_background_service`, `workmanager`, or custom platform channels.

#### 7.4. LOCAL DATA PERSISTENCE (Important)
Currently all event history and daily summaries are **generated in memory and lost on app restart**. Need:
- Local database (SQLite via `sqflite` or `drift`) for event history
- Computed daily summaries from real events
- Real "top apps during social moments" from actual data

#### 7.5. DATA EXPORT (Minor)
Settings screen has a "Export my data" button that just shows a SnackBar. Need real JSON export to local storage.

#### 7.6. CLEANUP
- Delete `lib/ui/` directory (legacy prototype, not used)
- Delete `lib/services/mock_sensor_feed.dart` (replaced by PhubbingRepository)
- Delete `lib/models/sensor_event.dart` (replaced by PhubEvent)

---

### Stage 4 — On-Device Personalization (❌ NOT STARTED)

This is the most research-heavy stage. The concept:

1. **Baseline Model:** The TFLite model (trained on 62 users' pooled data) provides the starting threshold for what constitutes "phone distraction during social presence."

2. **Personal Adaptation:** After 1–2 weeks of use, the app should:
   - Track this specific user's unlock frequency, notification response patterns, and social context timing
   - Mathematically adjust the internal decision threshold: users who check their phone 50 times/hour normally should have a different "phubbing" threshold than users who check 5 times/hour
   - Use federated learning concepts — but since all processing is local, it's simpler: just online learning with exponential moving averages or a small on-device fine-tuning loop

3. **Implementation Ideas:**
   - **Simple:** Exponential moving average of the user's feature distributions → dynamically shift the scaler_mean and scaler_scale to the user's personal baseline → model naturally adapts
   - **Medium:** Track model prediction accuracy by collecting user feedback (did you actually feel nudged? was this annoying?) and adjust the threshold accordingly
   - **Advanced:** On-device gradient updates to the LR weights using the user's own labeled data (e.g., user dismisses nudge = false positive signal)

4. **Privacy Consideration:** All personalization data must remain on-device. No cloud sync. If user deletes data, all personalization resets.

---

## 8. KEY CONFIGURATION VALUES

```python
# Signal Processing
RSSI_COPRESENCE_THRESHOLD = -75  # dBm (~1-3 meters)
FEATURE_WINDOW_SEC = 3600        # 1 hour rolling window
APP_SWITCH_GAP_THRESHOLD_SEC = 30  # rapid re-unlock = app switch proxy
PROXIMITY_WINDOW_SEC = 600       # ±10 min for co-presence detection

# Model
LATENCY_SENTINEL = -1.0          # NaN fill for missing notification latency
MODEL_SELECTION_THRESHOLD = 0.02 # F1 margin before preferring GBT over LR

# App
NUDGE_COOLDOWN = Duration(minutes: 2)
OVERLAY_DISMISS = Duration(seconds: 4)
MOCK_EVENT_INTERVAL = 3-8 seconds (random)
DEFAULT_QUIET_HOURS = 10:00 PM – 7:00 AM
DEFAULT_WHITELIST = ['Maps', 'Phone', 'Camera']
SENSITIVITY_TO_THRESHOLD = 0.70 - 0.40 * sensitivity  # (0.0→0.70, 0.5→0.50, 1.0→0.30)
```

---

## 9. HOW TO RUN

### Python ML Pipeline
```bash
cd Phubfree
pip install pandas scikit-learn pyarrow pyreadr joblib matplotlib seaborn flatbuffers

# Stage 1 (requires raw datasets in datasets/)
python -m phubb_free.run_stage1

# Stage 2 (requires data/features_labeled.parquet from Stage 1)
python -m phubb_free.run_stage2

# Tests
pytest tests/
```

### Flutter App
```bash
cd phubb_free_app
flutter pub get
flutter run
```

**Note:** The app currently uses the `model_metadata.json` asset for pure-Dart inference. The `.tflite` file is bundled for provenance but not loaded at runtime (inference is done via the Dart sigmoid implementation).

---

## 10. CRITICAL CAVEATS FOR CONTINUATION

> [!CAUTION]
> 1. **Proxy Label:** ALL metrics (F1=0.57, AUC=0.59) are against a CONSTRUCTED PROXY label, not ground-truth phubbing. The model is a starting point for personalization, not a definitive detector.
> 2. **Population Mismatch:** The 3 datasets are from DIFFERENT populations. Features are computed per-user within each dataset. The combined feature space trains a single classifier, but cross-population generalization is not validated.
> 3. **Mock Everything:** The Flutter app's data layer is 100% mock. PhubbingRepository generates fake events. PermissionService auto-grants. No real sensors are connected.
> 4. **No Background Service:** The app only works in the foreground. No persistent monitoring.
> 5. **No Local Storage:** Event history is in-memory only, lost on restart.
> 6. **Legacy UI files:** `lib/ui/` contains an old prototype that is NOT used by the current app. The current app uses `lib/screens/`, `lib/theme/`, `lib/widgets/`.
> 7. **model_metadata.json divergence:** The file in `models/` (Python output) does NOT have the `weights` and `bias` fields. The file in `phubb_free_app/assets/models/` DOES have them (manually added for Dart inference). Keep them in sync.

---

## 11. DEPENDENCY VERSIONS

### Python
- Python 3.12+
- pandas, scikit-learn, pyarrow, pyreadr, joblib, matplotlib, seaborn, flatbuffers
- tensorflow (only needed for schema_py_generated.py file and optional GBT distillation)

### Flutter (pubspec.yaml)
```yaml
environment:
  sdk: ^3.13.4

dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  provider: ^6.1.5+1
  google_fonts: ^6.2.1
  fl_chart: ^0.70.2
  shared_preferences: ^2.3.4
  intl: ^0.20.2

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^6.0.0
```

---

## 12. FULL END-TO-END IMPLEMENTATION PLAN

This is the complete staged implementation plan — from raw research data to a polished, production-ready product on the app stores. Each stage is broken into sub-stages with specific deliverables and status.

---

### STAGE 1: DATA ENGINEERING ✅ COMPLETE

**Goal:** Transform three raw smartphone telemetry datasets into a clean, unified feature table with proxy phubbing labels.

| Sub-stage | Description | Status |
|-----------|-------------|--------|
| 1.1 ETL — Copenhagen Networks Study | Load `bt_symmetric.csv`, filter valid user-to-user scans (user_b ≥ 0), apply RSSI ≥ -75 dBm threshold, derive time-of-day, map to unified schema with `cns_` prefix | ✅ Done |
| 1.2 ETL — Dartmouth StudentLife | Load `phonelock.Rds` and `bluetooth.Rds` via pyreadr. Extract unlock events, detect app-switch proxy (re-unlocks < 30s apart), BLE proximity events with RSSI threshold. Prefix `sl_` | ✅ Done |
| 1.3 ETL — University of Ljubljana | Load tab-delimited files. Compute notification response latency (Posted→Clicked/Removed join). Extract unlock events from screen state. Binary BT proximity (no RSSI). Prefix `lj_` | ✅ Done |
| 1.4 Unification | Concatenate all 3 datasets into unified schema (8 columns), validate schema, enforce types, deduplicate, sort by user+timestamp | ✅ Done |
| 1.5 Feature Engineering | Compute 10 rolling-window features per user: unlock_freq_1h, app_switch_rate_1h, notif_count_1h, notif_resp_latency_mean/median_1h, proximity_flag/density_1h, hour_of_day, day_of_week, is_weekend | ✅ Done |
| 1.6 Proxy Label Construction | Label phone-interaction events as phubbing=1 when BT co-presence detected within ±10 min window. Skip proximity-only users (no phone events to label) | ✅ Done |
| 1.7 Validation & Output | Schema validation, missing value report, class balance report. Save to `data/unified_events.parquet` and `data/features_labeled.parquet` | ✅ Done |

**Deliverables:** `unified_events.parquet`, `features_labeled.parquet`

---

### STAGE 2: AI MODEL TRAINING ✅ COMPLETE

**Goal:** Train a baseline phubbing classifier, evaluate rigorously with user-level splits, and export a sub-1KB TFLite model for on-device inference.

| Sub-stage | Description | Status |
|-----------|-------------|--------|
| 2.1 Preprocessing | NaN imputation for latency columns (sentinel -1.0), boolean→int cast, GroupShuffleSplit user-level train/test split (80/20, no user leakage), StandardScaler fit on train only | ✅ Done |
| 2.2 Logistic Regression Training | LR with balanced class weights, lbfgs solver, C=1.0, max_iter=1000. Result: F1=0.5727, AUC=0.5900 | ✅ Done |
| 2.3 Gradient-Boosted Trees Training | HistGBT with max_iter=200, max_depth=6, early_stopping, balanced weights. Result: F1=0.5354, AUC=0.5560 | ✅ Done |
| 2.4 Model Selection | Higher F1 wins; if within 2% F1 prefer LR for simpler TFLite export. Selected: **Logistic Regression** | ✅ Done |
| 2.5 Evaluation Artifacts | Confusion matrix heatmaps, ROC curves, feature importance charts, full classification report with proxy label caveat annotations | ✅ Done |
| 2.6 Custom TFLite Export | Pure-Python flatbuffer construction (no TF C++ runtime). Graph: input[1,8] → FULLY_CONNECTED → LOGISTIC → output[1,1]. Validated: max prediction diff < 1e-5 vs sklearn | ✅ Done |
| 2.7 Model Metadata | Exported `model_metadata.json` with feature_names, scaler_mean, scaler_scale, weights, bias, default_threshold, metrics | ✅ Done |

**Deliverables:** `phubbing_detector.tflite` (732B), `model_metadata.json`, `best_model.joblib`, `scaler.joblib`, evaluation plots

---

### STAGE 3: MOBILE APP INTERFACE ⚠️ PARTIALLY COMPLETE

**Goal:** A cross-platform Flutter app that loads the TFLite model for offline inferences, collects background sensor data, and provides a beautiful user dashboard with gentle nudge interventions.

#### 3A. UI / Frontend Layer ✅ COMPLETE

| Sub-stage | Description | Status |
|-----------|-------------|--------|
| 3A.1 App Shell & Navigation | Bottom navigation bar (Home, Insights, Settings) with IndexedStack to preserve tab state | ✅ Done |
| 3A.2 Onboarding Flow | 3-page PageView explaining Usage Access, Bluetooth, Notification permissions with privacy details, grant buttons, skip option. Persisted via SharedPreferences | ✅ Done |
| 3A.3 Home Screen Dashboard | Hero phubbing count (animated), yesterday comparison, 7-day bar chart (fl_chart), 2×2 metrics grid (nudges, phone-free time, longest stretch, unlocks near people), monitoring toggle, activity feed with expandable event tiles, profile bottom sheet | ✅ Done |
| 3A.4 Insights Screen | 7/30-day period toggle, weekly trend summary (% change), bar chart, top apps during social moments ranking | ✅ Done |
| 3A.5 Settings Screen | Theme selector (System/Light/Dark), nudge sensitivity slider (0.0–1.0 → model threshold 0.70–0.30), nudge style (Vibration/Silent/Off), quiet hours time pickers, app whitelist (add/remove), data export (placeholder), delete all data with confirmation, about section with re-run onboarding | ✅ Done |
| 3A.6 Design System | "Moss & Stone" color palette (light + dark), Fraunces serif + Inter sans typography, 4/8 spacing grid, 3-tier radii, custom ColorScheme builder, full ThemeData | ✅ Done |
| 3A.7 Shared Widgets | MetricCard, StatusTag, SectionHeader, PrivacyBadge, EmptyState — reusable across all screens | ✅ Done |
| 3A.8 Nudge Overlay | Animated slide-down glassmorphic banner with auto-dismiss (4s), tap-to-dismiss, rotating message templates (generic + app-specific) | ✅ Done |

#### 3B. Inference & Logic Layer ✅ COMPLETE

| Sub-stage | Description | Status |
|-----------|-------------|--------|
| 3B.1 Pure-Dart Inference Service | `PhubInferenceService` — loads weights/bias/scaler from `model_metadata.json`. Implements StandardScaler → dot product → sigmoid. No native TFLite dependency | ✅ Done |
| 3B.2 Rolling Window Aggregator | `RollingWindowAggregator` — 1-hour sliding window Queue of events. Computes unlockCount, appSwitchCount, notifCount, latency mean/median. Builds 8-element feature vector | ✅ Done |
| 3B.3 Nudge Service | `NudgeService` — evaluates every event against model probability, respects sensitivity threshold, quiet hours, app whitelist, 2-min cooldown. Delivers haptic (double light impact) + overlay banner | ✅ Done |
| 3B.4 State Management | `SettingsController` (all prefs with SharedPreferences), `ThemeController` (System/Light/Dark with persistence), `PhubbingRepository` (data source with ChangeNotifier) | ✅ Done |
| 3B.5 Data Models | `PhubEvent`, `PhubEventType`, `DaySummary`, `AppSocialUsage` — complete data model for the activity feed, charts, and analytics | ✅ Done |

#### 3C. Real Sensor Integration ❌ NOT STARTED

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 3C.1 BLE Proximity Scanner | Replace mock proximity with real BLE scanning. Scan for nearby devices every 5–15 seconds. Apply RSSI ≥ -75 dBm threshold. Use `flutter_blue_plus` or `flutter_reactive_ble`. Must handle scan start/stop lifecycle, battery optimization | ❌ Not started | 🔴 Critical |
| 3C.2 Screen Unlock Detection | Android: `BroadcastReceiver` for `ACTION_SCREEN_ON` / `ACTION_USER_PRESENT`. iOS: `UIApplication.didBecomeActiveNotification`. Requires platform channels (MethodChannel) | ❌ Not started | 🔴 Critical |
| 3C.3 App Usage / Foreground App Detection | Android: `UsageStatsManager.queryUsageStats()` to detect foreground app changes. Requires `PACKAGE_USAGE_STATS` permission (special, opens Settings). iOS: Limited — use app lifecycle as proxy. Detect rapid app switches (< 30s = app_switch event per proxy definition) | ❌ Not started | 🔴 Critical |
| 3C.4 Notification Listener | Android: `NotificationListenerService` to detect notification posting and user response. Compute response_latency_sec as time between posting and user clicking. Requires special permission (opens Settings). iOS: `UNUserNotificationCenter` with limited access | ❌ Not started | 🟡 Important |
| 3C.5 Sensor → PhubEvent Bridge | Wire all 4 real sensor streams into the existing `PhubbingRepository` interface. Each sensor event becomes a `PhubEvent` → fed into `RollingWindowAggregator` → scored by `PhubInferenceService` → evaluated by `NudgeService`. The pipeline is already built, just needs real input | ❌ Not started | 🔴 Critical |

#### 3D. Background Service & Lifecycle ❌ NOT STARTED

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 3D.1 Android Foreground Service | Persistent service with notification ("Phubb-Free is monitoring"). Runs BLE scans, screen unlock listener, notification listener continuously. Must survive app backgrounding and device sleep. Use `flutter_background_service` or custom `ForegroundService` via platform channel | ❌ Not started | 🔴 Critical |
| 3D.2 iOS Background Modes | Configure `UIBackgroundModes` for bluetooth-central. iOS is much more restrictive — BLE scanning works in background but with reduced frequency. Screen unlock detection is limited. Consider `BGTaskScheduler` for periodic check-ins | ❌ Not started | 🟡 Important |
| 3D.3 Battery Optimization Handling | Request exemption from Doze mode / App Standby (Android). Handle `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Adaptive scan intervals based on battery level. Show battery usage in settings | ❌ Not started | 🟡 Important |
| 3D.4 Service ↔ UI Communication | Background service sends events to foreground UI via `MethodChannel`, `EventChannel`, or `IsolateNameServer`. UI should update in real-time when app is foregrounded | ❌ Not started | 🔴 Critical |

#### 3E. Real Permissions ❌ NOT STARTED

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 3E.1 Permission Handler Integration | Add `permission_handler` package. Request `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION` (required for BLE on Android 12+) | ❌ Not started | 🔴 Critical |
| 3E.2 Special Permissions (Android) | `PACKAGE_USAGE_STATS` — must open Settings via intent, check on return. `BIND_NOTIFICATION_LISTENER_SERVICE` — must open Settings, check on return. Build custom UI flow that guides user step-by-step | ❌ Not started | 🔴 Critical |
| 3E.3 Permission State Persistence | Track granted/denied/permanently-denied states. Show targeted "re-grant" prompts if permission revoked. Handle runtime permission changes | ❌ Not started | 🟡 Important |
| 3E.4 Graceful Degradation | App should work with partial permissions. E.g., if BLE denied but notification access granted, still track notification patterns but mark all events as proximity_unknown | ❌ Not started | 🟢 Nice-to-have |

#### 3F. Local Data Persistence ❌ NOT STARTED

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 3F.1 Database Setup | SQLite via `sqflite` or `drift` (type-safe ORM). Tables: `events` (all PhubEvents), `daily_summaries` (computed aggregates), `nudge_history` (delivered nudges), `user_profile` (personalization state) | ❌ Not started | 🔴 Critical |
| 3F.2 Event Storage & Querying | Store every PhubEvent locally. Query: today's events, last 7/30 days, by event type. Auto-cleanup: delete events older than 90 days (configurable) | ❌ Not started | 🔴 Critical |
| 3F.3 Real Daily Summaries | Compute actual `DaySummary` from stored events instead of random mock data. Aggregate: phubMoments, nudgesSent, phoneFreeTime, longestStretch, unlocksNearPeople per day | ❌ Not started | 🔴 Critical |
| 3F.4 Real Top Apps | Compute actual "top apps during social moments" from stored events (apps used during proximity=true). Replace hardcoded mock data | ❌ Not started | 🟡 Important |
| 3F.5 Data Export | Implement real JSON export of all locally stored data to device storage. Respect Android scoped storage / iOS Files app. Wire to the Settings "Export my data" button | ❌ Not started | 🟢 Nice-to-have |
| 3F.6 Data Migration | Schema versioning for database upgrades across app updates | ❌ Not started | 🟢 Nice-to-have |

#### 3G. Code Cleanup ❌ NOT STARTED

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 3G.1 Remove Legacy UI | Delete `lib/ui/` directory (old neon theme prototype, `lib/ui/theme.dart`, `lib/ui/screens/home_screen.dart`, `lib/ui/screens/permissions_screen.dart`) | ❌ Not started | 🟡 Important |
| 3G.2 Remove Legacy Models | Delete `lib/models/sensor_event.dart` (replaced by `PhubEvent`), `lib/services/mock_sensor_feed.dart` (replaced by `PhubbingRepository`) | ❌ Not started | 🟡 Important |
| 3G.3 Remove Mock Flag from Repository | Add a `useMock: bool` flag or compile-time constant to `PhubbingRepository` to toggle between mock and real sensor data. Eventually remove mock path entirely | ❌ Not started | 🟡 Important |
| 3G.4 `StreamSubscription` Import | `main.dart` line 99 uses `StreamSubscription<dynamic>` but the import `dart:async` is missing at the top of the file. Fix this | ❌ Not started | 🟡 Important |

---

### STAGE 4: ON-DEVICE PERSONALIZATION ❌ NOT STARTED

**Goal:** The app learns each user's unique phone-usage baseline and adapts its phubbing detection threshold over time, entirely on-device.

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 4.1 Personal Baseline Collection | After 7–14 days of real usage, compute the user's personal mean and standard deviation for each of the 8 features. Store in local DB | ❌ Not started | 🔴 Critical |
| 4.2 Adaptive Scaler Shifting | Replace the population-level `scaler_mean` and `scaler_scale` (from training data of 62 users) with a weighted blend: `adapted_mean = α * user_mean + (1-α) * population_mean`, where α increases from 0→1 over the first 2 weeks. This naturally shifts the model's "normal" baseline to this user | ❌ Not started | 🔴 Critical |
| 4.3 Dynamic Threshold Adjustment | Track false positive rate by monitoring nudge dismissals (user ignores/dismisses nudge quickly = likely false positive). If dismissal rate > 60%, raise the threshold by 0.05. If user engages with nudges, lower slightly. Bounded between 0.3 and 0.8 | ❌ Not started | 🟡 Important |
| 4.4 Time-of-Day Profiling | Learn the user's daily rhythm: e.g., high phone usage during commute hours is normal, but high usage during dinner time is likely phubbing. Apply time-of-day multipliers to the base threshold | ❌ Not started | 🟡 Important |
| 4.5 Location-Context Learning | (Future) If location permission granted, learn that phone usage at "work" is different from "home" or "restaurant." Use geofencing clusters (not exact coordinates) for context-aware thresholds | ❌ Not started | 🟢 Future |
| 4.6 On-Device Weight Updates | (Advanced) Periodically retrain the LR weights using the user's own labeled data: events where user confirms/dismisses the nudge become positive/negative training labels. Use online SGD with learning rate decay. Store updated weights locally | ❌ Not started | 🟢 Future |
| 4.7 Personalization Reset | Allow user to "reset personalization" from Settings. Clears personal baseline, reverts to population-level scaler_mean/scaler_scale, resets threshold to 0.5 | ❌ Not started | 🟡 Important |
| 4.8 Personalization Analytics | Show the user their personalization progress: "Phubb-Free has learned your patterns for 12 days" or "Your personal baseline is 85% adapted." Display in Insights screen | ❌ Not started | 🟢 Nice-to-have |

---

### STAGE 5: TESTING & QUALITY ASSURANCE ❌ NOT STARTED

**Goal:** Comprehensive test coverage across the Python pipeline and Flutter app to ensure correctness and prevent regressions.

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 5.1 Python Unit Tests (Existing) | Tests for config, data validation, features, model, unification exist in `tests/`. Run with `pytest tests/` | ⚠️ Exists but needs expansion | 🟡 Important |
| 5.2 Flutter Unit Tests | Test `PhubInferenceService` (verify sigmoid math matches Python), `RollingWindowAggregator` (window eviction, feature computation), `NudgeService` (cooldown, quiet hours, whitelist logic), `SettingsController` (persistence roundtrip) | ❌ Not started | 🔴 Critical |
| 5.3 Flutter Widget Tests | Test all screens render correctly, onboarding flow navigation, settings toggles, event tile expansion, chart data binding | ❌ Not started | 🟡 Important |
| 5.4 Flutter Integration Tests | Full end-to-end flow: launch → onboarding → grant permissions → see dashboard → receive nudge → dismiss → check insights | ❌ Not started | 🟡 Important |
| 5.5 Cross-Platform Validation | Verify inference produces identical results in Python (sklearn), Python (manual sigmoid), Dart (PhubInferenceService). Automate with a shared test vector file | ❌ Not started | 🟡 Important |
| 5.6 Battery & Performance Testing | Profile background service CPU/memory/battery usage on real devices. Ensure BLE scan intervals don't drain battery. Target < 5% daily battery impact | ❌ Not started | 🟡 Important |
| 5.7 Privacy Audit | Verify no data leaves the device — audit all network calls, check no analytics SDKs are included, confirm SharedPreferences/SQLite data is not synced to cloud backup | ❌ Not started | 🔴 Critical |

---

### STAGE 6: POLISH & UX REFINEMENT 🟡 PARTIALLY ADDRESSED

**Goal:** Elevate the app from functional to delightful with animations, accessibility, and behavioral science-informed nudge design.

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 6.1 Micro-Animations | Add page transition animations, card entrance stagger, chart draw animation, monitoring toggle pulse | ⚠️ Some exist (hero counter, chart animation) | 🟢 Nice-to-have |
| 6.2 Haptic Feedback Patterns | Design multiple haptic patterns for different nudge intensities (gentle tap, double pulse, escalating). Map to phubbing probability ranges | ⚠️ Basic double-tap exists | 🟡 Important |
| 6.3 Nudge Message Quality | Expand nudge message pool. Add context-aware messages (time of day, app being used, duration of phubbing). A/B test message effectiveness via local tracking | ⚠️ 5 generic + 3 app-specific exist | 🟡 Important |
| 6.4 Accessibility | Add semantic labels for screen readers, ensure contrast ratios meet WCAG AA, support dynamic text scaling, RTL layout support | ❌ Not started | 🟡 Important |
| 6.5 Localization / i18n | Extract all user-facing strings to ARB files. Support at minimum English, Spanish, Hindi. Use `flutter_localizations` | ❌ Not started | 🟢 Future |
| 6.6 App Icon & Splash Screen | Design and implement custom launcher icon and splash screen (native Android/iOS splash, not Flutter delay) | ❌ Not started | 🟡 Important |
| 6.7 Onboarding Illustrations | Replace plain Material icons in onboarding pages with custom illustrations or Lottie animations | ❌ Not started | 🟢 Nice-to-have |
| 6.8 Weekly Summary Notification | Push a local notification every Sunday evening: "This week you had X phubbing moments, down Y% from last week" | ❌ Not started | 🟢 Nice-to-have |
| 6.9 Streaks & Gamification | "Phone-free streak" counter, daily/weekly goals, congratulatory animations when user improves | ❌ Not started | 🟢 Future |

---

### STAGE 7: APP STORE DEPLOYMENT ❌ NOT STARTED

**Goal:** Package, sign, and publish the app to Google Play Store and Apple App Store.

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 7.1 Android Build Configuration | Configure `build.gradle` — set applicationId, minSdkVersion (≥21 for BLE), targetSdkVersion (latest), signing config with keystore, ProGuard/R8 rules | ❌ Not started | 🔴 Critical |
| 7.2 iOS Build Configuration | Configure `Info.plist` — add `NSBluetoothAlwaysUsageDescription`, `UIBackgroundModes` (bluetooth-central), app transport security. Code signing with Apple Developer account | ❌ Not started | 🔴 Critical |
| 7.3 Privacy Policy | Write a comprehensive privacy policy page (web-hosted) explaining: what data is collected, that nothing leaves the device, how data is processed, user rights. Required for both app stores | ❌ Not started | 🔴 Critical |
| 7.4 App Store Listing | Screenshots (phone frames), app description, feature graphics, category selection (Health & Fitness or Productivity), content rating questionnaire | ❌ Not started | 🟡 Important |
| 7.5 Google Play Submission | Create Google Play Developer account (\$25 one-time). Submit signed AAB. Address data safety questionnaire (declare: no data shared, local processing only). Handle review feedback | ❌ Not started | 🔴 Critical |
| 7.6 Apple App Store Submission | Create Apple Developer account (\$99/year). Submit via App Store Connect. Address App Review guidelines — particularly privacy nutrition labels (no data collected/shared). Handle review feedback | ❌ Not started | 🔴 Critical |
| 7.7 CI/CD Pipeline | GitHub Actions or similar: lint → test → build → sign → upload to Play Console / App Store Connect on tag push | ❌ Not started | 🟢 Nice-to-have |

---

### STAGE 8: POST-LAUNCH & ANALYTICS ❌ NOT STARTED

**Goal:** Monitor app health, gather (privacy-respecting) usage analytics, and iterate.

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 8.1 Crash Reporting | Integrate Firebase Crashlytics or Sentry for crash reporting. This is the ONE acceptable cloud connection — crash reports only, no behavioral data | ❌ Not started | 🟡 Important |
| 8.2 Privacy-Respecting Analytics | OPTIONAL and OPT-IN ONLY: aggregate anonymous usage counts (how many users, avg nudges/day, retention). No personal behavioral data. Use privacy-first tools like Plausible or self-hosted Matomo. OR skip entirely and rely on app store analytics | ❌ Not started | 🟢 Future |
| 8.3 User Feedback Channel | In-app feedback form (simple text box in Settings). Stored locally + optionally emailed (user choice). No automatic telemetry | ❌ Not started | 🟢 Nice-to-have |
| 8.4 OTA Model Updates | (Future) Allow shipping updated model weights via app update (not cloud push — that violates privacy principles). New model → new app version → app store update | ❌ Not started | 🟢 Future |
| 8.5 A/B Testing Framework | Local-only A/B testing: randomly assign user to nudge variant (message style A vs B, haptic pattern 1 vs 2) and track effectiveness locally. No server | ❌ Not started | 🟢 Future |

---

### STAGE 9: ADVANCED FEATURES ❌ NOT STARTED (Future Roadmap)

**Goal:** Features that would differentiate Phubb-Free as a best-in-class digital wellness tool.

| Sub-stage | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 9.1 Companion / Accountability Partner | Allow two users to pair via local BLE handshake. Each user sees the other's phubbing score during shared time (opt-in). "You were both phone-free for 45 minutes at dinner!" | ❌ Not started | 🟢 Future |
| 9.2 Social Context Classification | Classify social situations: 1-on-1 conversation, group gathering, work meeting, public transit (not really social). Adjust nudge aggressiveness per context. Use BLE device count + time-of-day heuristics | ❌ Not started | 🟢 Future |
| 9.3 Watch / Wearable Integration | Deliver nudges via smartwatch haptic tap (WearOS / watchOS). More discreet than phone vibration. Companion watch app shows phubbing score | ❌ Not started | 🟢 Future |
| 9.4 Digital Wellbeing Dashboard Widget | Android home screen widget showing today's phubbing count and streak. iOS Lock Screen widget (WidgetKit) | ❌ Not started | 🟢 Future |
| 9.5 Focus Mode Integration | Integrate with Android Focus Mode / iOS Focus Filters. Auto-activate Phubb-Free's monitoring during "Social" focus mode | ❌ Not started | 🟢 Future |
| 9.6 Conversation Quality Scoring | (Research) Beyond just detecting phubbing, estimate the quality of a social interaction based on phone-free duration, BLE co-presence stability, and user engagement patterns | ❌ Not started | 🟢 Research |
| 9.7 ML Model V2 | Retrain with more datasets (e.g., PhoneStudy, Device Analyzer). Try transformer-based sequence models for temporal patterns. Explore on-device federated averaging across anonymous model updates (differential privacy) | ❌ Not started | 🟢 Research |

---

## 13. IMPLEMENTATION PRIORITY SUMMARY

### 🔴 Must-Have (MVP — Required for a Working Product)

```
3C.1  BLE Proximity Scanner (real Bluetooth)
3C.2  Screen Unlock Detection (real sensor)
3C.3  App Usage Detection (real sensor)
3C.5  Sensor → PhubEvent Bridge (wire real data into existing pipeline)
3D.1  Android Foreground Service (background monitoring)
3D.4  Service ↔ UI Communication
3E.1  Permission Handler Integration
3E.2  Special Permissions (Usage Stats, Notification Listener)
3F.1  Database Setup (SQLite/Drift)
3F.2  Event Storage & Querying
3F.3  Real Daily Summaries
4.1   Personal Baseline Collection
4.2   Adaptive Scaler Shifting
5.2   Flutter Unit Tests
5.7   Privacy Audit
7.1   Android Build Configuration
7.3   Privacy Policy
7.5   Google Play Submission
```

### 🟡 Should-Have (Post-MVP — Required for Quality)

```
3C.4  Notification Listener
3D.2  iOS Background Modes
3D.3  Battery Optimization Handling
3E.3  Permission State Persistence
3F.4  Real Top Apps
3G.1  Remove Legacy UI
3G.2  Remove Legacy Models
3G.3  Remove Mock Flag
3G.4  Fix StreamSubscription Import
4.3   Dynamic Threshold Adjustment
4.4   Time-of-Day Profiling
4.7   Personalization Reset
5.1   Expand Python Tests
5.3   Flutter Widget Tests
5.4   Flutter Integration Tests
5.5   Cross-Platform Validation
5.6   Battery & Performance Testing
6.2   Haptic Feedback Patterns
6.3   Nudge Message Quality
6.4   Accessibility
6.6   App Icon & Splash Screen
7.2   iOS Build Configuration
7.4   App Store Listing
7.6   Apple App Store Submission
8.1   Crash Reporting
```

### 🟢 Nice-to-Have / Future

```
3E.4  Graceful Degradation
3F.5  Data Export
3F.6  Data Migration
4.5   Location-Context Learning
4.6   On-Device Weight Updates
4.8   Personalization Analytics
6.1   Micro-Animations
6.5   Localization / i18n
6.7   Onboarding Illustrations
6.8   Weekly Summary Notification
6.9   Streaks & Gamification
7.7   CI/CD Pipeline
8.2   Privacy-Respecting Analytics
8.3   User Feedback Channel
8.4   OTA Model Updates
8.5   A/B Testing Framework
9.1–9.7  All Advanced Features
```

---

## 14. RECOMMENDED BUILD ORDER (If Starting Now)

```
Phase 1 — REAL SENSORS (Week 1-2)
├── 3C.2 Screen Unlock Detection (platform channel)
├── 3C.1 BLE Proximity Scanner (flutter_blue_plus)
├── 3C.3 App Usage Detection (UsageStatsManager)
├── 3C.5 Sensor → PhubEvent Bridge
└── 3E.1 + 3E.2 Real Permissions

Phase 2 — BACKGROUND & PERSISTENCE (Week 3-4)
├── 3D.1 Android Foreground Service
├── 3D.4 Service ↔ UI Communication
├── 3F.1 Database Setup
├── 3F.2 Event Storage
└── 3F.3 Real Daily Summaries

Phase 3 — PERSONALIZATION (Week 5-6)
├── 4.1 Personal Baseline Collection
├── 4.2 Adaptive Scaler Shifting
├── 4.3 Dynamic Threshold Adjustment
└── 4.7 Personalization Reset

Phase 4 — POLISH & TEST (Week 7-8)
├── 3G.1-3G.4 Code Cleanup
├── 5.2 Flutter Unit Tests
├── 5.7 Privacy Audit
├── 6.6 App Icon & Splash Screen
└── 6.4 Accessibility

Phase 5 — SHIP IT (Week 9-10)
├── 7.1 Android Build Config
├── 7.3 Privacy Policy
├── 7.4 App Store Listing
└── 7.5 Google Play Submission
```

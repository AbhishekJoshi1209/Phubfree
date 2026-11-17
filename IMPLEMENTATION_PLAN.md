# Phubb-Free — Implementation Plan (Stage 3 completion → Play Store v1)

> Companion to [PROJECT_SUMMARY_AND_ROADMAP.md](PROJECT_SUMMARY_AND_ROADMAP.md). The roadmap says *what* is left; this file says
> *how*, in which order, which files change, and how each step is accepted. Roadmap IDs (3C.1, 4.2, …) are
> referenced so the two documents stay in sync.
>
> Written 2026-11-17 against commit `633b989` plus the untracked `phubb_free_app/` folder.

---

## 0. Where things actually stand (checked, not copied from the roadmap)

| Check | Result |
|---|---|
| `flutter analyze` | **Fails** — `lib/main.dart:99` uses `StreamSubscription` without `import 'dart:async'` (error). 6 more infos, all in legacy `lib/ui/` or tests. The app does not currently build. |
| `flutter test` | 17/17 pass (`test/phub_inference_service_test.dart`, `test/rolling_window_aggregator_test.dart`). Roadmap item 5.2 is partly started, not "not started". |
| Git | **The whole Flutter app (`phubb_free_app/`) is untracked**, as is the roadmap. `data/features_labeled.parquet` has uncommitted changes. |
| Android config | Package `com.team4.phubb_free_app`, label `phubb_free_app`, no permissions, no services, plain `FlutterActivity`. |
| iOS config | Template only. |

### Problems in the current code that the roadmap doesn't list

These are design gaps, not just missing features. The plan fixes them before building on top.

1. **Proximity and "phubbing" are the same field.** `PhubbingRepository._generateEvent()` sets
   `nearbyPersonDetected = modelSaysPhubbing`, so the sensor fact ("someone is near") and the model verdict are
   merged. Real sensors need them separate: *proxy label = phone interaction AND co-presence*, and the model
   (which never sees proximity) only scores the interaction pattern.
2. **Nudges can't reach the user when they are phubbing.** The nudge is an in-app overlay plus
   `HapticFeedback`. When the user is phubbing they are inside *another* app, so the overlay is never seen and
   `HapticFeedback` doesn't fire from the background. Nudges have to be **system notifications plus
   vibration**, sent from the background service.
3. **Zero-network claim is false today.** `google_fonts` downloads Fraunces/Inter over HTTP at runtime. The fonts
   must be bundled and runtime fetching turned off, otherwise the privacy statement is wrong.
4. **Latency sentinel mismatch.** Python fills a missing latency with `-1.0` (`preprocessing.py:43`). Dart returns
   `0.0` (`rolling_window_aggregator.dart`). The numeric effect is tiny (the scale is about 4300), but the two
   pipelines should agree exactly.
5. **`app_switch_rate_1h` is a dead feature.** Training mean is 0, scale 1, weight 0.0, so it never varied in
   training. Real app-switch data will not move the score. It's still useful for the UI (top apps), but
   personalization should skip it.
6. **BLE "someone nearby" is harder than the roadmap assumes.** Android phones mostly don't advertise BLE
   continuously (iPhones do). A naive scan counts the user's own watch and earbuds, TVs, and neighbours' devices,
   and MAC randomization inflates counts. This is the biggest technical risk, so it gets a spike first (Phase 1).
7. **The 2-minute cooldown is too aggressive** for real use (up to 30 nudges an hour). Plan: 10-minute cooldown plus
   a per-hour cap, both tunable.

---

## 1. Decisions (recommended defaults; change before the relevant phase starts)

| # | Decision | Recommendation | Why |
|---|---|---|---|
| D1 | Platform scope for v1 | **Android only.** iOS deferred. | iOS gives third-party apps no foreground-app, unlock, or other-app notification data, so 3 of the 5 behavioural features can't be computed. Shipping iOS would mean a different, weaker product. |
| D2 | Where the pipeline runs | **Headless Dart isolate in an Android foreground service** (`flutter_background_service`). Sensors come from a small in-app Kotlin plugin. | Reuses the existing Dart aggregator, inference, and nudge logic unchanged. Only the sensor layer is native. |
| D3 | Database | **drift** (SQLite), with the background isolate as the **only writer**. | Type-safe, migrations built in, testable in memory. A single writer avoids cross-engine locking. |
| D4 | Nudge delivery | **`flutter_local_notifications`** (high-importance channel = vibrate, low-importance = silent) with **"Thanks" / "Not now" action buttons**. Keep the in-app overlay only when the app is in the foreground. | Fixes gap 2. The action buttons give explicit labels for personalization (Phase 5). |
| D5 | BLE scanning strategy | **Scan on demand**: a short scan (~6 s) on unlock/screen-on, low-duty re-scans while the screen stays on, **no scanning while the screen is off**. `BLUETOOTH_SCAN` with `neverForLocation`. | Phubbing needs the screen on, so off-screen scanning is wasted battery. `neverForLocation` means no location permission, which is a better privacy story and easier Play review. |
| D6 | Network | **No network at all in release.** No crash reporting in v1 (roadmap 8.1 is moved to "opt-in, later"). | Matches the "zero cloud" core principle and makes the privacy audit a simple binary check. |
| D7 | Inference engine | Keep **pure-Dart LR**. Keep the `.tflite` file only for provenance. | Already tested. Avoids a native TFLite dependency. |

---

## 2. Target architecture (Android v1)

```
┌──────────────────────── Android process ────────────────────────────────────────────┐
│                                                                                      │
│  Kotlin (android/app/src/main/kotlin/.../sensing/)                                   │
│   ├─ UsageEventsPoller    UsageStatsManager.queryEvents → UNLOCK, FOREGROUND_APP     │
│   ├─ ScreenReceiver       ACTION_USER_PRESENT / SCREEN_OFF (low-latency trigger)     │
│   ├─ PhubbNotificationListener  NotificationListenerService → POSTED / CLICKED(lat.) │
│   └─ PhubbSensorsPlugin   FlutterPlugin: EventChannel "phubb/sensor_events"          │
│                                        MethodChannel "phubb/permissions"             │
│                │ raw SensorEvent maps                                                │
│                ▼                                                                     │
│  Background Dart isolate (flutter_background_service, foreground notification)       │
│   SensorEvent ─► EventNormalizer (app-switch rule, whitelist tag)                    │
│              ─► ProximityTracker  ◄── BleScanner (flutter_blue_plus, on-demand)      │
│              ─► RollingWindowAggregator ─► PhubInferenceService (+PersonalScaler)    │
│              ─► NudgePolicy (pure) ─► NotificationNudger (local notif + vibration)   │
│              ─► AppDatabase (drift, sole writer) ─► BaselineTracker (Welford)        │
│                │ service.invoke('db_changed' | 'live_state')                         │
│                ▼                                                                     │
│  UI isolate (existing screens)                                                       │
│   PhubbingRepository = read model over AppDatabase + live state from service         │
│   Settings changes ──► service.invoke('settings_changed')                            │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

Key interface (introduced in Phase 0 so mock and real sources are interchangeable):

```dart
abstract class PhoneEventSource {          // lib/sensing/phone_event_source.dart
  Stream<RawPhoneEvent> get events;        // unlock | foregroundApp | notifPosted | notifClicked
  Future<void> start();
  Future<void> stop();
}
class MockPhoneEventSource implements PhoneEventSource { ... }   // demo + tests
class AndroidPhoneEventSource implements PhoneEventSource { ... } // platform channels
```

---

## 3. Phases

Estimates assume one developer. Every phase ends with `flutter analyze` clean, `flutter test` green, and a commit.

### Phase 0 — Stabilize the base (1–2 days) ✅ DONE (branch `phase-0-stabilize`)

> Notes from doing it: the root `.gitignore` had a Python-template `lib/` rule that silently ignored all Flutter
> source, now anchored to `/lib/`. For 0.8 the `google_fonts` package was **removed entirely**: the fonts are declared
> in `pubspec.yaml`, so no font-download code ships. The bundled files are the exact hash-verified files the package used to
> fetch, and the OFL licences are registered in `LicenseRegistry`. Run `python -m phubb_free.export_app_assets` after
> every Stage 2 run.

| Task | Roadmap | Files | Done when |
|---|---|---|---|
| 0.1 Commit the Flutter app and roadmap as they are; check `.gitignore` excludes `build/`, `.dart_tool/`, `android/local.properties`, `ios/Flutter/ephemeral` | — | repo root | `git status` clean apart from intended changes |
| 0.2 Add `import 'dart:async';` to main.dart | 3G.4 | `lib/main.dart` | `flutter analyze` has 0 errors |
| 0.3 Delete legacy prototype and models | 3G.1, 3G.2 | `lib/ui/`, `lib/models/sensor_event.dart`, `lib/services/mock_sensor_feed.dart` | Nothing imports them; analyze is clean |
| 0.4 **Split the event model**: `PhubEvent` gets `proximity` (`ProximityState.near / notNear / unknown`), `rssi`, `phubScore` (double?), `flagged` (bool). `isPossiblePhubbing` → `flagged`. Update the feed tiles and repository. | (new) | `lib/data/phub_event.dart`, `lib/data/phubbing_repository.dart`, `lib/screens/home_screen.dart` | Feed shows "someone nearby" from `proximity` and the phubbing badge from `flagged` |
| 0.5 Introduce `PhoneEventSource` and move the random generator into `MockPhoneEventSource`. Choose the source with `--dart-define=PHUBB_SOURCE=mock\|device` | 3G.3 | `lib/sensing/*`, `lib/main.dart` | The app runs on mock exactly as today |
| 0.6 Latency sentinel: aggregator returns `-1.0` when there is no latency data, matching Python | (new) | `rolling_window_aggregator.dart`, tests | Test asserts `-1.0` |
| 0.7 Make the app assets from the Python pipeline: Stage 2 writes `weights` and `bias` into `models/model_metadata.json`, plus a script that copies both model files into `phubb_free_app/assets/models/` | caveat 7 | `phubb_free/model/export_tflite.py` or `train.py`, new `phubb_free/export_app_assets.py` | The two JSON files are byte-identical after the script runs |
| 0.8 Bundle Fraunces and Inter under `assets/google_fonts/` and set `GoogleFonts.config.allowRuntimeFetching = false` in `main()` | 5.7 (early) | `pubspec.yaml`, `lib/main.dart` | The app renders correct fonts in airplane mode on first launch |

### Phase 1 — BLE co-presence spike (2–3 days) ⚠️ do before Phase 2

Goal: find out whether "another person is near" can be detected well enough, and freeze the heuristic.

1. Add a debug-only screen (behind `kDebugMode`) that scans with `flutter_blue_plus` and lists each advertisement:
   address, RSSI, manufacturer ID, service UUIDs, and how often it was seen.
2. Field-test in 4 situations: alone at home, with one person (iPhone), with one person (Android), and in a café.
   Log to a CSV on the device.
3. Freeze the `ProximityTracker` rules (starting point, tune from the data):
   - Ignore **bonded/paired devices** (the user's own watch and earbuds) and devices seen on > 80 % of the user's
     solo scans (learned "home furniture" list, kept on-device).
   - Count as a *person signal* only phone-like advertisers: Apple manufacturer `0x004C`, Samsung `0x0075`,
     Microsoft `0x0006`, Google Fast Pair / Nearby service `0xFE2C`/`0xFEF3`, with RSSI ≥ −75 dBm (training threshold).
   - Co-presence = at least 1 person signal seen in at least 2 of the last 3 scans. State stays `near` for 10 minutes
     after the last sighting (matches the ±10 min `PROXIMITY_WINDOW_SEC` used to build the labels).
   - Bluetooth off or permission denied → `ProximityState.unknown` (never `notNear`).
4. **Exit criterion:** in the field log, co-presence precision ≥ 0.7 and recall ≥ 0.5 against the tester's own
   notes. If Android-to-Android recall is poor, document it as a known limitation (or plan an opt-in "pair with a
   friend" beacon, roadmap 9.1) before continuing.

### Phase 2 — Real sensors and permissions, app in foreground (≈1.5 weeks)

| Task | Roadmap | Implementation notes |
|---|---|---|
| 2.1 Kotlin plugin skeleton `PhubbSensorsPlugin` (a real `FlutterPlugin`, so it also attaches to the background engine in Phase 4) | 3C.5 | `EventChannel("phubb/sensor_events")`, `MethodChannel("phubb/permissions")`. Events are maps: `{type, ts, pkg?, label?, latencySec?}` |
| 2.2 Unlocks and foreground apps from **`UsageStatsManager.queryEvents`** | 3C.2, 3C.3 | Poll every 15 s from the last checkpoint. `KEYGUARD_HIDDEN` (API 28+) → unlock. `ACTIVITY_RESUMED` → foreground app. `ACTION_USER_PRESENT` receiver triggers an immediate poll, for low latency. Keeping a checkpoint means no events are lost when the process is killed. |
| 2.3 App-switch rule | 3C.3 | `appSwitch` = foreground package changes to a different launcher app ≥ 2 s after the previous one, while the screen is on. Ignore our own package, launchers, and system UI. Resolve labels with `PackageManager` and a `<queries>` launcher intent (avoids `QUERY_ALL_PACKAGES`). |
| 2.4 `PhubbNotificationListener` | 3C.4 | `onNotificationPosted` → `notifPosted` (skip ongoing/foreground-service notifications and our own). `onNotificationRemoved(sbn, rankingMap, reason)` with `REASON_CLICK` → `notifClicked` with `latencySec = removedAt − postTime`. Keys stay in memory only. **Never read notification text.** |
| 2.5 `BleScanner` + `ProximityTracker` | 3C.1 | Rules from Phase 1. Triggered by unlock/screen-on, plus a re-scan every 60 s while the screen is on. |
| 2.6 `AndroidPhoneEventSource` + `EventNormalizer` → `PhubEvent` | 3C.5 | Attach the proximity state at event time. Score with the aggregator. `flagged = proximity==near && score ≥ threshold && !whitelisted`. |
| 2.7 Manifest | 3E.1 | `PACKAGE_USAGE_STATS` (`tools:ignore="ProtectedPermissions"`), `BLUETOOTH_SCAN` (`usesPermissionFlags="neverForLocation"`), `BLUETOOTH_CONNECT`, legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` + `ACCESS_FINE_LOCATION` with `maxSdkVersion="30"`, `POST_NOTIFICATIONS`, `VIBRATE`, the `NotificationListenerService` declaration with `BIND_NOTIFICATION_LISTENER_SERVICE`. Set `android:label="Phubb-Free"`. |
| 2.8 Real `PermissionService` | 3E.1–3E.3 | Runtime permissions via `permission_handler` (bluetoothScan, bluetoothConnect, notification). Special permissions via MethodChannel: usage access = `AppOpsManager` `OPSTR_GET_USAGE_STATS` check + `Settings.ACTION_USAGE_ACCESS_SETTINGS`. Listener = `NotificationManagerCompat.getEnabledListenerPackages` + `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`. Re-check on `AppLifecycleState.resumed`. States: granted / denied / permanentlyDenied / notRequested. |
| 2.9 Onboarding wired to real grants + a prominent-disclosure page before usage access and notification access (Play requirement) | 3E.2 | `onboarding_screen.dart`. Add a 4th page for notification permission (Android 13+). |
| 2.10 Degradation matrix | 3E.4 | No usage access → monitoring can't start, show a blocking card. No BT → proximity `unknown`, no nudges (they need co-presence), stats still recorded. No listener → notification features use sentinel values, banner in Settings. |

**Done when:** on a real phone with the app open, unlocking, switching apps, and opening a notification each appear in
the feed within ~15 s with correct proximity, and all permission states show correctly after toggling them in system
Settings.

### Phase 3 — Local persistence (≈1 week)

| Task | Roadmap | Notes |
|---|---|---|
| 3.1 drift `AppDatabase`, `schemaVersion = 1`, migration test harness | 3F.1, 3F.6 | Tables: `events(id, ts, type, pkg, label, proximity, rssi, latency_sec, score, flagged)`, `nudges(id, ts, score, trigger_pkg, style, outcome[shown/thanks/not_now/ignored], outcome_ts)`, `copresence_intervals(start, end)`, `baseline_stats(feature, n, mean, m2, updated_at)`, `kv(key, value)` |
| 3.2 DAOs + retention job (delete > 90 days, run daily) | 3F.2 | Indexes on `events(ts)` and `nudges(ts)` |
| 3.3 Real `DaySummary` via SQL | 3F.3 | `phubMoments` = flagged events. `nudgesSent` = nudge rows. `unlocksNearPeople` = unlocks with proximity near. `phoneFreeTime` = co-presence time minus screen-on time inside it. `longestStretch` = longest co-presence gap with no unlock. **Write these definitions into the Insights "How is this measured?" sheet.** |
| 3.4 Real top apps | 3F.4 | `GROUP BY label WHERE flagged OR proximity='near'` over the period |
| 3.5 `PhubbingRepository` becomes a read model | 3F.2 | Remove `_generateDailySummaries` and the hard-coded `topApps`. Today's numbers come from the DB plus the live stream. |
| 3.6 Export & delete | 3F.5 | Export = JSON of all tables → `share_plus` share sheet (no storage permission needed). "Delete all data" = drop DB rows + prefs + baseline + the learned furniture list. |

**Done when:** the dashboard survives an app restart, and a 30-day dataset seeded in a test produces the expected
summaries (unit test on an in-memory drift DB).

### Phase 4 — Background service and real nudges (≈1.5 weeks)

| Task | Roadmap | Notes |
|---|---|---|
| 4.1 `flutter_background_service` foreground service. Persistent low-importance notification "Phubb-Free is on · tap to pause". Auto-start on boot (`RECEIVE_BOOT_COMPLETED`) if monitoring was on. | 3D.1 | Declare `foregroundServiceType` (start with `connectedDevice` + `FOREGROUND_SERVICE_CONNECTED_DEVICE`; if Play rejects it, use `specialUse` with a justification string). Check against current Play policy before submission. |
| 4.2 Move the pipeline into the service isolate: source → normalizer → proximity → aggregator → inference → `NudgePolicy` → DB | 3D.4 | Load `model_metadata.json` in the background isolate (call `DartPluginRegistrant.ensureInitialized()` first). The aggregator is rebuilt from the last hour of DB events on service start. |
| 4.3 Extract **`NudgePolicy`** (pure function: event, score, settings, history, now → decision) from `NudgeService`. Keep `NudgeService` only for the foreground overlay. | 3B.3 | Cooldown 10 min, max 3/hour, quiet hours, whitelist, style. All constants in one `NudgeConfig`. |
| 4.4 `NotificationNudger` | (gap 2) | Two channels (vibrate / silent). Action buttons **Thanks 👍** and **Not now**. Their callbacks, and auto-dismiss/timeout = `ignored`, write `nudges.outcome`. Vibration pattern scales with score (roadmap 6.2). |
| 4.5 UI ↔ service messaging | 3D.4 | Service → UI: `live_state` (monitoring, last score, proximity) and `db_changed`. UI → service: `settings_changed`, `pause`, `resume`. Settings are read in the service with `SharedPreferencesAsync`, so values are never stale. The home-screen monitoring toggle drives the service. |
| 4.6 Battery | 3D.3 | Prompt for `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with an explanation screen. Pause BLE re-scans when battery < 15 %. Show "last 24 h: N scans" in Settings → About. |

**Done when:** with the app swiped away, 30 min of real use near another person produces flagged events and at least
one notification nudge; the service survives Doze overnight; and the battery cost over 24 h is ≤ 5 % (Android
battery stats).

### Phase 5 — On-device personalization (Stage 4, ≈1 week)

Only features with non-zero weight and a behavioural meaning are personalized: indices **0, 2, 3, 4**
(unlocks, notification count, latency mean and median). App-switch (weight 0) and calendar features keep the
population scaler.

| Task | Roadmap | Notes |
|---|---|---|
| 5.1 `BaselineTracker`: Welford running mean/variance per personalized feature, sampled from the window every 15 min while the screen is on, persisted in `baseline_stats` | 4.1 | Runs in the service isolate |
| 5.2 `PersonalScaler`: `α = min(1, daysOfData / 14)`, `mean' = α·μ_user + (1−α)·μ_pop`, `scale' = α·σ_user + (1−α)·σ_pop` with σ floored at 25 % of σ_pop. `PhubInferenceService.predictProbability(x, scaler: ...)` | 4.2 | Pure, unit-tested |
| 5.3 Threshold offset from nudge outcomes: over the last 20 nudges, `not_now` rate > 60 % → +0.05; `thanks` rate > 50 % → −0.02. At most one step per day. Effective threshold = slider threshold + offset, clamped to [0.30, 0.80] | 4.3 | Uses the explicit buttons, not guessed dismissals |
| 5.4 Time-of-day multipliers (later in v1 if time allows): per-hour-bucket offset learned the same way | 4.4 | |
| 5.5 "Reset personalization" in Settings (clears baseline + offset) | 4.7 | |
| 5.6 Insights card: "Learned your patterns for N days · X % adapted" | 4.8 | |

**Done when:** unit tests show a heavy-user baseline (50 unlocks/h) scores a typical hour lower than the
population model does, and that reset gives back exactly the population output.

### Phase 6 — Testing and privacy hardening (≈1 week; tests are also written in each phase)

| Task | Roadmap | Notes |
|---|---|---|
| 6.1 Unit tests: `NudgePolicy`, `ProximityTracker`, app-switch rule, `BaselineTracker`, `PersonalScaler`, DAOs/summaries (in-memory drift), `SettingsController` round-trip | 5.2 | Target ≥ 80 % line coverage on `lib/services`, `lib/sensing`, `lib/data` |
| 6.2 Cross-language test vectors: a Python script writes 200 feature vectors + sklearn probabilities to `phubb_free_app/test/fixtures/lr_vectors.json`. A Dart test asserts the max difference is < 1e-6. | 5.5 | Also covers the latency sentinel |
| 6.3 Widget tests: onboarding states, settings toggles, feed tile expand, empty states with an empty DB | 5.3 | |
| 6.4 Integration test (`integration_test/`) on an emulator with `MockPhoneEventSource`: onboarding → dashboard → flagged event → nudge recorded → Insights updated | 5.4 | |
| 6.5 Privacy audit, as checks that can fail: (a) **the release APK has no `INTERNET` permission** (`aapt dump permissions` in CI); (b) `android:allowBackup="false"` + `dataExtractionRules` exclude the DB and prefs; (c) `flutter pub deps` contains no analytics or ads SDK; (d) notification content is never read (code review + test) | 5.7 | |
| 6.6 Python: add a test for the asset export (0.7) and the test-vector generator | 5.1 | |

### Phase 7 — Android release (≈1 week + review time)

| Task | Roadmap | Notes |
|---|---|---|
| 7.1 Final `applicationId` (it can't change after publishing), upload keystore + `key.properties` (gitignored), R8 enabled, `minSdk 26` | 7.1 | API 26+ gives `onNotificationRemoved` with a reason. `KEYGUARD_HIDDEN` needs 28; below that, fall back to the `USER_PRESENT` receiver. |
| 7.2 Icon and native splash (`flutter_launcher_icons`, `flutter_native_splash`) in Moss & Stone | 6.6 | |
| 7.3 Accessibility pass: semantics labels on charts, metric cards, and the hero number; contrast check; 200 % text scale | 6.4 | |
| 7.4 Privacy policy page (static page, e.g. GitHub Pages) + in-app link | 7.3 | Must match the Data safety form: *no data collected or shared* |
| 7.5 Play Console: Data safety, permission declarations (usage access, notification listener, foreground service type + demo video), prominent-disclosure screenshots, Health & Fitness category | 7.4, 7.5 | Personal developer accounts must run a **closed test with ≥ 12 testers for 14 days** before production access, so start the closed track as early as Phase 4. |
| 7.6 CI (GitHub Actions): analyze → test → build release AAB → INTERNET-permission check | 7.7 | Cheap, and it protects the privacy guarantee |

---

## 4. Timeline at a glance

```
Wk 1   Phase 0 stabilize ─┬─ Phase 1 BLE spike
Wk 2-3 Phase 2 sensors + permissions (foreground)
Wk 4   Phase 3 persistence
Wk 5-6 Phase 4 background service + notification nudges   ← start Play closed test here
Wk 7   Phase 5 personalization
Wk 8   Phase 6 testing + privacy hardening
Wk 9   Phase 7 release prep → production once the 14-day closed test completes
```

## 5. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| BLE can't see nearby Android phones reliably | Proximity gate misses, so nudges rarely fire | Phase 1 spike decides early. Document the limitation. Optional friend-pairing beacon (9.1). |
| Weak base model (AUC 0.59 vs a proxy label) | Noisy nudges | Proximity gate + conservative default threshold + explicit feedback loop (5.3). Keep the "proxy label" wording in the UI. |
| OEM battery killers (Xiaomi, Oppo, Samsung) stop the service | Gaps in monitoring | Battery-optimization exemption, foreground service, checkpointed UsageEvents (no data lost, only latency), "monitoring gap" marker in the feed |
| Play rejects a sensitive permission or the FGS type | Launch delay | Prominent disclosure, a narrow use of each permission, demo video, `specialUse` fallback |
| Two Flutter engines touching the same DB | Corruption / stale UI | Service is the only writer. UI opens read-only and refreshes on `db_changed`. |

## 6. Deferred, explicitly out of v1

iOS (D1) · crash reporting / analytics (D6) · location context (4.5) · on-device weight updates (4.6) ·
localization (6.5) · weekly summary notification (6.8) · gamification (6.9) · everything in Stage 9.

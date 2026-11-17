# BLE co-presence field test (Phase 1)

Goal: find out whether Phubb-Free can tell **"I'm with someone"** from **"I'm alone"** using only Bluetooth LE
advertisements, and freeze the rule before Phase 2 builds on it. Exit criterion (IMPLEMENTATION_PLAN.md):
**precision ≥ 0.7 and recall ≥ 0.5** for the default rule on real logs.

## What you need

- An Android phone (Android 8+; ideally 12+) with Developer options / USB debugging, plus a machine with the
  Android SDK (Android Studio) to build and `adb pull`.
- At least one companion with an **iPhone** and one with an **Android** phone. Their phones just need Bluetooth on.
  Nothing is installed on their phones.
- Keep the screen on during sessions: set Display → Screen timeout to 30 min. Android throttles or stops scans when the screen is off.

## Build and open the screen

```bash
cd phubb_free_app
flutter run            # debug build: the developer entry is visible
```

In the app, go to **Settings → About → "Developer: BLE field test"**. For a profile or release build, add
`--dart-define=PHUBB_DEV_TOOLS=true`. Grant **Nearby devices** when asked. On Android 11 and below the system also
asks for location, because Android requires it for any BLE scan there.

## Run the sessions

Each session runs a 6-second scan every 20 seconds. One cycle is one row in the log. **Set the ground truth before pressing
Start, and change it the moment reality changes** (a friend arrives or leaves).

- **Situation** chip: `alone_home`, `with_iphone`, `with_android`, `cafe`, `commute`, `other`.
- **People I'm with**: people you are *with*. Strangers at the next table don't count; they are exactly the
  false positives we want to measure.

| # | Situation | People I'm with | Duration | What it tests |
|---|---|---|---|---|
| 1 | alone_home, your own earbuds/watch on | 0 | 20 min | Own paired devices and home electronics must not count |
| 2 | with_iphone, sitting together (~1 m) | 1 | 20 min | iPhone recall |
| 3 | with_android, sitting together (~1 m) | 1 | 20 min | Android recall (the risky one) |
| 4 | cafe, alone | 0 | 20 min | False positives from strangers |
| 5 | cafe, with a friend | 1 | 20 min | Recall amid noise |
| 6 | commute (bus/train), alone | 0 | 15 min | Crowd false positives |

Repeat sessions 2–3 with the companion's phone in a pocket or bag, not on the table.

## Get the logs

Each session writes one CSV. The path is shown on screen:

```bash
adb pull /sdcard/Android/data/com.team4.phubb_free_app/files/ble_spike/ ./ble_spike_logs/
```

The CSV contains randomized device addresses, signal strengths, advert types and any broadcast device names (e.g.
"Alex's AirPods"). **Treat the logs as personal data:** keep them out of git and delete them when the analysis is done.

## Analyse

```bash
cd phubb_free_app
dart run tool/ble_replay.dart ../ble_spike_logs/*.csv
```

This prints:

1. **Default rule** (RSSI ≥ −75 dBm, 2-of-3 cycles, 10-minute hold), with and without the hold, marked ✔ if it meets
   the exit criterion.
2. **Sweep** over RSSI thresholds and k-of-n rules, best first.
3. **Per-situation near rate**. You want it high for `with_*` and low for `alone_home`, `cafe` (alone) and `commute`.
4. **Advert classification reasons**: which advert types appeared. Look here for Android phones (`google_nearby`,
   `samsung`) and for accessories that were misclassified.

## Decide and record

- **Default meets the criterion:** keep it. Write the numbers into IMPLEMENTATION_PLAN.md under Phase 1.
- **A sweep row meets it clearly better:** change the defaults in
  `lib/sensing/proximity/person_signal_classifier.dart` (`minRssi`) and `proximity_tracker.dart`
  (`ProximityTrackerConfig`), then re-run the tests.
- **Android-to-Android recall is poor** (likely, since many Android phones don't advertise continuously): document it
  as a known limitation in the plan. Then choose between shipping with "iPhone and Samsung companions only" or adding the
  opt-in friend-pairing beacon (roadmap 9.1) before relying on Android co-presence.
- **Classifier mistakes** (e.g. Galaxy Buds counted as `samsung` phones): adjust the rules in
  `person_signal_classifier.dart`, add a unit test in `test/proximity_test.dart`, and re-run the replay.

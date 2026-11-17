import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'phub_event.dart';
import '../sensing/phone_event_source.dart';
import '../services/phub_inference_service.dart';
import '../services/rolling_window_aggregator.dart';

/// Turns raw phone events from a [PhoneEventSource] into scored, flagged
/// [PhubEvent]s and keeps the in-memory state the UI shows.
///
/// Pipeline per event: record in the rolling window → score the window with
/// the model → flag if someone is near AND score ≥ [flagThreshold].
///
/// ⚠️ Daily summaries and top apps are still MOCK data; Phase 3 of
/// IMPLEMENTATION_PLAN.md replaces them with SQLite-backed queries.
class PhubbingRepository extends ChangeNotifier {
  PhubbingRepository({required this._source});

  final PhoneEventSource _source;
  StreamSubscription<RawPhoneEvent>? _sourceSub;
  final Random _rng = Random();

  PhubInferenceService? _inferenceService;
  final RollingWindowAggregator _aggregator = RollingWindowAggregator();

  /// Attach the inference service (call once from main.dart after load).
  void attachInferenceService(PhubInferenceService service) {
    _inferenceService = service;
  }

  /// Model probability at or above which a near-someone event is flagged.
  /// Kept in sync with the user's sensitivity setting by main.dart.
  double flagThreshold = 0.5;

  /// The most recent phubbing probability from the model (0.0–1.0).
  double _lastProbability = 0.0;
  double get lastProbability => _lastProbability;

  bool _monitoring = true;
  bool get isMonitoring => _monitoring;

  // ── Live event stream ────────────────────────────────────────
  final _eventController = StreamController<PhubEvent>.broadcast();
  Stream<PhubEvent> get eventStream => _eventController.stream;

  final List<PhubEvent> _events = [];
  List<PhubEvent> get recentEvents => List.unmodifiable(_events);

  // ── Cached daily summaries (mock until Phase 3) ──────────────
  late final List<DaySummary> _dailySummaries = _generateDailySummaries(30);

  List<DaySummary> dailySummaries(int days) {
    return _dailySummaries.take(days).toList();
  }

  DaySummary get today => _dailySummaries.first;

  DaySummary? get yesterday =>
      _dailySummaries.length > 1 ? _dailySummaries[1] : null;

  // ── Top apps during social moments (mock until Phase 3) ──────
  List<AppSocialUsage> get topApps => const [
    AppSocialUsage(appName: 'WhatsApp', count: 12),
    AppSocialUsage(appName: 'Instagram', count: 8),
    AppSocialUsage(appName: 'Twitter', count: 5),
    AppSocialUsage(appName: 'YouTube', count: 3),
    AppSocialUsage(appName: 'Gmail', count: 2),
  ];

  /// Week-over-week trend (percentage change, negative = improvement).
  int get weeklyTrend {
    if (_dailySummaries.length < 14) return 0;
    final thisWeek = _dailySummaries
        .take(7)
        .fold<int>(0, (sum, d) => sum + d.phubMoments);
    final lastWeek = _dailySummaries
        .skip(7)
        .take(7)
        .fold<int>(0, (sum, d) => sum + d.phubMoments);
    if (lastWeek == 0) return 0;
    return (((thisWeek - lastWeek) / lastWeek) * 100).round();
  }

  // ── Monitoring control ───────────────────────────────────────

  /// Subscribes to the source and starts it. Call once from main.dart.
  Future<void> start() async {
    _sourceSub ??= _source.events.listen(handleRawEvent);
    if (_monitoring) await _source.start();
  }

  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    notifyListeners();
    _source.start();
  }

  void pauseMonitoring() {
    _monitoring = false;
    _source.stop();
    notifyListeners();
  }

  void toggleMonitoring() {
    if (_monitoring) {
      pauseMonitoring();
    } else {
      startMonitoring();
    }
  }

  /// Scores one raw event, records it, and emits the resulting [PhubEvent].
  /// Public for tests.
  @visibleForTesting
  PhubEvent handleRawEvent(RawPhoneEvent raw) {
    var event = PhubEvent(
      id: raw.timestamp.microsecondsSinceEpoch.toString(),
      type: raw.type,
      timestamp: raw.timestamp,
      appName: raw.appName,
      appPackage: raw.appPackage,
      proximity: raw.proximity,
      rssi: raw.rssi,
      responseLatencySec: raw.responseLatencySec,
    );

    _aggregator.record(event);

    final model = _inferenceService;
    if (model != null && model.isReady) {
      _lastProbability = _aggregator.currentProbability(
        model,
        now: raw.timestamp,
      );
      event = event.copyWith(
        phubScore: _lastProbability,
        flagged: event.someoneNearby && _lastProbability >= flagThreshold,
      );
    }

    _events.insert(0, event);
    if (_events.length > 50) _events.removeLast();
    _eventController.add(event);

    final t = _dailySummaries[0];
    _dailySummaries[0] = DaySummary(
      date: t.date,
      phubMoments: t.phubMoments + (event.flagged ? 1 : 0),
      nudgesSent: t.nudgesSent,
      phoneFreeTime: t.phoneFreeTime,
      longestStretch: t.longestStretch,
      unlocksNearPeople:
          t.unlocksNearPeople +
          (event.type == PhubEventType.unlock && event.someoneNearby ? 1 : 0),
    );
    notifyListeners();
    return event;
  }

  List<DaySummary> _generateDailySummaries(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final date = now.subtract(Duration(days: i));
      final phub = i == 0 ? 3 : 1 + _rng.nextInt(10);
      return DaySummary(
        date: date,
        phubMoments: phub,
        nudgesSent: (phub * 0.7).round(),
        phoneFreeTime: Duration(
          hours: 1 + _rng.nextInt(4),
          minutes: _rng.nextInt(60),
        ),
        longestStretch: Duration(minutes: 20 + _rng.nextInt(100)),
        unlocksNearPeople: _rng.nextInt(8),
      );
    });
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    _source.dispose();
    _eventController.close();
    super.dispose();
  }
}

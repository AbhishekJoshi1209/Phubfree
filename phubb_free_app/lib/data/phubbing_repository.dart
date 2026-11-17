import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'phub_event.dart';
import '../services/phub_inference_service.dart';
import '../services/rolling_window_aggregator.dart';

/// Mock data source that generates realistic phubbing events for demo purposes.
/// Implements the same interface a real sensor backend would provide.
///
/// ⚠️ MOCK: Replace with real sensor collection in production.
class PhubbingRepository extends ChangeNotifier {
  final Random _rng = Random();
  Timer? _timer;

  /// Optional inference service for model-based phubbing detection.
  /// When null, falls back to random mock flagging.
  PhubInferenceService? _inferenceService;
  final RollingWindowAggregator _aggregator = RollingWindowAggregator();

  /// The most recent phubbing probability from the model (0.0–1.0).
  double _lastProbability = 0.0;
  double get lastProbability => _lastProbability;

  /// Attach the inference service (call once from main.dart after load).
  void attachInferenceService(PhubInferenceService service) {
    _inferenceService = service;
  }

  bool _monitoring = true;
  bool get isMonitoring => _monitoring;

  // ── Live event stream ────────────────────────────────────────
  final _eventController = StreamController<PhubEvent>.broadcast();
  Stream<PhubEvent> get eventStream => _eventController.stream;

  final List<PhubEvent> _events = [];
  List<PhubEvent> get recentEvents => List.unmodifiable(_events);

  // ── Cached daily summaries (mock) ────────────────────────────
  late final List<DaySummary> _dailySummaries = _generateDailySummaries(30);

  List<DaySummary> dailySummaries(int days) {
    return _dailySummaries.take(days).toList();
  }

  DaySummary get today => _dailySummaries.first;

  DaySummary? get yesterday =>
      _dailySummaries.length > 1 ? _dailySummaries[1] : null;

  // ── Top apps during social moments ───────────────────────────
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
  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    notifyListeners();
    _scheduleNextEvent();
  }

  void pauseMonitoring() {
    _monitoring = false;
    _timer?.cancel();
    notifyListeners();
  }

  void toggleMonitoring() {
    if (_monitoring) {
      pauseMonitoring();
    } else {
      startMonitoring();
    }
  }

  /// Call from initState to begin emitting mock events.
  void start() {
    _scheduleNextEvent();
  }

  void _scheduleNextEvent() {
    if (!_monitoring) return;
    final delay = Duration(seconds: 3 + _rng.nextInt(6));
    _timer = Timer(delay, () {
      final event = _generateEvent();

      // Feed event into the rolling window for feature aggregation.
      _aggregator.record(event);

      // Score the current window with the real model (if available).
      final model = _inferenceService;
      if (model != null && model.isReady) {
        _lastProbability = _aggregator.currentProbability(model);
      }

      _events.insert(0, event);
      if (_events.length > 50) _events.removeLast();
      _eventController.add(event);
      // Update today's summary with this new event
      _dailySummaries[0] = DaySummary(
        date: _dailySummaries[0].date,
        phubMoments: _dailySummaries[0].phubMoments + (event.isPossiblePhubbing ? 1 : 0),
        nudgesSent: _dailySummaries[0].nudgesSent + (event.isPossiblePhubbing ? 1 : 0),
        phoneFreeTime: _dailySummaries[0].phoneFreeTime,
        longestStretch: _dailySummaries[0].longestStretch,
        unlocksNearPeople: _dailySummaries[0].unlocksNearPeople +
            (event.type == PhubEventType.unlock && event.nearbyPersonDetected ? 1 : 0),
      );
      notifyListeners();
      _scheduleNextEvent();
    });
  }

  PhubEvent _generateEvent() {
    final types = PhubEventType.values;
    final type = types[_rng.nextInt(types.length)];
    final apps = ['WhatsApp', 'Instagram', 'Twitter', 'YouTube', 'Gmail', 'Reddit'];
    final packages = [
      'com.whatsapp',
      'com.instagram.android',
      'com.twitter.android',
      'com.google.android.youtube',
      'com.google.android.gm',
      'com.reddit.frontpage',
    ];
    final appIdx = _rng.nextInt(apps.length);

    // Simulate proximity: ~60% chance someone is nearby (mock BLE).
    final proximityDetected = _rng.nextDouble() < 0.6;

    // Use the model's prediction to determine if this is a phubbing moment,
    // but only when someone is actually nearby (proxy label definition).
    // Falls back to random when no model is attached.
    final model = _inferenceService;
    final bool modelSaysPhubbing;
    if (model != null && model.isReady && proximityDetected) {
      // Build a temporary event to get features, then score.
      // We peek at what the aggregator would say *after* adding this event.
      modelSaysPhubbing = _lastProbability >= (model.defaultThreshold);
    } else {
      modelSaysPhubbing = proximityDetected && _rng.nextBool();
    }

    return PhubEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime.now(),
      appName: type == PhubEventType.appSwitch ? apps[appIdx] : '',
      appPackage: type == PhubEventType.appSwitch ? packages[appIdx] : '',
      nearbyPersonDetected: modelSaysPhubbing,
      rssi: proximityDetected ? -60 - _rng.nextInt(30) : null,
      responseLatencySec:
          type == PhubEventType.notification ? _rng.nextInt(20) : null,
    );
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
        phoneFreeTime: Duration(hours: 1 + _rng.nextInt(4), minutes: _rng.nextInt(60)),
        longestStretch: Duration(minutes: 20 + _rng.nextInt(100)),
        unlocksNearPeople: _rng.nextInt(8),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eventController.close();
    super.dispose();
  }
}

import 'dart:collection';

import '../data/phub_event.dart';
import 'phub_inference_service.dart';

/// A timestamped record kept in the rolling window buffer.
///
/// We track just enough per-event to recompute the 8 model features at
/// any point without re-scanning raw sensor streams.
class _BufferEntry {
  final DateTime timestamp;
  final PhubEventType type;
  final int? responseLatencySec;

  const _BufferEntry({
    required this.timestamp,
    required this.type,
    this.responseLatencySec,
  });
}

/// Maintains a 60-minute sliding window of phone-usage events and computes
/// the feature vector expected by [PhubInferenceService].
///
/// ### Usage
/// ```dart
/// final agg = RollingWindowAggregator();
/// agg.record(event);              // call on every PhubEvent
/// final prob = agg.currentProbability(inferenceService);
/// ```
///
/// ⚠️ This class is **not** thread-safe. Call [record] and the query methods
/// from the same isolate (the UI isolate is fine for the expected event rate).
class RollingWindowAggregator {
  /// Duration of the sliding window.
  static const windowDuration = Duration(hours: 1);

  /// Value used for the latency features when the window has no notification
  /// latency data. Must match `LATENCY_SENTINEL` in
  /// `phubb_free/model/preprocessing.py`, which the model was trained with.
  static const double latencySentinel = -1.0;

  /// Internal ring-buffer of recent events, newest last.
  final Queue<_BufferEntry> _buffer = Queue<_BufferEntry>();

  // ── Recording ─────────────────────────────────────────────────────

  /// Records a [PhubEvent] into the sliding window.
  ///
  /// Automatically evicts entries older than [windowDuration].
  void record(PhubEvent event) {
    _buffer.addLast(
      _BufferEntry(
        timestamp: event.timestamp,
        type: event.type,
        responseLatencySec: event.responseLatencySec,
      ),
    );
    _evict(event.timestamp);
  }

  /// Removes entries that have fallen outside the window relative to [now].
  void _evict(DateTime now) {
    final cutoff = now.subtract(windowDuration);
    while (_buffer.isNotEmpty && _buffer.first.timestamp.isBefore(cutoff)) {
      _buffer.removeFirst();
    }
  }

  // ── Feature extraction ────────────────────────────────────────────

  /// Number of unlock events in the current window.
  int get unlockCount =>
      _buffer.where((e) => e.type == PhubEventType.unlock).length;

  /// Number of app-switch events in the current window.
  int get appSwitchCount =>
      _buffer.where((e) => e.type == PhubEventType.appSwitch).length;

  /// Number of notification events in the current window.
  int get notifCount =>
      _buffer.where((e) => e.type == PhubEventType.notification).length;

  /// Mean notification response latency (seconds) over the window.
  ///
  /// Returns [latencySentinel] if there are no notification events with
  /// latency data.
  double get notifRespLatencyMean {
    final latencies = _buffer
        .where(
          (e) =>
              e.type == PhubEventType.notification &&
              e.responseLatencySec != null,
        )
        .map((e) => e.responseLatencySec!)
        .toList();
    if (latencies.isEmpty) return latencySentinel;
    return latencies.reduce((a, b) => a + b) / latencies.length;
  }

  /// Median notification response latency (seconds) over the window.
  ///
  /// Returns [latencySentinel] if there are no notification events with
  /// latency data.
  double get notifRespLatencyMedian {
    final latencies =
        _buffer
            .where(
              (e) =>
                  e.type == PhubEventType.notification &&
                  e.responseLatencySec != null,
            )
            .map((e) => e.responseLatencySec!)
            .toList()
          ..sort();
    if (latencies.isEmpty) return latencySentinel;
    final mid = latencies.length ~/ 2;
    if (latencies.length.isOdd) {
      return latencies[mid].toDouble();
    }
    return (latencies[mid - 1] + latencies[mid]) / 2.0;
  }

  /// Total events currently in the buffer.
  int get bufferSize => _buffer.length;

  // ── Inference bridge ──────────────────────────────────────────────

  /// Builds the raw feature vector from the current window state.
  ///
  /// [now] defaults to `DateTime.now()` if omitted.
  List<double> buildFeatures({DateTime? now}) {
    final t = now ?? DateTime.now();
    _evict(t);
    return PhubInferenceService.buildFeatureVector(
      unlockCountLastHour: unlockCount,
      appSwitchCountLastHour: appSwitchCount,
      notifCountLastHour: notifCount,
      notifRespLatencyMeanSec: notifRespLatencyMean,
      notifRespLatencyMedianSec: notifRespLatencyMedian,
      now: t,
    );
  }

  /// Returns the model's phubbing probability for the current window.
  ///
  /// Convenience wrapper that builds features → scales → runs sigmoid.
  double currentProbability(PhubInferenceService model, {DateTime? now}) {
    if (!model.isReady) return 0.0;
    return model.predictProbability(buildFeatures(now: now));
  }

  /// Returns `true` if the model thinks this is a phubbing moment.
  bool isPhubbing(
    PhubInferenceService model, {
    double? threshold,
    DateTime? now,
  }) {
    if (!model.isReady) return false;
    return model.predict(buildFeatures(now: now), threshold: threshold);
  }

  /// Clears the buffer (e.g. when monitoring is paused and resumed).
  void clear() => _buffer.clear();
}

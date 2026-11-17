import 'package:flutter_test/flutter_test.dart';
import 'package:phubb_free_app/data/phub_event.dart';
import 'package:phubb_free_app/services/phub_inference_service.dart';
import 'package:phubb_free_app/services/rolling_window_aggregator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PhubEvent _makeEvent(
    PhubEventType type, {
    required DateTime timestamp,
    int? responseLatencySec,
  }) {
    return PhubEvent(
      id: timestamp.microsecondsSinceEpoch.toString(),
      type: type,
      timestamp: timestamp,
      responseLatencySec: responseLatencySec,
    );
  }

  group('RollingWindowAggregator', () {
    late RollingWindowAggregator agg;

    setUp(() {
      agg = RollingWindowAggregator();
    });

    test('starts with empty buffer and zero counts', () {
      expect(agg.bufferSize, 0);
      expect(agg.unlockCount, 0);
      expect(agg.appSwitchCount, 0);
      expect(agg.notifCount, 0);
      expect(agg.notifRespLatencyMean, 0.0);
      expect(agg.notifRespLatencyMedian, 0.0);
    });

    test('records events and updates counts', () {
      final now = DateTime(2026, 10, 18, 14, 0, 0);
      agg.record(_makeEvent(PhubEventType.unlock, timestamp: now));
      agg.record(_makeEvent(PhubEventType.unlock,
          timestamp: now.add(const Duration(seconds: 10))));
      agg.record(_makeEvent(PhubEventType.appSwitch,
          timestamp: now.add(const Duration(seconds: 20))));

      expect(agg.bufferSize, 3);
      expect(agg.unlockCount, 2);
      expect(agg.appSwitchCount, 1);
      expect(agg.notifCount, 0);
    });

    test('evicts entries older than 1 hour', () {
      final t0 = DateTime(2026, 10, 18, 12, 0, 0);
      final t1 = t0.add(const Duration(minutes: 30));
      final t2 = t0.add(const Duration(minutes: 61)); // past the window

      agg.record(_makeEvent(PhubEventType.unlock, timestamp: t0));
      agg.record(_makeEvent(PhubEventType.unlock, timestamp: t1));
      agg.record(_makeEvent(PhubEventType.unlock, timestamp: t2));

      // After adding t2, t0 should be evicted (>60 min before t2).
      expect(agg.bufferSize, 2); // t1 and t2 remain
      expect(agg.unlockCount, 2);
    });

    test('computes mean latency correctly', () {
      final now = DateTime(2026, 10, 18, 14, 0, 0);
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now, responseLatencySec: 10));
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now.add(const Duration(seconds: 5)),
          responseLatencySec: 20));
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now.add(const Duration(seconds: 10)),
          responseLatencySec: 30));

      expect(agg.notifRespLatencyMean, closeTo(20.0, 0.001));
    });

    test('computes median latency correctly for odd count', () {
      final now = DateTime(2026, 10, 18, 14, 0, 0);
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now, responseLatencySec: 5));
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now.add(const Duration(seconds: 1)),
          responseLatencySec: 15));
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now.add(const Duration(seconds: 2)),
          responseLatencySec: 100));

      // Sorted: [5, 15, 100] → median = 15
      expect(agg.notifRespLatencyMedian, 15.0);
    });

    test('computes median latency correctly for even count', () {
      final now = DateTime(2026, 10, 18, 14, 0, 0);
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now, responseLatencySec: 10));
      agg.record(_makeEvent(PhubEventType.notification,
          timestamp: now.add(const Duration(seconds: 1)),
          responseLatencySec: 20));

      // Sorted: [10, 20] → median = 15
      expect(agg.notifRespLatencyMedian, 15.0);
    });

    test('buildFeatures produces 8-element vector', () {
      final now = DateTime(2026, 10, 18, 14, 0, 0);
      agg.record(_makeEvent(PhubEventType.unlock, timestamp: now));
      final features = agg.buildFeatures(now: now);
      expect(features.length, 8);
      expect(features[0], 1.0);        // 1 unlock
      expect(features[5], 14.0);       // hour_of_day
    });

    test('clear resets the buffer', () {
      final now = DateTime(2026, 10, 18, 14, 0, 0);
      agg.record(_makeEvent(PhubEventType.unlock, timestamp: now));
      agg.record(_makeEvent(PhubEventType.appSwitch, timestamp: now));
      expect(agg.bufferSize, 2);

      agg.clear();
      expect(agg.bufferSize, 0);
      expect(agg.unlockCount, 0);
    });

    test('end-to-end: aggregator feeds inference service', () async {
      final model = PhubInferenceService();
      await model.load();

      final now = DateTime(2026, 10, 18, 14, 0, 0);
      // Simulate a burst of activity
      for (int i = 0; i < 20; i++) {
        agg.record(_makeEvent(
          PhubEventType.unlock,
          timestamp: now.add(Duration(seconds: i * 10)),
        ));
      }
      for (int i = 0; i < 5; i++) {
        agg.record(_makeEvent(
          PhubEventType.notification,
          timestamp: now.add(Duration(seconds: 200 + i * 10)),
          responseLatencySec: 3 + i,
        ));
      }

      final prob = agg.currentProbability(model,
          now: now.add(const Duration(seconds: 250)));
      expect(prob, greaterThanOrEqualTo(0.0));
      expect(prob, lessThanOrEqualTo(1.0));

      // With 20 unlocks in the window (way above the training mean of ~11),
      // and the positive weight on unlock_freq, probability should be elevated.
      expect(prob, greaterThan(0.5));
    });
  });
}

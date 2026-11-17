import 'package:flutter_test/flutter_test.dart';
import 'package:phubb_free_app/services/phub_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhubInferenceService', () {
    late PhubInferenceService service;

    setUp(() async {
      service = PhubInferenceService();
      await service.load();
    });

    test('loads successfully and reports ready', () {
      expect(service.isReady, isTrue);
      expect(service.featureNames.length, equals(8));
      expect(service.defaultThreshold, equals(0.5));
    });

    test('feature names match model spec', () {
      expect(service.featureNames, [
        'unlock_freq_1h',
        'app_switch_rate_1h',
        'notif_count_1h',
        'notif_resp_latency_mean_1h',
        'notif_resp_latency_median_1h',
        'hour_of_day',
        'day_of_week',
        'is_weekend',
      ]);
    });

    test('returns probability in [0, 1]', () {
      final prob = service.predictProbability([
        5.0, // unlock_freq_1h
        0.0, // app_switch_rate_1h
        3.0, // notif_count_1h
        120.0, // notif_resp_latency_mean_1h
        90.0, // notif_resp_latency_median_1h
        14.0, // hour_of_day
        2.0, // day_of_week (Wednesday)
        0.0, // is_weekend
      ]);
      expect(prob, greaterThanOrEqualTo(0.0));
      expect(prob, lessThanOrEqualTo(1.0));
    });

    test('high activity near mean produces ~0.5 probability', () {
      // Features near training mean should produce logit ≈ bias ≈ 0.026,
      // yielding probability ≈ sigmoid(0.026) ≈ 0.506
      final prob = service.predictProbability([
        11.17,
        0.0,
        16.14,
        551.74,
        421.20,
        13.87,
        3.02,
        0.27,
      ]);
      expect(prob, closeTo(0.506, 0.05));
    });

    test('very high unlock frequency increases phubbing probability', () {
      final baseline = service.predictProbability([
        11.17,
        0.0,
        16.14,
        551.74,
        421.20,
        13.87,
        3.02,
        0.0,
      ]);
      final highUnlock = service.predictProbability([
        80.0,
        0.0,
        16.14,
        551.74,
        421.20,
        13.87,
        3.02,
        0.0,
      ]);
      // Weight for unlock_freq_1h is positive (0.773), so more unlocks → higher prob.
      expect(highUnlock, greaterThan(baseline));
    });

    test('throws on wrong feature count', () {
      expect(() => service.predictProbability([1.0, 2.0]), throwsArgumentError);
    });

    test('throws if called before load', () {
      final fresh = PhubInferenceService();
      expect(
        () => fresh.predictProbability([0, 0, 0, 0, 0, 0, 0, 0]),
        throwsA(isA<StateError>()),
      );
    });

    test('buildFeatureVector produces correct shape and weekend flag', () {
      // A Saturday at 15:00
      final saturday = DateTime(2026, 10, 17, 15, 30);
      final features = PhubInferenceService.buildFeatureVector(
        unlockCountLastHour: 7,
        appSwitchCountLastHour: 3,
        notifCountLastHour: 5,
        notifRespLatencyMeanSec: 45.0,
        notifRespLatencyMedianSec: 30.0,
        now: saturday,
      );
      expect(features.length, 8);
      expect(features[0], 7.0); // unlock_freq_1h
      expect(features[5], 15.0); // hour_of_day
      expect(features[7], 1.0); // is_weekend (Saturday)

      // A Wednesday at 10:00
      final wednesday = DateTime(2026, 10, 14, 10, 0);
      final weekdayFeatures = PhubInferenceService.buildFeatureVector(
        unlockCountLastHour: 2,
        appSwitchCountLastHour: 0,
        notifCountLastHour: 1,
        notifRespLatencyMeanSec: 10.0,
        notifRespLatencyMedianSec: 10.0,
        now: wednesday,
      );
      expect(weekdayFeatures[7], 0.0); // is_weekend (Wednesday)
      expect(weekdayFeatures[6], 2.0); // day_of_week (Wed = 3 in Dart, -1 = 2)
    });
  });
}

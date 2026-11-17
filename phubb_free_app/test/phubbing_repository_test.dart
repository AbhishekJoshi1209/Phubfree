import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:phubb_free_app/data/phub_event.dart';
import 'package:phubb_free_app/data/phubbing_repository.dart';
import 'package:phubb_free_app/sensing/mock_phone_event_source.dart';
import 'package:phubb_free_app/sensing/phone_event_source.dart';
import 'package:phubb_free_app/services/phub_inference_service.dart';
import 'package:phubb_free_app/services/rolling_window_aggregator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PhubInferenceService model;
  late PhubbingRepository repo;

  setUp(() async {
    model = PhubInferenceService();
    await model.load();
    repo = PhubbingRepository(source: MockPhoneEventSource())
      ..attachInferenceService(model);
  });

  RawPhoneEvent raw(ProximityState proximity, DateTime t) => RawPhoneEvent(
    type: PhubEventType.unlock,
    timestamp: t,
    proximity: proximity,
  );

  final t = DateTime(2026, 11, 17, 14);

  test('model score never flags an event when nobody is near', () {
    repo.flagThreshold = 0.0; // any score would pass
    final e = repo.handleRawEvent(raw(ProximityState.notNear, t));
    expect(e.phubScore, isNotNull);
    expect(e.flagged, isFalse);
    expect(e.someoneNearby, isFalse);
  });

  test('unknown proximity is never flagged', () {
    repo.flagThreshold = 0.0;
    final e = repo.handleRawEvent(raw(ProximityState.unknown, t));
    expect(e.flagged, isFalse);
  });

  test('near + score above threshold is flagged; below is not', () {
    repo.flagThreshold = 0.0;
    expect(repo.handleRawEvent(raw(ProximityState.near, t)).flagged, isTrue);

    repo.flagThreshold = 1.01;
    final e = repo.handleRawEvent(
      raw(ProximityState.near, t.add(const Duration(seconds: 1))),
    );
    expect(e.someoneNearby, isTrue); // the sensor fact is kept…
    expect(e.flagged, isFalse); // …separately from the model verdict
  });

  test('score matches the aggregator for the same window', () {
    final e = repo.handleRawEvent(raw(ProximityState.near, t));
    final agg = RollingWindowAggregator()
      ..record(PhubEvent(id: '1', type: PhubEventType.unlock, timestamp: t));
    expect(e.phubScore, closeTo(agg.currentProbability(model, now: t), 1e-12));
    expect(repo.lastProbability, e.phubScore);
  });

  test('createPhoneEventSource defaults to mock and rejects unknown names', () {
    expect(createPhoneEventSource('mock'), isA<MockPhoneEventSource>());
    expect(() => createPhoneEventSource('device'), throwsUnimplementedError);
    expect(() => createPhoneEventSource('nope'), throwsArgumentError);
  });

  test(
    'aggregator latency sentinel matches the exported model metadata',
    () async {
      final meta = json.decode(
        await rootBundle.loadString('assets/models/model_metadata.json'),
      );
      expect(meta['latency_sentinel'], RollingWindowAggregator.latencySentinel);
    },
  );
}

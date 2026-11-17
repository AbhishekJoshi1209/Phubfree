import '../data/phub_event.dart';
import 'mock_phone_event_source.dart';

/// An unscored phone-interaction event as produced by a sensor source.
///
/// The repository scores it with the model and turns it into a [PhubEvent].
class RawPhoneEvent {
  final PhubEventType type;
  final DateTime timestamp;
  final String appName;
  final String appPackage;
  final int? responseLatencySec;

  /// Proximity at event time. Real sources leave this `unknown` until the
  /// BLE proximity tracker lands (Phase 2); the mock source simulates it.
  final ProximityState proximity;
  final int? rssi;

  const RawPhoneEvent({
    required this.type,
    required this.timestamp,
    this.appName = '',
    this.appPackage = '',
    this.responseLatencySec,
    this.proximity = ProximityState.unknown,
    this.rssi,
  });
}

/// A stream of phone-interaction events. The mock and real (Android)
/// implementations are interchangeable behind this interface.
abstract class PhoneEventSource {
  Stream<RawPhoneEvent> get events;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// Which source to use, chosen at build time:
/// `flutter run --dart-define=PHUBB_SOURCE=mock|device` (default `mock`).
const String phubbSourceName = String.fromEnvironment(
  'PHUBB_SOURCE',
  defaultValue: 'mock',
);

PhoneEventSource createPhoneEventSource([String name = phubbSourceName]) {
  switch (name) {
    case 'mock':
      return MockPhoneEventSource();
    case 'device':
      throw UnimplementedError(
        'PHUBB_SOURCE=device: the Android sensor source is built in Phase 2 '
        'of IMPLEMENTATION_PLAN.md. Use PHUBB_SOURCE=mock for now.',
      );
    default:
      throw ArgumentError.value(name, 'PHUBB_SOURCE', 'expected mock|device');
  }
}

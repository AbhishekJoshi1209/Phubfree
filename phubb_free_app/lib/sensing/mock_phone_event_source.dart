import 'dart:async';
import 'dart:math';

import '../data/phub_event.dart';
import 'phone_event_source.dart';

/// Demo source that emits a random event every 3–8 seconds, with simulated
/// BLE proximity (~60 % of events have someone nearby).
///
/// ⚠️ MOCK: for demos, UI work and tests only.
class MockPhoneEventSource implements PhoneEventSource {
  MockPhoneEventSource({Random? random}) : _rng = random ?? Random();

  final Random _rng;
  final _controller = StreamController<RawPhoneEvent>.broadcast();
  Timer? _timer;
  bool _running = false;

  static const _apps = [
    ('WhatsApp', 'com.whatsapp'),
    ('Instagram', 'com.instagram.android'),
    ('Twitter', 'com.twitter.android'),
    ('YouTube', 'com.google.android.youtube'),
    ('Gmail', 'com.google.android.gm'),
    ('Reddit', 'com.reddit.frontpage'),
  ];

  @override
  Stream<RawPhoneEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _scheduleNext();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  void _scheduleNext() {
    if (!_running) return;
    _timer = Timer(Duration(seconds: 3 + _rng.nextInt(6)), () {
      _controller.add(generate(DateTime.now()));
      _scheduleNext();
    });
  }

  /// Builds one random event. Public so tests can drive it without timers.
  RawPhoneEvent generate(DateTime now) {
    final type =
        PhubEventType.values[_rng.nextInt(PhubEventType.values.length)];
    final app = _apps[_rng.nextInt(_apps.length)];
    final near = _rng.nextDouble() < 0.6;
    return RawPhoneEvent(
      type: type,
      timestamp: now,
      appName: type == PhubEventType.appSwitch ? app.$1 : '',
      appPackage: type == PhubEventType.appSwitch ? app.$2 : '',
      responseLatencySec: type == PhubEventType.notification
          ? _rng.nextInt(20)
          : null,
      proximity: near ? ProximityState.near : ProximityState.notNear,
      rssi: near ? -60 - _rng.nextInt(30) : null,
    );
  }
}

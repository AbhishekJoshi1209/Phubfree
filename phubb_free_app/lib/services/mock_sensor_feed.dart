import 'dart:async';
import 'dart:math';
import '../models/sensor_event.dart';

class MockSensorFeed {
  final _controller = StreamController<SensorEvent>.broadcast();
  Timer? _timer;
  final Random _random = Random();

  Stream<SensorEvent> get eventStream => _controller.stream;

  void start() {
    // Emit a mock event every 2 to 5 seconds
    _scheduleNextEvent();
  }

  void _scheduleNextEvent() {
    final delay = Duration(seconds: 2 + _random.nextInt(4));
    _timer = Timer(delay, () {
      _controller.add(_generateRandomEvent());
      _scheduleNextEvent();
    });
  }

  SensorEvent _generateRandomEvent() {
    final types = SensorEventType.values;
    final type = types[_random.nextInt(types.length)];
    
    Map<String, dynamic> data = {};
    if (type == SensorEventType.proximity) {
      data['rssi'] = -60 - _random.nextInt(30); // e.g. -60 to -89
    } else if (type == SensorEventType.appSwitch) {
      final apps = ['com.whatsapp', 'com.instagram.android', 'com.twitter.android'];
      data['app_name'] = apps[_random.nextInt(apps.length)];
    } else if (type == SensorEventType.notification) {
      data['response_latency_sec'] = _random.nextInt(20);
    }
    
    return SensorEvent(
      type: type,
      timestamp: DateTime.now(),
      data: data,
    );
  }

  void stop() {
    _timer?.cancel();
    _controller.close();
  }
}

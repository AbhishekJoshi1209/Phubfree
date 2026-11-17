enum SensorEventType {
  unlock,
  appSwitch,
  notification,
  proximity
}

class SensorEvent {
  final SensorEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  SensorEvent({
    required this.type,
    required this.timestamp,
    this.data = const {},
  });

  @override
  String toString() {
    return 'SensorEvent($type, $timestamp, $data)';
  }
}

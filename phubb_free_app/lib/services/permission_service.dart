import 'package:flutter/foundation.dart';

class PermissionService extends ChangeNotifier {
  bool _usageAccessGranted = false;
  bool _notificationAccessGranted = false;
  bool _bluetoothGranted = false;

  bool get usageAccessGranted => _usageAccessGranted;
  bool get notificationAccessGranted => _notificationAccessGranted;
  bool get bluetoothGranted => _bluetoothGranted;

  bool get allGranted =>
      _usageAccessGranted && _notificationAccessGranted && _bluetoothGranted;

  Future<void> requestUsageAccess() async {
    // Mocking the system settings flow
    await Future.delayed(const Duration(seconds: 1));
    _usageAccessGranted = true;
    notifyListeners();
  }

  Future<void> requestNotificationAccess() async {
    // Mocking the system settings flow
    await Future.delayed(const Duration(seconds: 1));
    _notificationAccessGranted = true;
    notifyListeners();
  }

  Future<void> requestBluetooth() async {
    // Mocking standard permission dialog
    await Future.delayed(const Duration(seconds: 1));
    _bluetoothGranted = true;
    notifyListeners();
  }
}

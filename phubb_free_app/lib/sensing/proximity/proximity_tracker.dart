// Pure Dart (no Flutter imports) so it can run in tests and offline replay.
import '../../data/phub_event.dart' show ProximityState;
import 'ble_advert.dart';
import 'person_signal_classifier.dart';

class ProximityTrackerConfig {
  /// Co-presence needs a person signal in [requiredCycles] of the last
  /// [windowCycles] scan cycles (filters one-off passers-by).
  final int windowCycles;
  final int requiredCycles;

  /// How long state stays `near` after the last confirming cycle. Matches the
  /// ±10 min PROXIMITY_WINDOW_SEC used to build the training labels.
  final Duration hold;

  /// With no scan for this long, proximity is `unknown` (not `notNear`).
  final Duration staleAfter;

  const ProximityTrackerConfig({
    this.windowCycles = 3,
    this.requiredCycles = 2,
    this.hold = const Duration(minutes: 10),
    this.staleAfter = const Duration(minutes: 3),
  }) : assert(requiredCycles >= 1 && requiredCycles <= windowCycles);

  @override
  String toString() =>
      '$requiredCycles-of-$windowCycles, hold ${hold.inMinutes}m';
}

/// Summary of one scan cycle after classification.
class ScanCycleResult {
  final DateTime at;
  final int advertCount;
  final int personSignalCount;

  /// The k-of-n rule is satisfied as of this cycle.
  final bool confirmedNear;

  const ScanCycleResult({
    required this.at,
    required this.advertCount,
    required this.personSignalCount,
    required this.confirmedNear,
  });
}

/// Turns a series of BLE scan cycles into a [ProximityState].
///
/// Counting is per cycle ("was there any person signal?"), not per device, so
/// MAC address randomization cannot inflate it.
class ProximityTracker {
  ProximityTracker({
    this.config = const ProximityTrackerConfig(),
    this.classifier = const PersonSignalClassifier(),
  });

  final ProximityTrackerConfig config;
  final PersonSignalClassifier classifier;

  final List<bool> _recent = [];
  DateTime? _lastScanAt;
  DateTime? _lastConfirmedAt;

  /// False when Bluetooth is off or the scan permission is missing.
  bool bluetoothAvailable = true;

  ScanCycleResult addScanCycle(DateTime at, List<BleAdvert> adverts) {
    final signals = adverts.where(classifier.isPersonSignal).length;
    _recent.add(signals > 0);
    if (_recent.length > config.windowCycles) _recent.removeAt(0);
    _lastScanAt = at;

    final confirmed = _recent.where((x) => x).length >= config.requiredCycles;
    if (confirmed) _lastConfirmedAt = at;

    return ScanCycleResult(
      at: at,
      advertCount: adverts.length,
      personSignalCount: signals,
      confirmedNear: confirmed,
    );
  }

  ProximityState stateAt(DateTime now) {
    if (!bluetoothAvailable) return ProximityState.unknown;
    final confirmedAt = _lastConfirmedAt;
    if (confirmedAt != null && now.difference(confirmedAt) <= config.hold) {
      return ProximityState.near;
    }
    final scanAt = _lastScanAt;
    if (scanAt == null || now.difference(scanAt) > config.staleAfter) {
      return ProximityState.unknown;
    }
    return ProximityState.notNear;
  }

  void reset() {
    _recent.clear();
    _lastScanAt = null;
    _lastConfirmedAt = null;
  }
}

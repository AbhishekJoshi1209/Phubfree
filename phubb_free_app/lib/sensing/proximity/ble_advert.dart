// Pure Dart (no Flutter imports) so it can run in tests and offline replay.

/// One BLE advertisement seen during a scan, reduced to the fields the
/// co-presence heuristic uses. Nothing here identifies a person: device ids are
/// randomized MAC addresses, and only advert *types* are inspected.
class BleAdvert {
  final String deviceId;
  final DateTime timestamp;
  final int rssi;
  final String name;

  /// Manufacturer-specific data, keyed by Bluetooth SIG company id.
  final Map<int, List<int>> manufacturerData;

  /// 16-bit service UUIDs (lowercase hex, e.g. `fef3`) from both the service
  /// UUID list and service-data keys. Longer UUIDs are kept in full.
  final List<String> serviceUuids;
  final bool connectable;

  /// True if the device is paired with this phone (the user's own watch,
  /// earbuds, car…). Bonded devices never count as "someone nearby".
  final bool bonded;

  const BleAdvert({
    required this.deviceId,
    required this.timestamp,
    required this.rssi,
    this.name = '',
    this.manufacturerData = const {},
    this.serviceUuids = const [],
    this.connectable = false,
    this.bonded = false,
  });

  /// Apple Continuity message types found in the Apple (0x004C) payload.
  /// The payload is a sequence of TLVs: `type, length, data[length]`.
  Set<int> get appleContinuityTypes {
    final bytes = manufacturerData[companyApple];
    if (bytes == null) return const {};
    final types = <int>{};
    var i = 0;
    while (i + 1 < bytes.length) {
      types.add(bytes[i]);
      i += 2 + bytes[i + 1];
    }
    return types;
  }
}

// Bluetooth SIG company identifiers.
const companyApple = 0x004C;
const companySamsung = 0x0075;
const companyMicrosoft = 0x0006;
const companyGoogle = 0x00E0;

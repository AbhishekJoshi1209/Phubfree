// Pure Dart (no Flutter imports) so it can run in tests and offline replay.
import 'ble_advert.dart';

/// What kind of device an advertisement most likely came from.
enum AdvertCategory {
  /// A phone (or tablet/laptop/watch that travels with a person).
  phoneLike,

  /// Earbuds, trackers, beacons, keyboards: not evidence of a person.
  accessory,

  /// Unknown; ignored by the heuristic but kept in logs.
  other,
}

class AdvertClassification {
  final AdvertCategory category;

  /// Short machine-readable reason, logged so field data can tune the rules.
  final String reason;

  const AdvertClassification(this.category, this.reason);
}

/// Decides which advertisements count as a "person signal".
///
/// v0 rules, to be tuned with Phase 1 field data (IMPLEMENTATION_PLAN.md):
/// * Apple Continuity types 0x10 Nearby Info, 0x0C Handoff, 0x0F Nearby Action
///   are sent by iPhones (also iPads/Macs/Watches) → phoneLike.
///   0x07 Proximity Pairing (AirPods), 0x12 Find My (AirTags, offline
///   devices), 0x02 iBeacon → accessory.
/// * Service 0xFEF3 (Google Nearby / Quick Share) → phoneLike (Android).
/// * Samsung manufacturer data → phoneLike (tentative: Galaxy Buds/Watch
///   also use it; the field test decides).
/// * Service 0xFE2C (Google Fast Pair) is advertised by accessories → accessory.
/// * Microsoft (Swift Pair keyboards, Windows PCs) → other.
class PersonSignalClassifier {
  /// Minimum RSSI for a phone-like advert to count. −75 dBm (~1–3 m) is the
  /// co-presence threshold used to build the training labels.
  final int minRssi;

  const PersonSignalClassifier({this.minRssi = -75});

  static const _appleTypeNames = {
    0x02: 'ibeacon',
    0x07: 'proximity_pairing',
    0x0C: 'handoff',
    0x0F: 'nearby_action',
    0x10: 'nearby_info',
    0x12: 'find_my',
  };
  static const _applePhoneTypes = {0x10, 0x0C, 0x0F};
  static const _appleAccessoryTypes = {0x02, 0x07, 0x12};

  AdvertClassification classify(BleAdvert a) {
    final appleTypes = a.appleContinuityTypes;
    if (appleTypes.isNotEmpty) {
      String names(Set<int> t) => t
          .map((x) => _appleTypeNames[x] ?? '0x${x.toRadixString(16)}')
          .join('+');
      final phone = appleTypes.intersection(_applePhoneTypes);
      if (phone.isNotEmpty) {
        return AdvertClassification(
          AdvertCategory.phoneLike,
          'apple_${names(phone)}',
        );
      }
      final acc = appleTypes.intersection(_appleAccessoryTypes);
      if (acc.isNotEmpty) {
        return AdvertClassification(
          AdvertCategory.accessory,
          'apple_${names(acc)}',
        );
      }
      return AdvertClassification(
        AdvertCategory.other,
        'apple_${names(appleTypes)}',
      );
    }
    if (a.serviceUuids.contains('fef3')) {
      return const AdvertClassification(
        AdvertCategory.phoneLike,
        'google_nearby',
      );
    }
    if (a.serviceUuids.contains('fe2c')) {
      return const AdvertClassification(
        AdvertCategory.accessory,
        'google_fast_pair',
      );
    }
    if (a.manufacturerData.containsKey(companySamsung)) {
      return const AdvertClassification(AdvertCategory.phoneLike, 'samsung');
    }
    if (a.manufacturerData.containsKey(companyMicrosoft)) {
      return const AdvertClassification(AdvertCategory.other, 'microsoft');
    }
    return const AdvertClassification(AdvertCategory.other, 'unclassified');
  }

  /// True if this advert is evidence that another person is close by.
  bool isPersonSignal(BleAdvert a) =>
      !a.bonded &&
      a.rssi >= minRssi &&
      classify(a).category == AdvertCategory.phoneLike;
}

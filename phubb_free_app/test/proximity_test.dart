import 'package:flutter_test/flutter_test.dart';
import 'package:phubb_free_app/data/phub_event.dart';
import 'package:phubb_free_app/sensing/proximity/ble_advert.dart';
import 'package:phubb_free_app/sensing/proximity/person_signal_classifier.dart';
import 'package:phubb_free_app/sensing/proximity/proximity_tracker.dart';
import 'package:phubb_free_app/sensing/proximity/spike_log.dart';

final t0 = DateTime(2026, 11, 17, 19);

BleAdvert iphone({int rssi = -60, bool bonded = false, String id = 'A'}) =>
    BleAdvert(
      deviceId: id,
      timestamp: t0,
      rssi: rssi,
      bonded: bonded,
      // Apple Nearby Info TLV: type 0x10, length 5, payload.
      manufacturerData: {
        companyApple: [0x10, 0x05, 0x01, 0x18, 0x44, 0x00, 0x00],
      },
    );

BleAdvert airpods({int rssi = -50}) => BleAdvert(
  deviceId: 'P',
  timestamp: t0,
  rssi: rssi,
  manufacturerData: {
    companyApple: [0x07, 0x02, 0x01, 0x02],
  },
);

BleAdvert androidNearby({int rssi = -60}) => BleAdvert(
  deviceId: 'N',
  timestamp: t0,
  rssi: rssi,
  serviceUuids: const ['fef3'],
);

BleAdvert fastPairBuds() => BleAdvert(
  deviceId: 'F',
  timestamp: t0,
  rssi: -50,
  serviceUuids: const ['fe2c'],
);

void main() {
  group('BleAdvert', () {
    test('parses multiple Apple Continuity TLVs', () {
      final a = BleAdvert(
        deviceId: 'x',
        timestamp: t0,
        rssi: -60,
        manufacturerData: {
          companyApple: [0x0C, 0x01, 0xAA, 0x10, 0x02, 0x01, 0x02],
        },
      );
      expect(a.appleContinuityTypes, {0x0C, 0x10});
    });

    test('truncated payload does not throw', () {
      final a = BleAdvert(
        deviceId: 'x',
        timestamp: t0,
        rssi: -60,
        manufacturerData: {
          companyApple: [0x10],
        },
      );
      expect(a.appleContinuityTypes, isEmpty);
    });
  });

  group('PersonSignalClassifier', () {
    const c = PersonSignalClassifier();

    test('iPhone Nearby Info and Android Nearby are phone-like', () {
      expect(c.classify(iphone()).category, AdvertCategory.phoneLike);
      expect(c.classify(iphone()).reason, 'apple_nearby_info');
      expect(c.classify(androidNearby()).category, AdvertCategory.phoneLike);
    });

    test('AirPods and Fast Pair earbuds are accessories', () {
      expect(c.classify(airpods()).category, AdvertCategory.accessory);
      expect(c.classify(fastPairBuds()).category, AdvertCategory.accessory);
    });

    test('person signal needs phone-like, in range and not paired', () {
      expect(c.isPersonSignal(iphone(rssi: -75)), isTrue);
      expect(c.isPersonSignal(iphone(rssi: -76)), isFalse);
      expect(c.isPersonSignal(iphone(bonded: true)), isFalse);
      expect(c.isPersonSignal(airpods()), isFalse);
    });
  });

  group('ProximityTracker', () {
    test('unknown before any scan and when Bluetooth is off', () {
      final tr = ProximityTracker();
      expect(tr.stateAt(t0), ProximityState.unknown);
      tr.addScanCycle(t0, [iphone()]);
      tr.addScanCycle(t0.add(const Duration(seconds: 20)), [iphone()]);
      tr.bluetoothAvailable = false;
      expect(
        tr.stateAt(t0.add(const Duration(seconds: 21))),
        ProximityState.unknown,
      );
    });

    test('one sighting is not enough; two of three cycles confirms', () {
      final tr = ProximityTracker();
      tr.addScanCycle(t0, [iphone()]);
      expect(tr.stateAt(t0), ProximityState.notNear);
      final r = tr.addScanCycle(t0.add(const Duration(seconds: 20)), []);
      expect(r.confirmedNear, isFalse);
      final r2 = tr.addScanCycle(t0.add(const Duration(seconds: 40)), [
        iphone(),
      ]);
      expect(r2.confirmedNear, isTrue);
      expect(
        tr.stateAt(t0.add(const Duration(seconds: 40))),
        ProximityState.near,
      );
    });

    test('near holds for 10 minutes, then falls back', () {
      final tr = ProximityTracker();
      tr.addScanCycle(t0, [iphone()]);
      tr.addScanCycle(t0.add(const Duration(seconds: 20)), [iphone()]);
      for (var i = 2; i < 40; i++) {
        tr.addScanCycle(t0.add(Duration(seconds: 20 * i)), []);
      }
      // 2-of-3: the empty cycle at 40 s still sees two sightings in its
      // window, so the last confirmation (and the hold's start) is at 40 s.
      final confirmedAt = t0.add(const Duration(seconds: 40));
      expect(
        tr.stateAt(confirmedAt.add(const Duration(minutes: 10))),
        ProximityState.near,
      );
      expect(
        tr.stateAt(confirmedAt.add(const Duration(minutes: 10, seconds: 1))),
        ProximityState.notNear,
      );
    });

    test('stale scans give unknown, not notNear', () {
      final tr = ProximityTracker();
      tr.addScanCycle(t0, []);
      expect(
        tr.stateAt(t0.add(const Duration(minutes: 2))),
        ProximityState.notNear,
      );
      expect(
        tr.stateAt(t0.add(const Duration(minutes: 4))),
        ProximityState.unknown,
      );
    });

    test('randomized MACs do not inflate the count (per-cycle counting)', () {
      final tr = ProximityTracker();
      final r = tr.addScanCycle(t0, [
        for (var i = 0; i < 5; i++) iphone(id: 'rand$i'),
      ]);
      expect(r.personSignalCount, 5);
      expect(r.confirmedNear, isFalse); // still just one cycle
    });
  });

  group('spike log', () {
    LoggedCycle cycle(
      int n,
      int companions,
      List<BleAdvert> adverts, {
      String session = 's1',
      bool bt = true,
    }) => LoggedCycle(
      session: session,
      cycle: n,
      at: t0.add(Duration(seconds: 20 * n)),
      situation: companions > 0 ? 'with_iphone' : 'alone_home',
      companions: companions,
      bluetoothOn: bt,
      adverts: adverts,
    );

    test('CSV round-trip keeps everything the heuristic uses', () {
      final original = [
        cycle(0, 1, [iphone(), airpods(), androidNearby()]),
        cycle(1, 1, []), // empty cycle must survive
        cycle(2, 0, [iphone(bonded: true)], bt: false),
      ];
      final csv = [
        spikeCsvHeader,
        for (final c in original) ...encodeCycle(c),
      ].join('\n');
      final parsed = parseSpikeCsv(csv);

      expect(parsed.length, 3);
      expect(parsed[1].adverts, isEmpty);
      expect(parsed[2].bluetoothOn, isFalse);
      expect(parsed[2].adverts.single.bonded, isTrue);
      final a = parsed[0].adverts.first;
      expect(a.rssi, -60);
      expect(a.appleContinuityTypes, {0x10});
      expect(parsed[0].adverts[2].serviceUuids, ['fef3']);
      expect(parsed[0].at, original[0].at);
    });

    test('names with commas or quotes do not break the CSV', () {
      final weird = BleAdvert(
        deviceId: 'w',
        timestamp: t0,
        rssi: -40,
        name: 'Bob\'s, "Phone"\n',
      );
      final csv = encodeCycle(cycle(0, 0, [weird])).join('\n');
      expect(parseSpikeCsv(csv).single.adverts.single.rssi, -40);
    });

    test('evaluation counts tp/fp/fn/tn against companions label', () {
      final cycles = [
        // Session 1: with a friend, iPhone visible → confirmed from cycle 1.
        cycle(0, 1, [iphone()]),
        cycle(1, 1, [iphone()]),
        cycle(2, 1, [iphone()]),
        // Session 2: alone, a stranger's phone in range once.
        cycle(0, 0, [], session: 's2'),
        cycle(1, 0, [iphone()], session: 's2'),
        cycle(2, 0, [], session: 's2'),
      ];
      final r = evaluateSpike(cycles);
      expect(r.tp, 2); // cycle 0 of s1 is not confirmed yet
      expect(r.fn, 1);
      expect(r.fp, 0);
      expect(r.tn, 3);
      expect(r.precision, 1.0);
      expect(r.recall, closeTo(2 / 3, 1e-9));
      expect(r.meetsExitCriterion, isTrue);
    });

    test('sweep covers every rssi × rule combination', () {
      expect(sweepSpike([cycle(0, 0, [])]).length, 6 * 5);
    });
  });
}

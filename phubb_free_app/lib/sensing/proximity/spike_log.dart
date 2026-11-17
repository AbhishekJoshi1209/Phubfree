// Phase 1 BLE field-test log format + offline evaluation.
// Pure Dart (no Flutter imports): used by the debug screen, tests and
// `dart run tool/ble_replay.dart`.
import '../../data/phub_event.dart' show ProximityState;
import 'ble_advert.dart';
import 'person_signal_classifier.dart';
import 'proximity_tracker.dart';

/// One scan cycle as recorded in the field, with the tester's ground truth.
class LoggedCycle {
  final String session;
  final int cycle;
  final DateTime at;

  /// Free-text situation, e.g. `alone_home`, `with_iphone`, `cafe`.
  final String situation;

  /// Ground truth: how many people the tester is *with* (companions, not
  /// strangers at the next table). 0 means alone.
  final int companions;
  final bool bluetoothOn;
  final List<BleAdvert> adverts;

  const LoggedCycle({
    required this.session,
    required this.cycle,
    required this.at,
    required this.situation,
    required this.companions,
    required this.bluetoothOn,
    required this.adverts,
  });
}

// ── CSV ─────────────────────────────────────────────────────────────────

const spikeCsvHeader =
    'row_type,session,cycle,ts_ms,situation,companions,bt_on,device_id,rssi,'
    'name,connectable,bonded,manufacturer_data,service_uuids,category,reason';

String _clean(String s) => s.replaceAll(RegExp(r'[,"\r\n]'), ' ').trim();

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String s) => [
  for (var i = 0; i + 1 < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

/// Encodes one cycle as CSV lines (no header): a `cycle` row, then one
/// `advert` row per advertisement.
List<String> encodeCycle(
  LoggedCycle c, {
  PersonSignalClassifier classifier = const PersonSignalClassifier(),
}) {
  final base = [
    _clean(c.session),
    c.cycle,
    c.at.millisecondsSinceEpoch,
    _clean(c.situation),
    c.companions,
    c.bluetoothOn ? 1 : 0,
  ].join(',');
  return [
    'cycle,$base,,,,,,,,,',
    for (final a in c.adverts)
      () {
        final cls = classifier.classify(a);
        final msd = a.manufacturerData.entries
            .map(
              (e) =>
                  '${e.key.toRadixString(16).padLeft(4, '0')}:'
                  '${_hex(e.value)}',
            )
            .join('|');
        return [
          'advert',
          base,
          _clean(a.deviceId),
          a.rssi,
          _clean(a.name),
          a.connectable ? 1 : 0,
          a.bonded ? 1 : 0,
          msd,
          a.serviceUuids.map(_clean).join('|'),
          cls.category.name,
          cls.reason,
        ].join(',');
      }(),
  ];
}

/// Parses CSV text (header optional, several sessions allowed) back into
/// cycles in file order.
List<LoggedCycle> parseSpikeCsv(String text) {
  final cycles = <String, LoggedCycle>{};
  final order = <String>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('row_type')) continue;
    final f = line.split(',');
    if (f.length < 16) {
      throw FormatException('expected 16 columns, got ${f.length}', line);
    }
    final key = '${f[1]}#${f[2]}';
    final at = DateTime.fromMillisecondsSinceEpoch(int.parse(f[3]));
    final c = cycles.putIfAbsent(key, () {
      order.add(key);
      return LoggedCycle(
        session: f[1],
        cycle: int.parse(f[2]),
        at: at,
        situation: f[4],
        companions: int.parse(f[5]),
        bluetoothOn: f[6] == '1',
        adverts: [],
      );
    });
    if (f[0] == 'advert') {
      c.adverts.add(
        BleAdvert(
          deviceId: f[7],
          timestamp: at,
          rssi: int.parse(f[8]),
          name: f[9],
          connectable: f[10] == '1',
          bonded: f[11] == '1',
          manufacturerData: {
            for (final part in f[12].split('|').where((p) => p.contains(':')))
              int.parse(part.split(':')[0], radix: 16): _unhex(
                part.split(':')[1],
              ),
          },
          serviceUuids: f[13].isEmpty ? const [] : f[13].split('|'),
        ),
      );
    }
  }
  return [for (final k in order) cycles[k]!];
}

// ── Evaluation ──────────────────────────────────────────────────────────

class SpikeEvalResult {
  final String label;
  int tp = 0, fp = 0, fn = 0, tn = 0, unknown = 0;

  SpikeEvalResult(this.label);

  double get precision => tp + fp == 0 ? double.nan : tp / (tp + fp);
  double get recall => tp + fn == 0 ? double.nan : tp / (tp + fn);

  /// Phase 1 exit criterion from IMPLEMENTATION_PLAN.md.
  bool get meetsExitCriterion => precision >= 0.7 && recall >= 0.5;
}

/// Replays logged cycles through a fresh tracker per session and scores the
/// predicted state against the tester's `companions > 0` label.
///
/// With [useHold] false the 10-minute hold is ignored and each cycle is judged
/// on the k-of-n rule alone (shows the raw detector quality).
SpikeEvalResult evaluateSpike(
  List<LoggedCycle> cycles, {
  PersonSignalClassifier classifier = const PersonSignalClassifier(),
  ProximityTrackerConfig config = const ProximityTrackerConfig(),
  bool useHold = true,
  String? label,
}) {
  final result = SpikeEvalResult(
    label ??
        'rssi≥${classifier.minRssi}, $config${useHold ? '' : ' (no hold)'}',
  );
  ProximityTracker? tracker;
  String? session;
  for (final c in cycles) {
    if (c.session != session) {
      session = c.session;
      tracker = ProximityTracker(config: config, classifier: classifier);
    }
    final t = tracker!..bluetoothAvailable = c.bluetoothOn;
    final cycle = t.addScanCycle(c.at, c.adverts);
    final state = useHold
        ? t.stateAt(c.at)
        : (!c.bluetoothOn
              ? ProximityState.unknown
              : (cycle.confirmedNear
                    ? ProximityState.near
                    : ProximityState.notNear));
    if (state == ProximityState.unknown) {
      result.unknown++;
      continue;
    }
    final predicted = state == ProximityState.near;
    final actual = c.companions > 0;
    if (predicted && actual) result.tp++;
    if (predicted && !actual) result.fp++;
    if (!predicted && actual) result.fn++;
    if (!predicted && !actual) result.tn++;
  }
  return result;
}

/// Grid of RSSI thresholds × k-of-n rules to pick the frozen parameters.
List<SpikeEvalResult> sweepSpike(List<LoggedCycle> cycles) => [
  for (final rssi in const [-60, -65, -70, -75, -80, -85])
    for (final (k, n) in const [(1, 1), (1, 2), (2, 3), (3, 3), (3, 5)])
      evaluateSpike(
        cycles,
        classifier: PersonSignalClassifier(minRssi: rssi),
        config: ProximityTrackerConfig(windowCycles: n, requiredCycles: k),
      ),
];

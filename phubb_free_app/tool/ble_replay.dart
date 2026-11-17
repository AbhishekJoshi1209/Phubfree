// Replays Phase 1 BLE field-test logs through the proximity heuristic.
//
//   cd phubb_free_app
//   dart run tool/ble_replay.dart path/to/ble_spike/*.csv
//
// Prints the default configuration's score, a parameter sweep, and a
// per-situation breakdown. See docs/ble_field_test.md.
import 'dart:io';

import 'package:phubb_free_app/sensing/proximity/person_signal_classifier.dart';
import 'package:phubb_free_app/sensing/proximity/spike_log.dart';

String _pct(double v) => v.isNaN ? '   -' : '${(v * 100).round()}%'.padLeft(4);

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/ble_replay.dart <log.csv> [...]');
    exit(64);
  }
  final cycles = <LoggedCycle>[];
  for (final path in args) {
    cycles.addAll(parseSpikeCsv(File(path).readAsStringSync()));
  }
  final sessions = cycles.map((c) => c.session).toSet();
  stdout.writeln(
    '${cycles.length} scan cycles from ${sessions.length} '
    'session(s), ${cycles.fold<int>(0, (s, c) => s + c.adverts.length)} '
    'adverts\n',
  );

  void row(SpikeEvalResult r) => stdout.writeln(
    '${r.label.padRight(40)} prec ${_pct(r.precision)}  rec '
    '${_pct(r.recall)}  tp ${r.tp} fp ${r.fp} fn ${r.fn} tn ${r.tn} '
    'unk ${r.unknown}${r.meetsExitCriterion ? '  ✔ exit criterion' : ''}',
  );

  stdout.writeln('Default (frozen candidate):');
  row(evaluateSpike(cycles));
  row(evaluateSpike(cycles, useHold: false));

  stdout.writeln('\nSweep (with 10 min hold):');
  final sweep = sweepSpike(
    cycles,
  )..sort((a, b) => (b.precision + b.recall).compareTo(a.precision + a.recall));
  sweep.forEach(row);

  stdout.writeln(
    '\nPer situation, default rule (share of cycles judged near):',
  );
  final bySituation = <String, List<LoggedCycle>>{};
  for (final c in cycles) {
    bySituation.putIfAbsent(c.situation, () => []).add(c);
  }
  bySituation.forEach((situation, list) {
    final r = evaluateSpike(list);
    final judged = r.tp + r.fp + r.fn + r.tn;
    final nearRate = judged == 0 ? double.nan : (r.tp + r.fp) / judged;
    stdout.writeln(
      '${situation.padRight(20)} near ${_pct(nearRate)} of '
      '$judged cycles',
    );
  });

  stdout.writeln('\nAdvert classification reasons (all adverts, all RSSI):');
  const classifier = PersonSignalClassifier();
  final reasons = <String, int>{};
  for (final c in cycles) {
    for (final a in c.adverts) {
      final cls = classifier.classify(a);
      reasons[cls.reason] = (reasons[cls.reason] ?? 0) + 1;
    }
  }
  final sorted = reasons.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    stdout.writeln('${e.key.padRight(30)} ${e.value}');
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/phub_event.dart' show ProximityState;
import '../../sensing/proximity/ble_advert.dart';
import '../../sensing/proximity/person_signal_classifier.dart';
import '../../sensing/proximity/proximity_tracker.dart';
import '../../sensing/proximity/spike_log.dart';

/// Whether developer tools (this screen) are reachable from Settings.
/// On in debug builds; for profile/release test builds pass
/// `--dart-define=PHUBB_DEV_TOOLS=true`.
const bool phubbDevTools = bool.fromEnvironment(
  'PHUBB_DEV_TOOLS',
  defaultValue: false,
);

/// Phase 1 BLE co-presence field test (IMPLEMENTATION_PLAN.md).
///
/// Runs a scan cycle (6 s scan every 20 s), shows every advertisement with its
/// classification and the live proximity verdict, and appends everything to a
/// CSV together with the tester's ground-truth label. Protocol and analysis:
/// docs/ble_field_test.md.
class BleFieldTestScreen extends StatefulWidget {
  const BleFieldTestScreen({super.key});

  @override
  State<BleFieldTestScreen> createState() => _BleFieldTestScreenState();
}

class _BleFieldTestScreenState extends State<BleFieldTestScreen> {
  static const _scanDuration = Duration(seconds: 6);
  static const _cyclePeriod = Duration(seconds: 20);
  static const _situations = [
    'alone_home',
    'with_iphone',
    'with_android',
    'cafe',
    'commute',
    'other',
  ];

  static const _classifier = PersonSignalClassifier();
  final _tracker = ProximityTracker(classifier: _classifier);

  String _situation = _situations.first;
  int _companions = 0;

  bool _running = false;
  String? _session;
  int _cycle = 0;
  File? _logFile;
  String? _error;
  Set<String> _bonded = {};
  List<BleAdvert> _lastAdverts = [];
  ScanCycleResult? _lastResult;
  int _loggedRows = 0;

  @override
  void dispose() {
    _running = false;
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<File> _openLog(String session) async {
    // Android: /sdcard/Android/data/<package>/files/ble_spike/ (adb pull-able).
    final base = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory())
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/ble_spike');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$session.csv');
    await file.writeAsString('$spikeCsvHeader\n');
    return file;
  }

  Future<void> _start() async {
    setState(() => _error = null);
    if (!await FlutterBluePlus.isSupported) {
      setState(() => _error = 'Bluetooth LE is not supported on this device.');
      return;
    }
    final now = DateTime.now();
    final session =
        'spike_${now.toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}';
    final file = await _openLog(session);
    try {
      // Requires BLUETOOTH_CONNECT; the user's own devices are excluded.
      _bonded = {
        for (final d in await FlutterBluePlus.bondedDevices) d.remoteId.str,
      };
    } catch (_) {
      _bonded = {};
    }
    _tracker.reset();
    setState(() {
      _session = session;
      _logFile = file;
      _cycle = 0;
      _loggedRows = 0;
      _running = true;
    });
    unawaited(_loop());
  }

  void _stop() {
    setState(() => _running = false);
    FlutterBluePlus.stopScan();
  }

  Future<void> _loop() async {
    while (_running && mounted) {
      final started = DateTime.now();
      try {
        await _runCycle(started);
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
      final wait = _cyclePeriod - DateTime.now().difference(started);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
  }

  Future<void> _runCycle(DateTime at) async {
    final btOn = FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    var adverts = <BleAdvert>[];
    if (btOn) {
      await FlutterBluePlus.startScan(timeout: _scanDuration);
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      adverts = [
        for (final r in FlutterBluePlus.lastScanResults)
          BleAdvert(
            deviceId: r.device.remoteId.str,
            timestamp: r.timeStamp,
            rssi: r.rssi,
            name: r.advertisementData.advName,
            connectable: r.advertisementData.connectable,
            manufacturerData: r.advertisementData.manufacturerData,
            serviceUuids: {
              for (final g in r.advertisementData.serviceUuids)
                g.str.toLowerCase(),
              for (final g in r.advertisementData.serviceData.keys)
                g.str.toLowerCase(),
            }.toList(),
            bonded: _bonded.contains(r.device.remoteId.str),
          ),
      ]..sort((a, b) => b.rssi.compareTo(a.rssi));
    }
    _tracker.bluetoothAvailable = btOn;
    final result = _tracker.addScanCycle(at, adverts);

    final logged = LoggedCycle(
      session: _session!,
      cycle: _cycle,
      at: at,
      situation: _situation,
      companions: _companions,
      bluetoothOn: btOn,
      adverts: adverts,
    );
    final lines = encodeCycle(logged, classifier: _classifier);
    await _logFile!.writeAsString(
      '${lines.join('\n')}\n',
      mode: FileMode.append,
    );

    if (!mounted) return;
    setState(() {
      _cycle++;
      _loggedRows += lines.length;
      _lastAdverts = adverts;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _lastResult == null
        ? ProximityState.unknown
        : _tracker.stateAt(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('BLE field test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ground truth (change it the moment the situation changes)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in _situations)
                ChoiceChip(
                  label: Text(s),
                  selected: _situation == s,
                  onSelected: (_) => setState(() => _situation = s),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('People I\'m with:'),
              const SizedBox(width: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('0')),
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3+')),
                ],
                selected: {_companions},
                onSelectionChanged: (v) =>
                    setState(() => _companions = v.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? _stop : _start,
            icon: Icon(_running ? Icons.stop : Icons.play_arrow),
            label: Text(_running ? 'Stop' : 'Start session'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verdict: ${state.name.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Cycles: $_cycle · last cycle: '
                    '${_lastResult?.advertCount ?? 0} adverts, '
                    '${_lastResult?.personSignalCount ?? 0} person signals',
                  ),
                  Text(
                    'Rule: rssi ≥ ${_classifier.minRssi} dBm, '
                    '${_tracker.config} · ${_bonded.length} paired devices excluded',
                  ),
                  if (_logFile != null)
                    SelectableText(
                      'Log ($_loggedRows rows): ${_logFile!.path}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final a in _lastAdverts) _AdvertTile(advert: a),
        ],
      ),
    );
  }
}

class _AdvertTile extends StatelessWidget {
  const _AdvertTile({required this.advert});
  final BleAdvert advert;

  static const _classifier = PersonSignalClassifier();

  @override
  Widget build(BuildContext context) {
    final cls = _classifier.classify(advert);
    final signal = _classifier.isPersonSignal(advert);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(
        signal
            ? Icons.person
            : cls.category == AdvertCategory.accessory
            ? Icons.headphones
            : Icons.bluetooth,
        color: signal ? scheme.primary : null,
      ),
      title: Text(
        '${advert.rssi} dBm · ${cls.reason}'
        '${advert.bonded ? ' · PAIRED' : ''}',
      ),
      subtitle: Text(
        [
          advert.deviceId,
          if (advert.name.isNotEmpty) advert.name,
          if (advert.manufacturerData.isNotEmpty)
            'mfr ${advert.manufacturerData.keys.map((k) => '0x${k.toRadixString(16).padLeft(4, '0')}').join(',')}',
          if (advert.serviceUuids.isNotEmpty)
            'svc ${advert.serviceUuids.join(',')}',
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

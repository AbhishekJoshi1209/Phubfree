/// Whether another person was detected near the user when an event happened.
///
/// `unknown` means proximity could not be measured (Bluetooth off, permission
/// denied, no scan yet). It is never treated as `notNear`.
enum ProximityState { near, notNear, unknown }

/// A phone-interaction event shown in the activity feed.
///
/// Two separate ideas live here and must not be mixed up:
/// * [proximity] is a **sensor fact**: was someone physically nearby?
/// * [phubScore] / [flagged] are the **model verdict** on the user's recent
///   interaction pattern. The model never sees proximity. An event is flagged
///   only when someone is near *and* the score clears the threshold, which
///   mirrors the proxy label used in training (interaction during co-presence).
class PhubEvent {
  final String id;
  final PhubEventType type;
  final DateTime timestamp;
  final String appName; // e.g. 'WhatsApp'
  final String appPackage; // e.g. 'com.whatsapp'
  final ProximityState proximity;
  final int? rssi;
  final int? responseLatencySec;

  /// Model probability (0–1) for the rolling window at this event, if scored.
  final double? phubScore;

  /// True when this event counts as a possible phubbing moment.
  final bool flagged;

  const PhubEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.appName = '',
    this.appPackage = '',
    this.proximity = ProximityState.unknown,
    this.rssi,
    this.responseLatencySec,
    this.phubScore,
    this.flagged = false,
  });

  bool get someoneNearby => proximity == ProximityState.near;

  PhubEvent copyWith({double? phubScore, bool? flagged}) => PhubEvent(
    id: id,
    type: type,
    timestamp: timestamp,
    appName: appName,
    appPackage: appPackage,
    proximity: proximity,
    rssi: rssi,
    responseLatencySec: responseLatencySec,
    phubScore: phubScore ?? this.phubScore,
    flagged: flagged ?? this.flagged,
  );

  /// Human-friendly one-line description.
  String get friendlyText {
    switch (type) {
      case PhubEventType.unlock:
        return someoneNearby
            ? 'Unlocked phone while someone was nearby'
            : 'Unlocked phone';
      case PhubEventType.appSwitch:
        return someoneNearby
            ? 'Opened $appName while someone was nearby'
            : 'Opened $appName';
      case PhubEventType.notification:
        return responseLatencySec == null
            ? 'Received a notification'
            : 'Responded to a notification in ${responseLatencySec}s';
    }
  }
}

enum PhubEventType { unlock, appSwitch, notification }

/// Daily summary for charts.
class DaySummary {
  final DateTime date;
  final int phubMoments;
  final int nudgesSent;
  final Duration phoneFreeTime;
  final Duration longestStretch;
  final int unlocksNearPeople;

  const DaySummary({
    required this.date,
    required this.phubMoments,
    required this.nudgesSent,
    required this.phoneFreeTime,
    required this.longestStretch,
    required this.unlocksNearPeople,
  });
}

/// App usage during social moments.
class AppSocialUsage {
  final String appName;
  final int count;

  const AppSocialUsage({required this.appName, required this.count});
}

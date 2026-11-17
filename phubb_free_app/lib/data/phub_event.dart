/// A humanized phubbing event, displayed in the activity feed.
class PhubEvent {
  final String id;
  final PhubEventType type;
  final DateTime timestamp;
  final String appName;        // e.g. 'WhatsApp'
  final String appPackage;     // e.g. 'com.whatsapp'
  final bool nearbyPersonDetected;
  final int? rssi;
  final int? responseLatencySec;

  const PhubEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.appName = '',
    this.appPackage = '',
    this.nearbyPersonDetected = false,
    this.rssi,
    this.responseLatencySec,
  });

  /// Human-friendly one-line description.
  String get friendlyText {
    switch (type) {
      case PhubEventType.unlock:
        if (nearbyPersonDetected) {
          return 'Unlocked phone while someone was nearby';
        }
        return 'Unlocked phone';
      case PhubEventType.appSwitch:
        if (nearbyPersonDetected) {
          return 'Opened $appName while someone was nearby';
        }
        return 'Opened $appName';
      case PhubEventType.notification:
        return 'Responded to a notification in ${responseLatencySec}s';
    }
  }

  /// Whether this event is flagged as possible phubbing.
  bool get isPossiblePhubbing => nearbyPersonDetected;
}

enum PhubEventType {
  unlock,
  appSwitch,
  notification,
}

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

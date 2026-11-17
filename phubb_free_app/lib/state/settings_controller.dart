import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages all user-facing settings with persistence.
class SettingsController extends ChangeNotifier {
  // ── Nudge sensitivity (0.0 – 1.0, feeds model threshold) ─────
  double _nudgeSensitivity = 0.5;
  double get nudgeSensitivity => _nudgeSensitivity;

  // ── Nudge style ──────────────────────────────────────────────
  NudgeStyle _nudgeStyle = NudgeStyle.vibration;
  NudgeStyle get nudgeStyle => _nudgeStyle;

  // ── Quiet hours ──────────────────────────────────────────────
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd   = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay get quietStart => _quietStart;
  TimeOfDay get quietEnd   => _quietEnd;

  // ── App whitelist ────────────────────────────────────────────
  List<String> _whitelistedApps = ['Maps', 'Phone', 'Camera'];
  List<String> get whitelistedApps => List.unmodifiable(_whitelistedApps);

  // ── Onboarding complete ──────────────────────────────────────
  bool _onboardingComplete = false;
  bool get onboardingComplete => _onboardingComplete;

  /// Load persisted settings.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _nudgeSensitivity = prefs.getDouble('nudge_sensitivity') ?? 0.5;
    final styleIndex = prefs.getInt('nudge_style') ?? 0;
    _nudgeStyle = NudgeStyle.values[styleIndex.clamp(0, NudgeStyle.values.length - 1)];
    _quietStart = _timeFromMinutes(prefs.getInt('quiet_start') ?? 22 * 60);
    _quietEnd   = _timeFromMinutes(prefs.getInt('quiet_end')   ?? 7 * 60);
    _whitelistedApps = prefs.getStringList('whitelisted_apps') ?? ['Maps', 'Phone', 'Camera'];
    _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    notifyListeners();
  }

  Future<void> setNudgeSensitivity(double value) async {
    _nudgeSensitivity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('nudge_sensitivity', value);
  }

  Future<void> setNudgeStyle(NudgeStyle style) async {
    _nudgeStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nudge_style', style.index);
  }

  Future<void> setQuietHours(TimeOfDay start, TimeOfDay end) async {
    _quietStart = start;
    _quietEnd   = end;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quiet_start', start.hour * 60 + start.minute);
    await prefs.setInt('quiet_end', end.hour * 60 + end.minute);
  }

  Future<void> addWhitelistedApp(String app) async {
    if (!_whitelistedApps.contains(app)) {
      _whitelistedApps.add(app);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('whitelisted_apps', _whitelistedApps);
    }
  }

  Future<void> removeWhitelistedApp(String app) async {
    _whitelistedApps.remove(app);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('whitelisted_apps', _whitelistedApps);
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  Future<void> resetOnboarding() async {
    _onboardingComplete = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', false);
  }

  Future<void> deleteAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _nudgeSensitivity = 0.5;
    _nudgeStyle = NudgeStyle.vibration;
    _quietStart = const TimeOfDay(hour: 22, minute: 0);
    _quietEnd   = const TimeOfDay(hour: 7, minute: 0);
    _whitelistedApps = ['Maps', 'Phone', 'Camera'];
    _onboardingComplete = false;
    notifyListeners();
  }

  TimeOfDay _timeFromMinutes(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

enum NudgeStyle {
  vibration,
  silentNotification,
  off,
}

extension NudgeStyleLabel on NudgeStyle {
  String get label {
    switch (this) {
      case NudgeStyle.vibration:
        return 'Vibration';
      case NudgeStyle.silentNotification:
        return 'Silent notification';
      case NudgeStyle.off:
        return 'Off';
    }
  }
}

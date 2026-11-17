import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/phub_event.dart';
import '../state/settings_controller.dart';

/// Record of a delivered nudge, for analytics and the activity feed.
class NudgeRecord {
  final DateTime timestamp;
  final NudgeStyle style;
  final double probability;
  final String? triggerApp;

  const NudgeRecord({
    required this.timestamp,
    required this.style,
    required this.probability,
    this.triggerApp,
  });
}

/// Central nudge delivery service.
///
/// Sits between the inference pipeline and the user-facing interventions.
/// It respects all user preferences (style, quiet hours, whitelist, cooldown)
/// before actually firing a nudge.
///
/// ### Lifecycle
/// Create once, attach to the repository's event stream, and call
/// [evaluate] on every phubbing-positive event.
class NudgeService extends ChangeNotifier {
  /// Minimum time between consecutive nudges to avoid annoyance.
  static const _cooldownDuration = Duration(minutes: 2);

  /// In-app overlay dismiss timer.
  static const _overlayDuration = Duration(seconds: 4);

  // ── State ──────────────────────────────────────────────────────

  DateTime? _lastNudgeTime;

  /// Whether a nudge overlay is currently visible.
  bool _overlayVisible = false;
  bool get overlayVisible => _overlayVisible;

  /// Message shown in the overlay nudge.
  String _overlayMessage = '';
  String get overlayMessage => _overlayMessage;

  Timer? _overlayTimer;

  /// History of nudges delivered this session.
  final List<NudgeRecord> _history = [];
  List<NudgeRecord> get history => List.unmodifiable(_history);

  /// Total nudges delivered this session.
  int get nudgeCount => _history.length;

  // ── Sensitivity → Threshold mapping ───────────────────────────

  /// Maps the user-facing sensitivity slider (0.0 = fewer nudges, 1.0 = more)
  /// to a model decision threshold.
  ///
  /// Higher sensitivity → lower threshold → more nudges.
  ///   - sensitivity 0.0 → threshold 0.70 (very conservative)
  ///   - sensitivity 0.5 → threshold 0.50 (default)
  ///   - sensitivity 1.0 → threshold 0.30 (aggressive)
  static double sensitivityToThreshold(double sensitivity) {
    // Linear interpolation: threshold = 0.70 - 0.40 * sensitivity
    return (0.70 - 0.40 * sensitivity).clamp(0.1, 0.9);
  }

  // ── Core evaluation ───────────────────────────────────────────

  /// Evaluates whether a nudge should be delivered for the given event and
  /// probability. Respects quiet hours, whitelist, cooldown, and nudge style.
  ///
  /// Returns `true` if a nudge was actually delivered.
  bool evaluate({
    required PhubEvent event,
    required double probability,
    required SettingsController settings,
  }) {
    // 1. Nudges disabled?
    if (settings.nudgeStyle == NudgeStyle.off) return false;

    // 2. Below threshold?
    final threshold = sensitivityToThreshold(settings.nudgeSensitivity);
    if (probability < threshold) return false;

    // 3. Not flagged (no one nearby, or score below the flag threshold)?
    if (!event.flagged) return false;

    // 4. Whitelisted app?
    if (event.appName.isNotEmpty &&
        settings.whitelistedApps.contains(event.appName)) {
      return false;
    }

    // 5. Quiet hours?
    if (_isDuringQuietHours(settings)) return false;

    // 6. Cooldown?
    if (_lastNudgeTime != null &&
        DateTime.now().difference(_lastNudgeTime!) < _cooldownDuration) {
      return false;
    }

    // All checks passed — deliver the nudge.
    _deliver(
      style: settings.nudgeStyle,
      probability: probability,
      triggerApp: event.appName.isNotEmpty ? event.appName : null,
    );

    return true;
  }

  // ── Delivery ──────────────────────────────────────────────────

  void _deliver({
    required NudgeStyle style,
    required double probability,
    String? triggerApp,
  }) {
    _lastNudgeTime = DateTime.now();

    final record = NudgeRecord(
      timestamp: DateTime.now(),
      style: style,
      probability: probability,
      triggerApp: triggerApp,
    );
    _history.insert(0, record);
    if (_history.length > 100) _history.removeLast();

    switch (style) {
      case NudgeStyle.vibration:
        _deliverHaptic();
        _showOverlay(_buildMessage(triggerApp));
        break;
      case NudgeStyle.silentNotification:
        _showOverlay(_buildMessage(triggerApp));
        break;
      case NudgeStyle.off:
        break; // Should not reach here (guarded above).
    }

    notifyListeners();
  }

  /// Triggers a gentle haptic pattern.
  void _deliverHaptic() {
    // Light impact followed by a short pause and another light impact.
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Shows an in-app overlay banner with auto-dismiss.
  void _showOverlay(String message) {
    _overlayMessage = message;
    _overlayVisible = true;
    notifyListeners();

    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayDuration, dismissOverlay);
  }

  /// Dismisses the overlay immediately (also called by the user tapping it).
  void dismissOverlay() {
    if (!_overlayVisible) return;
    _overlayVisible = false;
    _overlayTimer?.cancel();
    notifyListeners();
  }

  // ── Message templates ─────────────────────────────────────────

  static const _genericMessages = [
    'You seem to be on your phone around someone. Take a moment to connect! 🤝',
    'Looks like you might be phubbing. How about putting the phone down? 📵',
    'Someone nearby might appreciate your attention right now. 😊',
    'Quick check-in: are you present with the people around you? 💭',
    'Your phone can wait — real connections can\'t. ✨',
  ];

  static const _appMessages = [
    'You opened {app} while someone is nearby. Need to? 🤔',
    '{app} can wait — the person next to you can\'t. 🤗',
    'Noticed you\'re on {app} during social time. Just a gentle reminder! 💡',
  ];

  String _buildMessage(String? triggerApp) {
    final now = DateTime.now();
    final seed = now.millisecondsSinceEpoch;

    if (triggerApp != null && triggerApp.isNotEmpty) {
      final template = _appMessages[seed % _appMessages.length];
      return template.replaceAll('{app}', triggerApp);
    }

    return _genericMessages[seed % _genericMessages.length];
  }

  // ── Quiet hours check ─────────────────────────────────────────

  bool _isDuringQuietHours(SettingsController settings) {
    final now = TimeOfDay.now();
    final start = settings.quietStart;
    final end = settings.quietEnd;

    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    if (startMin <= endMin) {
      // Same-day range (e.g. 09:00 – 17:00)
      return nowMin >= startMin && nowMin < endMin;
    } else {
      // Overnight range (e.g. 22:00 – 07:00)
      return nowMin >= startMin || nowMin < endMin;
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
  }
}

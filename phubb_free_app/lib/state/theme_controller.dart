import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages System / Light / Dark theme selection.
///
/// Persists the user's choice via [SharedPreferences] so the correct theme
/// is applied before the first frame renders (no flash).
class ThemeController extends ChangeNotifier {
  static const _prefKey = 'phubbfree_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Whether we have finished loading the persisted preference.
  bool _loaded = false;
  bool get loaded => _loaded;

  /// Call once before [runApp] to avoid a wrong-theme flash.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored != null) {
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
    _loaded = true;
    notifyListeners();
  }

  /// Set an explicit mode and persist it.
  Future<void> setMode(ThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newMode.name);
  }

  /// Quick toggle (app-bar button): flips between light and dark.
  /// If currently System, switches to the opposite of the effective theme.
  Future<void> toggle() async {
    if (_mode == ThemeMode.light) {
      await setMode(ThemeMode.dark);
    } else if (_mode == ThemeMode.dark) {
      await setMode(ThemeMode.light);
    } else {
      // System → opposite of current platform brightness
      final platformBrightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      final opposite = platformBrightness == Brightness.light
          ? ThemeMode.dark
          : ThemeMode.light;
      await setMode(opposite);
    }
  }

  /// The effective brightness given current mode and platform.
  Brightness get effectiveBrightness {
    if (_mode == ThemeMode.light) return Brightness.light;
    if (_mode == ThemeMode.dark) return Brightness.dark;
    return SchedulerBinding.instance.platformDispatcher.platformBrightness;
  }
}

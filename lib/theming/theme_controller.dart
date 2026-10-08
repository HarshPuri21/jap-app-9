import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_definition.dart';
import 'theme_registry.dart';

/// Owns which theme is active, and persists that choice.
///
/// Uses the same SharedPreferences store as the rest of the app's settings,
/// just under its own keys, so there's one persistence mechanism overall
/// without the theme concern leaking into SettingsService.
class ThemeController extends ChangeNotifier {
  static const _kThemeId = 'active_theme_id';
  static const _kEffectsEnabled = 'theme_effects_enabled';

  String _themeId = ThemeRegistry.defaultThemeId;
  bool _effectsEnabled = true;

  String get themeId => _themeId;
  AppThemeDefinition get theme => ThemeRegistry.byId(_themeId);

  /// When false, themes use their cheap rendering path (no backdrop blur,
  /// no heavy shaders). Layout, colours and contrast are unchanged -- this
  /// only trades the expensive effect for a static approximation, which is
  /// what makes the app comfortable on low-end phones.
  bool get effectsEnabled => _effectsEnabled;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeId = prefs.getString(_kThemeId) ?? ThemeRegistry.defaultThemeId;
      _effectsEnabled = prefs.getBool(_kEffectsEnabled) ?? true;
    } catch (e) {
      // A corrupted preference must never stop the app from starting; worst
      // case the user sees the default theme.
      debugPrint('ThemeController.load failed, using defaults: $e');
    }
    notifyListeners();
  }

  Future<void> setThemeId(String id) async {
    if (_themeId == id) return;
    _themeId = id;
    notifyListeners();
    await _persist(_kThemeId, id);
  }

  Future<void> setEffectsEnabled(bool value) async {
    if (_effectsEnabled == value) return;
    _effectsEnabled = value;
    notifyListeners();
    await _persist(_kEffectsEnabled, value);
  }

  Future<void> _persist(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) await prefs.setString(key, value);
      if (value is bool) await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('ThemeController save failed (kept in memory only): $e');
    }
  }
}

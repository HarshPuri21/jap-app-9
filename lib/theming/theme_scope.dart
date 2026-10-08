import 'package:flutter/material.dart';

import 'theme_definition.dart';
import 'theme_tokens.dart';

/// Makes the active theme available to every widget below it.
///
/// Installed once, in `MaterialApp.builder`, so it wraps the Navigator and
/// therefore covers every pushed route -- not just the home screen.
class ThemeScope extends InheritedWidget {
  final AppThemeDefinition theme;

  /// Global "reduce visual effects" switch. Themes with an expensive signature
  /// effect (Glass's backdrop blur) must fall back to a cheap path when
  /// this is false, without changing layout or contrast.
  final bool effectsEnabled;

  const ThemeScope({
    super.key,
    required this.theme,
    required this.effectsEnabled,
    required super.child,
  });

  static ThemeScope _scopeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'No ThemeScope found. Is MaterialApp.builder set up?');
    return scope!;
  }

  static AppThemeDefinition of(BuildContext context) => _scopeOf(context).theme;

  static bool effectsEnabledOf(BuildContext context) =>
      _scopeOf(context).effectsEnabled;

  @override
  bool updateShouldNotify(ThemeScope oldWidget) =>
      oldWidget.theme.id != theme.id ||
      oldWidget.effectsEnabled != effectsEnabled;
}

/// Shorthands so screens read cleanly:
///
///   final t = context.tokens;
///   Text('Daily Review', style: t.text.cardTitle)
extension ThemeContextX on BuildContext {
  AppThemeDefinition get appTheme => ThemeScope.of(this);
  ThemeTokens get tokens => ThemeScope.of(this).tokens;
  ThemeColors get palette => ThemeScope.of(this).tokens.colors;
}

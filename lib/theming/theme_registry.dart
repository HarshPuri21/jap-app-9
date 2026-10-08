import 'theme_definition.dart';
import '../themes/glass/glass_theme.dart';
import '../themes/tokyo_neon/tokyo_neon_theme.dart';
import '../themes/zen_minimal/zen_minimal_theme.dart';

/// The list of themes the app ships with.
///
/// Adding a theme is: create `themes/<name>/`, implement [AppThemeDefinition],
/// add one line here. No screen, service, model or widget changes.
class ThemeRegistry {
  ThemeRegistry._();

  /// Order here is the order shown in Settings.
  static const List<AppThemeDefinition> themes = <AppThemeDefinition>[
    GlassTheme(),
    ZenMinimalTheme(),
    TokyoNeonTheme(),
  ];

  static const String defaultThemeId = GlassTheme.themeId;

  /// Resolves a persisted id. Falls back to the default when an id is
  /// unknown -- which happens if a theme is ever removed from a build, and
  /// must not leave the user staring at a crash.
  static AppThemeDefinition byId(String? id) {
    for (final theme in themes) {
      if (theme.id == id) return theme;
    }
    return themes.firstWhere(
      (t) => t.id == defaultThemeId,
      orElse: () => themes.first,
    );
  }
}

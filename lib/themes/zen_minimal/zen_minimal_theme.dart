import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_tokens.dart';
import 'zen_minimal_background.dart';
import 'zen_minimal_surface.dart';
import 'zen_minimal_tokens.dart';

/// Ink on paper: a light, flat, near-silent theme.
///
/// It exists for two reasons. It's the calm, long-session reading mode --
/// and it is proof that the theme contract really is enough: a *light* theme
/// with different geometry, different typography weights, no blur and no
/// elevation drops in without a single screen being edited.
class ZenMinimalTheme extends AppThemeDefinition {
  static const String themeId = 'zen_minimal';

  const ZenMinimalTheme();

  @override
  String get id => themeId;

  @override
  String get name => 'Zen Minimal';

  @override
  String get description => 'Sumi ink on warm paper — light, flat and quiet';

  @override
  ThemePreview get preview => const ThemePreview(
        swatch: [
          ZenPalette.paperBase,
          ZenPalette.accent,
          ZenPalette.ink,
        ],
        icon: Icons.brightness_low_rounded,
      );

  @override
  ThemeTokens get tokens => kZenMinimalTokens;

  @override
  ThemeData buildMaterialTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: ZenPalette.accent,
        secondary: ZenPalette.accent,
        surface: ZenPalette.paper,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: ZenPalette.ink,
        displayColor: ZenPalette.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ZenPalette.ink,
        centerTitle: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ZenPalette.accent,
        inactiveTrackColor: ZenPalette.ink.withOpacity(0.14),
        thumbColor: ZenPalette.accent,
        overlayColor: ZenPalette.accent.withOpacity(0.12),
        trackHeight: 3,
        valueIndicatorColor: ZenPalette.accent,
        valueIndicatorTextStyle: const TextStyle(
          color: ZenPalette.onAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZenPalette.ink,
        contentTextStyle: const TextStyle(color: ZenPalette.paperBase),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: ZenPalette.accent),
      dividerColor: ZenPalette.ink.withOpacity(0.16),
    );
  }

  @override
  Widget buildBackground(
    BuildContext context,
    BackgroundRequest request,
    Widget child,
  ) {
    return ZenMinimalBackground(request: request, child: child);
  }

  @override
  Widget buildSurface(BuildContext context, SurfaceRequest request) {
    return ZenMinimalSurface(request: request);
  }

  @override
  Widget buildIconPlate(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
  }) {
    // A hanko-like square of flat colour, no gradient.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kZenMinimalTokens.radii.xs),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

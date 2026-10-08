import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_scope.dart';
import '../../theming/theme_tokens.dart';
import 'tokyo_neon_background.dart';
import 'tokyo_neon_motion.dart';
import 'tokyo_neon_surface.dart';
import 'tokyo_neon_tokens.dart';

/// Tokyo at night: a dark HUD lit by cyan and purple neon.
///
/// Where Glass is fluid and soft, this is precise and fast. Panels are opaque
/// and machined; light lives on their edges; motion is a scan or a pulse
/// rather than a bloom. Nothing about it is a recolour of the other theme —
/// the surfaces, the radii, the typography tracking and every animation are
/// its own.
///
/// It is also the *cheaper* of the two dark themes: no backdrop blur
/// anywhere, one static backdrop, and every animation is a short one-shot
/// over a child that never rebuilds.
class TokyoNeonTheme extends AppThemeDefinition {
  static const String themeId = 'tokyo_neon';

  const TokyoNeonTheme();

  @override
  String get id => themeId;

  @override
  String get name => 'Tokyo Neon';

  @override
  String get description => 'Neon cyan and purple on a deep night HUD';

  @override
  ThemePreview get preview => const ThemePreview(
        swatch: [
          NeonPalette.voidBlack,
          NeonPalette.cyan,
          NeonPalette.purple,
        ],
        icon: Icons.bolt_rounded,
      );

  @override
  ThemeTokens get tokens => kTokyoNeonTokens;

  @override
  ThemeData buildMaterialTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: NeonPalette.cyan,
        secondary: NeonPalette.purple,
        surface: NeonPalette.navy,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: NeonPalette.textPrimary,
        displayColor: NeonPalette.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: NeonPalette.textPrimary,
        centerTitle: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: NeonPalette.cyan,
        inactiveTrackColor: NeonPalette.cyan.withOpacity(0.18),
        thumbColor: NeonPalette.cyan,
        overlayColor: NeonPalette.cyan.withOpacity(0.18),
        trackHeight: 3,
        valueIndicatorColor: NeonPalette.cyan,
        valueIndicatorTextStyle: const TextStyle(
          color: NeonPalette.onAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NeonPalette.navyRaised,
        contentTextStyle: const TextStyle(color: NeonPalette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kTokyoNeonTokens.radii.sm),
          side: BorderSide(color: NeonPalette.cyan.withOpacity(0.45)),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: NeonPalette.cyan),
      dividerColor: NeonPalette.cyan.withOpacity(0.16),
    );
  }

  @override
  Widget buildBackground(
    BuildContext context,
    BackgroundRequest request,
    Widget child,
  ) {
    return TokyoNeonBackground(
      request: request,
      effectsEnabled: ThemeScope.effectsEnabledOf(context),
      child: child,
    );
  }

  @override
  Widget buildSurface(BuildContext context, SurfaceRequest request) {
    return TokyoNeonSurface(
      request: request,
      effectsEnabled: ThemeScope.effectsEnabledOf(context),
    );
  }

  @override
  Widget buildReveal(BuildContext context, RevealRequest request) =>
      NeonReveal(request: request);

  @override
  Widget buildProgressFill(
    BuildContext context,
    ProgressFillRequest request,
  ) =>
      NeonProgressFill(request: request);

  @override
  Duration get pageTransitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The sweep is decoration on top of the transition, so if effects are off
    // the screen still arrives the same way, just without the line.
    if (!ThemeScope.effectsEnabledOf(context)) {
      return super.buildPageTransition(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return NeonPageTransition(animation: animation, child: child);
  }

  @override
  Widget buildIconPlate(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
  }) {
    // A lit keycap: dark centre, neon rule, faint glow.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kTokyoNeonTokens.radii.xs),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeonPalette.navyRaised,
            Color.alphaBlend(color.withOpacity(0.12), NeonPalette.voidBlack),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.18), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

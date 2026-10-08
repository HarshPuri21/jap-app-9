import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_scope.dart';
import '../../theming/theme_tokens.dart';
import 'glass_background.dart';
import 'glass_motion.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// Premium translucent glass: frosted panes floating over a deep backdrop,
/// with specular edges and soft ambient depth.
///
/// This is the app's default theme and the reference implementation of
/// [AppThemeDefinition] -- a new theme can be written by copying this file's
/// shape and replacing what the three pieces (tokens, surface, background)
/// actually paint.
class GlassTheme extends AppThemeDefinition {
  /// Persisted since the theme shipped as "Liquid Glass". The user-facing
  /// name changed; this id deliberately did not. Changing it would mean every
  /// existing user's saved choice no longer resolves, and
  /// `ThemeRegistry.byId` would quietly fall them back to the default — a
  /// rename should never cost someone their selected theme. Renaming the id
  /// would only be safe alongside a migration step in `ThemeController.load`
  /// that rewrites the old value, which isn't worth the moving part here.
  static const String themeId = 'liquid_glass';

  const GlassTheme();

  @override
  String get id => themeId;

  @override
  String get name => 'Glass';

  @override
  String get description => 'Frosted translucent panes over a deep backdrop';

  @override
  ThemePreview get preview => const ThemePreview(
        swatch: [
          Color(0xFF162138),
          GlassPalette.accent,
          Color(0xFF6366F1),
        ],
        icon: Icons.blur_on_rounded,
      );

  @override
  ThemeTokens get tokens => kGlassTokens;

  @override
  ThemeData buildMaterialTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: GlassPalette.accent,
        secondary: GlassPalette.accent,
        surface: GlassPalette.ink,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: GlassPalette.textPrimary,
        displayColor: GlassPalette.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: GlassPalette.textPrimary,
        centerTitle: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: GlassPalette.accent,
        inactiveTrackColor: GlassPalette.sheen.withOpacity(0.16),
        thumbColor: GlassPalette.accent,
        overlayColor: GlassPalette.accent.withOpacity(0.16),
        trackHeight: 4,
        valueIndicatorColor: GlassPalette.accent,
        valueIndicatorTextStyle: const TextStyle(
          color: GlassPalette.onAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF16213A).withOpacity(0.96),
        contentTextStyle:
            const TextStyle(color: GlassPalette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GlassPalette.accent,
      ),
      dividerColor: GlassPalette.sheen.withOpacity(0.12),
    );
  }

  @override
  Widget buildBackground(
    BuildContext context,
    BackgroundRequest request,
    Widget child,
  ) {
    return GlassBackground(request: request, child: child);
  }

  @override
  Widget buildSurface(BuildContext context, SurfaceRequest request) {
    return GlassSurface(
      request: request,
      effectsEnabled: ThemeScope.effectsEnabledOf(context),
    );
  }

  @override
  Widget buildReveal(BuildContext context, RevealRequest request) =>
      GlassReveal(request: request);

  @override
  Widget buildProgressFill(
    BuildContext context,
    ProgressFillRequest request,
  ) =>
      GlassProgressFill(request: request);

  @override
  Duration get pageTransitionDuration => const Duration(milliseconds: 260);

  /// Glass navigates the way its panes behave: the new screen surfaces
  /// through a soft fade while easing up very slightly in scale, as if a
  /// pane were settling into place. No slide across the screen — that reads
  /// as mechanical rather than fluid, and it costs more to composite.
  @override
  Widget buildPageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget buildIconPlate(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
  }) {
    // A small pane of tinted glass rather than a flat chip -- never blurred,
    // because it always sits on top of an already-blurred parent surface.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kGlassTokens.radii.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.30), color.withOpacity(0.12)],
        ),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

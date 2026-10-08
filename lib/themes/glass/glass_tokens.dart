import 'package:flutter/material.dart';

import '../../theming/theme_tokens.dart';

/// Glass palette and tokens.
///
/// Deep ink, cool sky accent, near-white text. The whole theme is built on
/// the idea that every surface is a thin frosted pane floating above the
/// user's backdrop, so the colours here are mostly *translucent films* rather
/// than solid fills -- the opacities live in `glass_surface.dart`.
class GlassPalette {
  GlassPalette._();

  static const accent = Color(0xFF38BDF8); // sky-400
  static const accentDeep = Color(0xFF0284C7);
  static const onAccent = Color(0xFF042F3D);

  static const textPrimary = Color(0xFFF2F6FB);
  static const textSecondary = Color(0xFFB6C2D4);
  static const textTertiary = Color(0xFF8A97AB);

  static const good = Color(0xFF4ADE80);
  static const bad = Color(0xFFF87171);
  static const warn = Color(0xFFFACC15);

  /// The dark ink layered *under* the frost. Keeping a dark base beneath
  /// every pane is what lets near-white text stay readable even when the
  /// user has set a bright photo as their wallpaper.
  static const ink = Color(0xFF0B1220);

  /// Cool highlight used for the top sheen and hairline borders.
  static const sheen = Color(0xFFFFFFFF);

  static final border = sheen.withOpacity(0.18);
}

/// Glass-specific geometry that the generic token classes don't cover.
class GlassMetrics {
  GlassMetrics._();

  /// Blur sigma per surface level.
  static const double blurSubtle = 10;
  static const double blurStandard = 18;
  static const double blurElevated = 26;

  /// Opacity of the ink base per level.
  static const double inkSubtle = 0.22;
  static const double inkStandard = 0.34;
  static const double inkElevated = 0.44;

  /// Opacity of the white frost film layered over the ink.
  static const double frostSubtle = 0.05;
  static const double frostStandard = 0.07;
  static const double frostElevated = 0.10;

  /// Strength of the specular top-edge sheen.
  static const double sheenSubtle = 0.07;
  static const double sheenStandard = 0.11;
  static const double sheenElevated = 0.16;

  static const double borderSubtle = 0.13;
  static const double borderStandard = 0.18;
  static const double borderElevated = 0.26;

  static const double shadowSubtle = 0.16;
  static const double shadowStandard = 0.26;
  static const double shadowElevated = 0.38;

  /// Extra ink added when blur is unavailable (effects switched off). Without
  /// frosting there is nothing diffusing the wallpaper behind the pane, so
  /// the body darkens a little to hold text contrast exactly where it was.
  static const double noBlurInkCompensation = 0.12;

  /// How much brighter a surface gets while pressed.
  static const double pressBrightness = 0.06;
}

const ThemeTokens kGlassTokens = ThemeTokens(
  colors: ThemeColors(
    accent: GlassPalette.accent,
    onAccent: GlassPalette.onAccent,
    textPrimary: GlassPalette.textPrimary,
    textSecondary: GlassPalette.textSecondary,
    textTertiary: GlassPalette.textTertiary,
    good: GlassPalette.good,
    bad: GlassPalette.bad,
    warn: GlassPalette.warn,
    border: Color(0x2EFFFFFF), // sheen @ 0.18
  ),
  radii: ThemeRadii(xs: 10, sm: 14, md: 20, lg: 26, xl: 32),
  spacing: ThemeSpacing(),
  motion: ThemeMotion(
    curve: Curves.easeOutCubic,
    pressScale: 0.975,
  ),
  text: ThemeTypography(
    jpFontFamily: 'NotoJP',
    jpColor: GlassPalette.textPrimary,
    display: TextStyle(
      color: GlassPalette.textPrimary,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.15,
    ),
    title: TextStyle(
      color: GlassPalette.textPrimary,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    cardTitle: TextStyle(
      color: GlassPalette.textPrimary,
      fontSize: 16.5,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    ),
    body: TextStyle(
      color: GlassPalette.textPrimary,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    secondary: TextStyle(
      color: GlassPalette.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    caption: TextStyle(
      color: GlassPalette.textTertiary,
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
    ),
    overline: TextStyle(
      color: GlassPalette.textSecondary,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    ),
    button: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  ),
);

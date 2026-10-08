import 'package:flutter/material.dart';

import '../../theming/theme_tokens.dart';

/// Tokyo Neon palette: a dark HUD lit by cyan and purple.
///
/// The rule that shapes every value here is that neon is *edge* light, never
/// fill light. Borders, glows and thin rules carry the colour; the surfaces
/// themselves stay near-black so that white Japanese text sits on a quiet
/// background and keeps its contrast. A theme that floods panels with cyan
/// looks striking in a screenshot and is exhausting to study on.
class NeonPalette {
  NeonPalette._();

  /// Bases, darkest to lightest.
  static const voidBlack = Color(0xFF04060E);
  static const navy = Color(0xFF0A1022);
  static const navyRaised = Color(0xFF111A33);
  static const indigo = Color(0xFF1A1440);

  /// Primary neon: cyan, with an electric blue for depth.
  static const cyan = Color(0xFF22E1FF);
  static const electric = Color(0xFF3B82F6);

  /// Secondary neon.
  static const purple = Color(0xFFA855F7);
  static const magenta = Color(0xFFE935C1);

  /// Highlight. Used sparingly — an accent on an accent.
  static const hotPink = Color(0xFFFF3D8A);

  static const onAccent = Color(0xFF021018);

  static const textPrimary = Color(0xFFEAF6FF);
  static const textSecondary = Color(0xFFA3B8D8);
  static const textTertiary = Color(0xFF6E86AA);

  static const good = Color(0xFF3BF5B0);
  static const bad = Color(0xFFFF4D6D);
  static const warn = Color(0xFFFFC94D);
}

/// Neon-specific geometry the generic token classes don't cover.
class NeonMetrics {
  NeonMetrics._();

  /// Opacity of the neon rule around a surface, per level.
  static const double borderSubtle = 0.34;
  static const double borderStandard = 0.48;
  static const double borderElevated = 0.70;

  /// Opacity of the dark body, per level. High on purpose: the surface is a
  /// solid panel, not glass, which is also why this theme costs almost
  /// nothing to draw.
  static const double bodySubtle = 0.62;
  static const double bodyStandard = 0.78;
  static const double bodyElevated = 0.90;

  /// Outer glow strength, per level. Only drawn when heavy effects are on.
  static const double glowSubtle = 0.10;
  static const double glowStandard = 0.16;
  static const double glowElevated = 0.26;

  static const double glowBlurSubtle = 8;
  static const double glowBlurStandard = 14;
  static const double glowBlurElevated = 22;

  /// How much brighter the neon rule gets while a surface is held.
  static const double pressBorderBoost = 0.30;

  /// Extra glow while held.
  static const double pressGlowBoost = 0.18;

  /// Length of a corner bracket, as a fraction of the shorter side, capped
  /// by [cornerMax].
  static const double cornerFraction = 0.16;
  static const double cornerMax = 22;
}

const ThemeTokens kTokyoNeonTokens = ThemeTokens(
  colors: ThemeColors(
    accent: NeonPalette.cyan,
    onAccent: NeonPalette.onAccent,
    textPrimary: NeonPalette.textPrimary,
    textSecondary: NeonPalette.textSecondary,
    textTertiary: NeonPalette.textTertiary,
    good: NeonPalette.good,
    bad: NeonPalette.bad,
    warn: NeonPalette.warn,
    border: Color(0x5C22E1FF), // cyan @ 0.36
  ),
  // Tighter than Glass. Hard, machined corners are half of what separates a
  // HUD from a frosted pane.
  radii: ThemeRadii(xs: 4, sm: 7, md: 11, lg: 15, xl: 20),
  spacing: ThemeSpacing(),
  motion: ThemeMotion(
    // Quicker across the board than Glass: this theme's character is
    // precision, and precision reads as *short*.
    fast: Duration(milliseconds: 90),
    base: Duration(milliseconds: 170),
    slow: Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    pressScale: 0.985,
  ),
  text: ThemeTypography(
    jpFontFamily: 'NotoJP',
    jpColor: NeonPalette.textPrimary,
    display: TextStyle(
      color: NeonPalette.textPrimary,
      fontSize: 29,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      height: 1.15,
    ),
    title: TextStyle(
      color: NeonPalette.textPrimary,
      fontSize: 18.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    ),
    cardTitle: TextStyle(
      color: NeonPalette.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
    body: TextStyle(
      color: NeonPalette.textPrimary,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      height: 1.42,
    ),
    secondary: TextStyle(
      color: NeonPalette.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    caption: TextStyle(
      color: NeonPalette.textTertiary,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
    // Wide-tracked small caps: the single most HUD-like thing in the whole
    // theme, and it costs nothing.
    overline: TextStyle(
      color: NeonPalette.cyan,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
    ),
    button: TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  ),
);

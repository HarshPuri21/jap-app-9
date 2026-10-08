import 'package:flutter/material.dart';

import '../../theming/theme_tokens.dart';

/// Zen Minimal palette: sumi ink on warm washi paper, with an indigo (藍)
/// accent. Light, quiet, high-contrast -- chosen so Japanese study text is
/// the darkest, sharpest thing on the screen.
class ZenPalette {
  ZenPalette._();

  static const paperBase = Color(0xFFF7F4EE);
  static const paperSunk = Color(0xFFF1EDE4);
  static const paper = Color(0xFFFBF9F5);
  static const paperRaised = Color(0xFFFFFFFF);

  static const ink = Color(0xFF1C1B18);
  static const inkSoft = Color(0xFF5A564E);
  static const inkFaint = Color(0xFF8C8679);

  static const accent = Color(0xFF2F4F7F); // 藍 indigo
  static const onAccent = Color(0xFFFBF9F5);

  static const good = Color(0xFF2E7D4F);
  static const bad = Color(0xFFB03A34);
  static const warn = Color(0xFF9A6B15);
}

const ThemeTokens kZenMinimalTokens = ThemeTokens(
  colors: ThemeColors(
    accent: ZenPalette.accent,
    onAccent: ZenPalette.onAccent,
    textPrimary: ZenPalette.ink,
    textSecondary: ZenPalette.inkSoft,
    textTertiary: ZenPalette.inkFaint,
    good: ZenPalette.good,
    bad: ZenPalette.bad,
    warn: ZenPalette.warn,
    border: Color(0x331C1B18),
  ),
  // Restrained geometry: gentler corners than the glass theme, closer to a
  // trimmed sheet of paper than a rounded pane.
  radii: ThemeRadii(xs: 4, sm: 6, md: 8, lg: 10, xl: 12),
  spacing: ThemeSpacing(),
  motion: ThemeMotion(
    curve: Curves.easeOut,
    // Paper doesn't bounce; the press is shown by the sheet darkening.
    pressScale: 1.0,
  ),
  text: ThemeTypography(
    jpFontFamily: 'NotoJP',
    jpColor: ZenPalette.ink,
    display: TextStyle(
      color: ZenPalette.ink,
      fontSize: 28,
      fontWeight: FontWeight.w300,
      letterSpacing: 0.5,
      height: 1.2,
    ),
    title: TextStyle(
      color: ZenPalette.ink,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
    cardTitle: TextStyle(
      color: ZenPalette.ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    body: TextStyle(
      color: ZenPalette.ink,
      fontSize: 14.5,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    secondary: TextStyle(
      color: ZenPalette.inkSoft,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    caption: TextStyle(
      color: ZenPalette.inkFaint,
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
    ),
    overline: TextStyle(
      color: ZenPalette.inkFaint,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.2,
    ),
    button: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
  ),
);

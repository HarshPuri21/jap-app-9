import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Theme tokens
/// ---------------------------------------------------------------------------
/// The vocabulary every theme has to speak. Screens never name a colour, a
/// radius or a font size directly -- they ask for a *role* ("card title",
/// "accent", "gutter") and whichever theme is active decides what that role
/// looks like.
///
/// Nothing here knows anything about kanji, reviews or scoring. These are
/// pure presentation values.

/// How far forward a surface reads. Themes are free to interpret the three
/// levels however they like -- Glass varies blur and translucency,
/// Zen Minimal varies paper weight and border strength -- but the *meaning*
/// is fixed so screens can ask for the right one without knowing the theme.
enum SurfaceLevel {
  /// Chips, badges, inner rows, secondary controls.
  subtle,

  /// The workhorse: cards, panels, list tiles, sections.
  standard,

  /// Dialogs, question prompts, primary actions, floating elements.
  elevated,
}

@immutable
class ThemeColors {
  /// The theme's signature colour, used for emphasis and primary actions.
  final Color accent;

  /// A legible foreground for text/icons drawn *on top of* a filled accent.
  final Color onAccent;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Semantic states. Their meaning is fixed app-wide (correct / incorrect /
  /// caution); only their exact hue is the theme's choice.
  final Color good;
  final Color bad;
  final Color warn;

  /// Hairline/divider colour.
  final Color border;

  const ThemeColors({
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.good,
    required this.bad,
    required this.warn,
    required this.border,
  });

  /// Difficulty labels come from the data files as plain strings; mapping
  /// them to colours is a presentation decision, so it lives here.
  Color forDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return good;
      case 'normal':
        return warn;
      case 'hard':
        return bad;
      default:
        return textTertiary;
    }
  }
}

@immutable
class ThemeRadii {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const ThemeRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  /// Fully rounded. Not theme-dependent -- a pill is a pill.
  static const double pill = 999;
}

@immutable
class ThemeSpacing {
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  /// Standard horizontal screen margin.
  final double gutter;

  const ThemeSpacing({
    this.xxs = 4,
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 20,
    this.xl = 28,
    this.xxl = 36,
    this.gutter = 20,
  });
}

@immutable
class ThemeMotion {
  final Duration fast;
  final Duration base;
  final Duration slow;
  final Curve curve;

  /// How far a pressable surface shrinks while held. A theme that wants no
  /// press animation at all sets this to 1.0.
  final double pressScale;

  const ThemeMotion({
    this.fast = const Duration(milliseconds: 120),
    this.base = const Duration(milliseconds: 220),
    this.slow = const Duration(milliseconds: 380),
    this.curve = Curves.easeOutCubic,
    this.pressScale = 0.975,
  });
}

/// Named text roles. Screens ask for `text.cardTitle`, never for a font size.
@immutable
class ThemeTypography {
  final TextStyle display;
  final TextStyle title;
  final TextStyle cardTitle;
  final TextStyle body;
  final TextStyle secondary;
  final TextStyle caption;
  final TextStyle overline;
  final TextStyle button;

  /// Font family used for Japanese. Kept separate from the Latin UI font
  /// because legibility of kana and kanji is non-negotiable: a theme may
  /// restyle its labels freely, but the study content stays in a font that
  /// is known to render every character crisply.
  final String jpFontFamily;

  /// Default colour for Japanese study text.
  final Color jpColor;

  const ThemeTypography({
    required this.display,
    required this.title,
    required this.cardTitle,
    required this.body,
    required this.secondary,
    required this.caption,
    required this.overline,
    required this.button,
    required this.jpFontFamily,
    required this.jpColor,
  });

  /// Japanese study text at an explicit size. This is the one place in the
  /// app allowed to name a font size, because the size *is* the meaning here
  /// (a 92pt kanji versus a 15pt reading).
  TextStyle jp(double size, {FontWeight weight = FontWeight.w500, Color? color}) {
    return TextStyle(
      fontFamily: jpFontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? jpColor,
      height: 1.35,
    );
  }
}

/// Everything a theme exposes as plain values, bundled.
@immutable
class ThemeTokens {
  final ThemeColors colors;
  final ThemeRadii radii;
  final ThemeSpacing spacing;
  final ThemeMotion motion;
  final ThemeTypography text;

  const ThemeTokens({
    required this.colors,
    required this.radii,
    required this.spacing,
    this.motion = const ThemeMotion(),
    required this.text,
  });
}

import 'package:flutter/material.dart';

import '../models/jlpt_level.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import 'themed/themed_surface.dart';

/// Compact learner-facing level badge.
///
/// JLPT is the primary label whenever the item has a level (N5 -> N1).
/// Difficulty remains the fallback for content that has no JLPT metadata and
/// still supplies the tint, preserving the existing theme language.
class JlptLevelBadge extends StatelessWidget {
  final JlptLevel? level;
  final String difficulty;

  const JlptLevelBadge({
    super.key,
    required this.level,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = t.colors.forDifficulty(difficulty);
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      tint: color,
      tintStrength: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        level?.label ?? difficulty.toUpperCase(),
        style: t.text.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import 'themed/themed_surface.dart';

/// Difficulty pill. Tiny and repeated, so it always takes the cheap path.
class DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const DifficultyBadge({super.key, required this.difficulty});

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            difficulty.toUpperCase(),
            style: t.text.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

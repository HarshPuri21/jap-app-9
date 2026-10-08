import 'package:flutter/material.dart';

import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import 'themed/themed_surface.dart';

/// A learning-mode entry point.
///
/// The public API is unchanged (`icon`, `title`, `subtitle`, `onTap`) so every
/// existing call site keeps working; the extra parameters are optional. All
/// styling is delegated -- this widget names roles, never colours.
class ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Optional accent override, so a list of modes can be distinguishable at
  /// a glance without any of them shouting.
  final Color? accentColor;

  /// Optional short status line ("124 learned", "12 due").
  final String? trailingLabel;

  /// Optional 0..1 progress shown as a hairline bar under the text.
  final double? progress;

  /// Renders on the elevated tier, for a highlighted card.
  final bool emphasized;

  final bool enabled;

  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
    this.trailingLabel,
    this.progress,
    this.emphasized = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = accentColor ?? t.colors.accent;

    return ThemedCard(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      level: emphasized ? SurfaceLevel.elevated : SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      tint: emphasized ? accent : null,
      tintStrength: 0.7,
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          ThemedIconPlate(
            icon: icon,
            color: accent,
            size: emphasized ? 54 : 50,
            iconSize: emphasized ? 26 : 23,
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.cardTitle,
                      ),
                    ),
                    if (trailingLabel != null) ...[
                      SizedBox(width: t.spacing.xs),
                      Text(
                        trailingLabel!,
                        style: t.text.caption.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.secondary.copyWith(fontSize: 12.5),
                ),
                if (progress != null) ...[
                  SizedBox(height: t.spacing.xs),
                  _HairlineBar(value: progress!, color: accent),
                ],
              ],
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            color: t.colors.textTertiary,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _HairlineBar extends StatelessWidget {
  final double value;
  final Color color;
  const _HairlineBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(ThemeRadii.pill),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: t.colors.textTertiary.withOpacity(0.25)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v == 0 ? 0.0001 : v,
                heightFactor: 1,
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import 'themed/themed_surface.dart';

enum OptionState { idle, selectedCorrect, selectedWrong, revealCorrect }

/// A multiple-choice answer.
///
/// Two things are deliberate and are *app* decisions, not theme ones:
///
///  * `allowHeavyEffects: false`. Four to six of these appear on every
///    question screen, so the theme is told to use its cheap path rather than
///    stacking six expensive passes.
///  * State is never communicated by colour alone -- correct and wrong also
///    gain an icon, and the theme strengthens the outline of a selected
///    surface. That survives colour blindness.
class OptionButton extends StatelessWidget {
  final String text;
  final OptionState state;
  final VoidCallback? onTap;

  const OptionButton({
    super.key,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Color? tint;
    Color fg = t.colors.textPrimary;
    IconData? badge;
    SurfaceLevel level = SurfaceLevel.standard;
    bool selected = false;

    switch (state) {
      case OptionState.idle:
        break;
      case OptionState.selectedCorrect:
        tint = t.colors.good;
        fg = t.colors.good;
        badge = Icons.check_circle_rounded;
        level = SurfaceLevel.elevated;
        selected = true;
        break;
      case OptionState.selectedWrong:
        tint = t.colors.bad;
        fg = t.colors.bad;
        badge = Icons.cancel_rounded;
        level = SurfaceLevel.elevated;
        selected = true;
        break;
      case OptionState.revealCorrect:
        tint = t.colors.good;
        fg = t.colors.good;
        badge = Icons.check_circle_outline_rounded;
        selected = true;
        break;
    }

    return ThemedCard(
      onTap: onTap,
      level: level,
      radius: t.radii.sm,
      allowHeavyEffects: false,
      tint: tint,
      tintStrength: 0.9,
      selected: selected,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.md,
      ),
      semanticLabel: text,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              textAlign: badge == null ? TextAlign.center : TextAlign.start,
              style: t.text.body.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
                height: 1.3,
              ),
            ),
          ),
          if (badge != null) ...[
            SizedBox(width: t.spacing.xs),
            Icon(badge, color: fg, size: 20),
          ],
        ],
      ),
    );
  }
}

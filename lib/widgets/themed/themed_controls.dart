import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_scope.dart';
import '../../theming/theme_tokens.dart';
import 'themed_surface.dart';

/// Visual weight of a [ThemedButton]. What each weight *looks* like is the
/// theme's business; what it *means* is fixed.
enum ThemedButtonVariant { primary, secondary }

/// The app's button. A null [onPressed] disables it, matching
/// `ElevatedButton`'s contract, so screens can swap one for the other
/// without touching their logic.
class ThemedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ThemedButtonVariant variant;
  final IconData? icon;

  /// Overrides the accent, for semantic actions.
  final Color? color;

  final bool expand;
  final EdgeInsetsGeometry? padding;

  const ThemedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ThemedButtonVariant.primary,
    this.icon,
    this.color,
    this.expand = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isPrimary = variant == ThemedButtonVariant.primary;
    final accent = color ?? t.colors.accent;
    final enabled = onPressed != null;

    final labelColor = !enabled
        ? t.colors.textTertiary
        : (isPrimary ? accent : t.colors.textPrimary);

    return ThemedCard(
      onTap: onPressed,
      enabled: enabled,
      level: isPrimary ? SurfaceLevel.elevated : SurfaceLevel.subtle,
      radius: t.radii.sm,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: t.spacing.lg,
            vertical: t.spacing.md,
          ),
      tint: isPrimary ? accent : null,
      tintStrength: 0.85,
      semanticLabel: label,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: labelColor),
            SizedBox(width: t.spacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: t.text.button.copyWith(color: labelColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular/rounded plate around a single icon. Back arrows, close
/// buttons, the settings entry point.
class ThemedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double iconSize;
  final String? tooltip;

  const ThemedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 44,
    this.iconSize = 21,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget button = ThemedCard(
      onTap: onPressed,
      enabled: onPressed != null,
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      padding: EdgeInsets.zero,
      semanticLabel: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: iconSize,
          color: color ?? t.colors.textPrimary,
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// A filter/selector chip.
///
/// Selected state is carried by an icon *and* a label colour *and* whatever
/// the theme does to a selected surface -- never by colour alone, so it still
/// reads for colour-blind users.
class ThemedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const ThemedChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = color ?? t.colors.accent;

    return ThemedCard(
      onTap: onTap,
      level: selected ? SurfaceLevel.standard : SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      // Repeated in horizontal strips on several screens -- keep it cheap.
      allowHeavyEffects: false,
      tint: selected ? accent : null,
      selected: selected,
      showShadow: selected,
      semanticLabel: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Icon(Icons.check_rounded, size: 14, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: t.text.caption.copyWith(
              color: selected ? accent : t.colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A progress bar. Animates value changes so progress glides rather than
/// jumps between questions.
class ThemedProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  final double height;

  const ThemedProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 7,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = color ?? t.colors.accent;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();

    return Semantics(
      value: '${(clamped * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: t.colors.textTertiary.withOpacity(0.22),
          borderRadius: BorderRadius.circular(ThemeRadii.pill),
          border: Border.all(color: t.colors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThemeRadii.pill),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: t.motion.slow,
              curve: t.motion.curve,
              builder: (context, v, _) {
                // True only while the bar is still travelling to its new
                // value. Themes use it to run a highlight during the change
                // and then stop -- a bar that animates forever burns a frame
                // of work for no information.
                final animating = (v - clamped).abs() > 0.001;
                return FractionallySizedBox(
                  widthFactor: v == 0 ? 0.0001 : v,
                  heightFactor: 1,
                  child: context.appTheme.buildProgressFill(
                    context,
                    ProgressFillRequest(
                      value: v,
                      animating: animating,
                      color: accent,
                      height: height,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet section header used to group settings and setup options.
class ThemedSectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;

  const ThemedSectionLabel(this.text, {super.key, this.padding});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: padding ??
          EdgeInsets.only(left: 4, bottom: t.spacing.sm),
      child: Text(text.toUpperCase(), style: t.text.overline),
    );
  }
}

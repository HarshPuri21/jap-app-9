import 'package:flutter/material.dart';

import '../../theming/theme_scope.dart';
import '../../theming/theme_tokens.dart';
import 'themed_controls.dart';
import 'themed_surface.dart';

/// The app's header.
///
/// A plain widget rather than a `PreferredSizeWidget`, because every screen
/// composes its own header inside a `Column` -- keeping that structure means
/// navigation behaviour is untouched by the theme engine.
class ThemedAppBar extends StatelessWidget {
  final String title;

  /// Optional second line, e.g. the Japanese name of the screen.
  final String? subtitle;

  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;

  /// Right-hand slot: a score, a counter, a settings button.
  final Widget? trailing;

  const ThemedAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon = Icons.arrow_back_rounded,
    this.onLeadingTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.xs,
        t.spacing.md,
        t.spacing.sm,
      ),
      child: ThemedSurface(
        level: SurfaceLevel.standard,
        radius: t.radii.lg,
        padding: EdgeInsets.all(t.spacing.xs),
        child: Row(
          children: [
            if (onLeadingTap != null)
              ThemedIconButton(
                icon: leadingIcon,
                onPressed: onLeadingTap,
                size: 40,
                iconSize: 20,
                tooltip: 'Back',
              ),
            SizedBox(
              width: onLeadingTap != null ? t.spacing.sm : t.spacing.xs,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.title,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text
                          .jp(11.5, color: t.colors.textTertiary)
                          .copyWith(letterSpacing: 2),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: t.spacing.xs),
              Padding(
                padding: EdgeInsets.only(right: t.spacing.xs),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact read-only pill for app-bar trailing slots (score, counter).
class ThemedStatPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;

  const ThemedStatPill({
    super.key,
    required this.text,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.colors.accent;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      tint: c,
      tintStrength: 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: t.text.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A search/input field on a themed surface. Used by the radical browser.
class ThemedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onClear;
  final bool showClear;

  const ThemedTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onClear,
    this.showClear = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.sm,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        style: t.text.body,
        cursorColor: t.colors.accent,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: t.text.secondary,
          prefixIcon: Icon(Icons.search, color: t.colors.textTertiary),
          suffixIcon: !showClear
              ? null
              : IconButton(
                  icon: Icon(Icons.clear, color: t.colors.textTertiary),
                  onPressed: onClear,
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// A floating themed dialog.
Future<T?> showThemedDialog<T>({
  required BuildContext context,
  String? title,
  required Widget content,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  final t = context.tokens;
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (ctx) => Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.spacing.xl),
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ThemedSurface(
              level: SurfaceLevel.elevated,
              radius: t.radii.lg,
              padding: EdgeInsets.all(t.spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Text(title, style: t.text.title),
                    SizedBox(height: t.spacing.sm),
                  ],
                  content,
                  if (actions.isNotEmpty) ...[
                    SizedBox(height: t.spacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) SizedBox(width: t.spacing.sm),
                          Flexible(child: actions[i]),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_scope.dart';
import '../../theming/theme_tokens.dart';

/// A surface, painted by whichever theme is active.
///
/// This widget contains no styling of its own. It translates the app's intent
/// ("an elevated panel tinted green, with this padding") into a
/// [SurfaceRequest] and hands it to the theme. Swapping the theme swaps every
/// surface in the app with no screen edits.
class ThemedSurface extends StatelessWidget {
  final Widget child;
  final SurfaceLevel level;

  /// Corner rounding. Defaults to the theme's medium radius.
  final double? radius;
  final BorderRadius? borderRadius;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  final Color? tint;
  final double tintStrength;
  final bool selected;
  final bool showShadow;

  /// Set false for surfaces repeated many times on one screen, so themes
  /// with expensive effects can use a cheap path. See [SurfaceRequest].
  final bool allowHeavyEffects;

  final double? width;
  final double? height;

  const ThemedSurface({
    super.key,
    required this.child,
    this.level = SurfaceLevel.standard,
    this.radius,
    this.borderRadius,
    this.padding,
    this.margin,
    this.tint,
    this.tintStrength = 1.0,
    this.selected = false,
    this.showShadow = true,
    this.allowHeavyEffects = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final tokens = theme.tokens;

    Widget surface = theme.buildSurface(
      context,
      SurfaceRequest(
        level: level,
        borderRadius:
            borderRadius ?? BorderRadius.circular(radius ?? tokens.radii.md),
        padding: padding ?? EdgeInsets.all(tokens.spacing.md),
        tint: tint,
        tintStrength: tintStrength,
        selected: selected,
        showShadow: showShadow,
        allowHeavyEffects: allowHeavyEffects,
        width: width,
        height: height,
        child: child,
      ),
    );

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

/// A tappable [ThemedSurface].
///
/// The gesture handling, the disabled guard and the press *value* live here,
/// theme-agnostically; how that press value is rendered (a scale-down, a
/// brightening, an ink ripple, nothing at all) is up to the theme, which
/// receives it as `pressAmount` in the [SurfaceRequest].
class ThemedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final SurfaceLevel level;
  final double? radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final double tintStrength;
  final bool selected;
  final bool showShadow;
  final bool allowHeavyEffects;
  final bool enabled;
  final double? width;
  final double? height;

  /// Read out by screen readers. Worth setting whenever the visible label
  /// alone doesn't explain what tapping does.
  final String? semanticLabel;

  const ThemedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.level = SurfaceLevel.standard,
    this.radius,
    this.borderRadius,
    this.padding,
    this.margin,
    this.tint,
    this.tintStrength = 1.0,
    this.selected = false,
    this.showShadow = true,
    this.allowHeavyEffects = true,
    this.enabled = true,
    this.width,
    this.height,
    this.semanticLabel,
  });

  @override
  State<ThemedCard> createState() => _ThemedCardState();
}

class _ThemedCardState extends State<ThemedCard> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final tokens = theme.tokens;

    Widget surface = theme.buildSurface(
      context,
      SurfaceRequest(
        level: widget.level,
        borderRadius: widget.borderRadius ??
            BorderRadius.circular(widget.radius ?? tokens.radii.md),
        padding: widget.padding ?? EdgeInsets.all(tokens.spacing.md),
        tint: widget.tint,
        tintStrength: widget.tintStrength,
        selected: widget.selected,
        pressAmount: _pressed ? 1.0 : 0.0,
        enabled: widget.enabled,
        showShadow: widget.showShadow,
        allowHeavyEffects: widget.allowHeavyEffects,
        width: widget.width,
        height: widget.height,
        child: widget.child,
      ),
    );

    if (_interactive) {
      surface = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: surface,
      );
    }

    if (widget.semanticLabel != null) {
      surface = Semantics(
        label: widget.semanticLabel,
        button: _interactive,
        enabled: widget.enabled,
        child: surface,
      );
    }

    if (widget.margin != null) {
      surface = Padding(padding: widget.margin!, child: surface);
    }

    return surface;
  }
}

/// The decorative plate behind an icon, delegated to the theme.
class ThemedIconPlate extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;

  const ThemedIconPlate({
    super.key,
    required this.icon,
    this.color,
    this.size = 50,
    this.iconSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return theme.buildIconPlate(
      context,
      icon: icon,
      color: color ?? theme.tokens.colors.accent,
      size: size,
      iconSize: iconSize,
    );
  }
}

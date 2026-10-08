import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_tokens.dart';
import 'tokyo_neon_tokens.dart';

/// Paints one Tokyo Neon panel.
///
/// A dark, near-opaque body with a thin neon rule around it, an outer glow,
/// and — on the most forward surfaces — HUD corner brackets.
///
/// Deliberately cheap. There is no backdrop blur anywhere in this theme: the
/// body is opaque enough that blurring what's behind it would be invisible
/// work. That means a screen full of Tokyo Neon panels costs roughly what a
/// screen full of plain `Container`s costs, and the theme's entire budget can
/// go on the interaction animations instead.
///
/// ### Sizing
///
/// [SurfaceRequest.width] and `height` may be [double.infinity]. They are
/// applied with a [SizedBox] and the incoming constraints are passed through
/// untouched, so a full-width panel inside a scroll view lays out correctly.
/// See the note on [SurfaceRequest.width]; getting this wrong is what made
/// answer explanations vanish under the previous Glass implementation.
class TokyoNeonSurface extends StatelessWidget {
  final SurfaceRequest request;

  /// The global "visual effects" switch.
  final bool effectsEnabled;

  const TokyoNeonSurface({
    super.key,
    required this.request,
    required this.effectsEnabled,
  });

  T _byLevel<T>(T subtle, T standard, T elevated) {
    switch (request.level) {
      case SurfaceLevel.subtle:
        return subtle;
      case SurfaceLevel.standard:
        return standard;
      case SurfaceLevel.elevated:
        return elevated;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;

    // Heavy here means glow and corner brackets. The neon rule itself is
    // never dropped: it is the theme's only way of expressing depth and
    // selection, so losing it would change contrast, not just polish.
    final heavy = effectsEnabled && r.allowHeavyEffects;

    final neon = r.tint ?? NeonPalette.cyan;

    final bodyOpacity = _byLevel(
      NeonMetrics.bodySubtle,
      NeonMetrics.bodyStandard,
      NeonMetrics.bodyElevated,
    );
    final borderOpacity = _byLevel(
      NeonMetrics.borderSubtle,
      NeonMetrics.borderStandard,
      NeonMetrics.borderElevated,
    );
    final glowOpacity = heavy
        ? _byLevel(
            NeonMetrics.glowSubtle,
            NeonMetrics.glowStandard,
            NeonMetrics.glowElevated,
          )
        : 0.0;
    final glowBlur = _byLevel(
      NeonMetrics.glowBlurSubtle,
      NeonMetrics.glowBlurStandard,
      NeonMetrics.glowBlurElevated,
    );

    // Selection is carried by a visibly thicker, brighter rule — and stays
    // that way permanently, long after any selection animation has finished.
    final selectedBoost = r.selected ? 0.26 : 0.0;
    final borderWidth = r.selected
        ? 1.6
        : (r.level == SurfaceLevel.elevated ? 1.2 : 1.0);

    // Only the panel skin animates on press. The content is the Stack's
    // non-positioned child, outside the builder, so it is neither rebuilt nor
    // relaid-out while a button is held.
    final skin = Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: r.pressAmount),
          duration: kTokyoNeonTokens.motion.fast,
          curve: Curves.easeOut,
          builder: (context, press, _) => _NeonSkin(
            borderRadius: r.borderRadius,
            neon: neon,
            tint: r.tint,
            tintStrength: r.tintStrength,
            bodyOpacity: bodyOpacity,
            borderOpacity:
                (borderOpacity + selectedBoost + press * NeonMetrics.pressBorderBoost)
                    .clamp(0.0, 1.0),
            borderWidth: borderWidth,
            glowOpacity: glowOpacity <= 0
                ? 0.0
                : (glowOpacity +
                        selectedBoost * 0.4 +
                        press * NeonMetrics.pressGlowBoost)
                    .clamp(0.0, 1.0),
            glowBlur: glowBlur,
            press: press,
            showCorners: heavy && r.level == SurfaceLevel.elevated,
          ),
        ),
      ),
    );

    final sized = r.width != null || r.height != null;

    Widget result = SizedBox(
      width: r.width,
      height: r.height,
      child: Stack(
        fit: sized ? StackFit.passthrough : StackFit.loose,
        children: [
          skin,
          Padding(padding: r.padding, child: r.child),
        ],
      ),
    );

    if (!r.enabled) {
      result = Opacity(opacity: 0.45, child: result);
    }

    final pressScale = kTokyoNeonTokens.motion.pressScale;
    if (r.pressAmount > 0 || pressScale != 1.0) {
      result = AnimatedScale(
        scale: r.pressAmount > 0 ? pressScale : 1.0,
        duration: kTokyoNeonTokens.motion.fast,
        curve: Curves.easeOut,
        child: result,
      );
    }

    return result;
  }
}

/// The panel skin at a given press amount: body, rule, glow, corner brackets
/// and the press light-sweep. One `DecoratedBox` plus, at most, one cheap
/// `CustomPaint`.
class _NeonSkin extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color neon;
  final Color? tint;
  final double tintStrength;
  final double bodyOpacity;
  final double borderOpacity;
  final double borderWidth;
  final double glowOpacity;
  final double glowBlur;
  final double press;
  final bool showCorners;

  const _NeonSkin({
    required this.borderRadius,
    required this.neon,
    required this.tint,
    required this.tintStrength,
    required this.bodyOpacity,
    required this.borderOpacity,
    required this.borderWidth,
    required this.glowOpacity,
    required this.glowBlur,
    required this.press,
    required this.showCorners,
  });

  @override
  Widget build(BuildContext context) {
    Color top = NeonPalette.navyRaised.withOpacity(bodyOpacity);
    Color bottom = NeonPalette.voidBlack.withOpacity(
      (bodyOpacity + 0.06).clamp(0.0, 1.0),
    );

    final tintColor = tint;
    if (tintColor != null) {
      // Tint the body only faintly. The colour's real job in this theme is
      // done by the rule and the glow, which are already tinted.
      final strength = (0.16 * tintStrength).clamp(0.0, 1.0);
      top = Color.alphaBlend(tintColor.withOpacity(strength), top);
      bottom =
          Color.alphaBlend(tintColor.withOpacity(strength * 0.45), bottom);
    }

    Widget skin = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        border: Border.all(
          color: neon.withOpacity(borderOpacity),
          width: borderWidth,
        ),
        boxShadow: glowOpacity <= 0
            ? null
            : [
                BoxShadow(
                  color: neon.withOpacity(glowOpacity),
                  blurRadius: glowBlur,
                ),
              ],
      ),
    );

    if (showCorners || press > 0.001) {
      skin = Stack(
        fit: StackFit.expand,
        children: [
          skin,
          // A fast band of light crossing the panel as it is pressed. Sharper
          // and quicker than Glass's equivalent — this is a signal, not a
          // reflection.
          if (press > 0.001)
            ClipRRect(
              borderRadius: borderRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.8 + press * 2.2, 0),
                    end: Alignment(-1.1 + press * 2.2, 0),
                    colors: [
                      Colors.transparent,
                      neon.withOpacity(0.18 * press),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          if (showCorners)
            CustomPaint(
              painter: _CornerBracketsPainter(
                color: neon.withOpacity((borderOpacity + 0.2).clamp(0.0, 1.0)),
                borderRadius: borderRadius,
                strokeWidth: borderWidth + 0.6,
              ),
            ),
        ],
      );
    }

    return skin;
  }
}

/// Four short HUD brackets at the panel's corners.
///
/// Eight `drawLine` calls, repainted only when a colour or radius actually
/// changes — cheaper than the border it sits beside.
class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final BorderRadius borderRadius;
  final double strokeWidth;

  const _CornerBracketsPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final len = (size.shortestSide * NeonMetrics.cornerFraction)
        .clamp(6.0, NeonMetrics.cornerMax);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Start each bracket past the corner radius so it runs along the straight
    // part of the edge rather than cutting across the curve.
    final tl = borderRadius.topLeft.x;
    final tr = borderRadius.topRight.x;
    final bl = borderRadius.bottomLeft.x;
    final br = borderRadius.bottomRight.x;

    final inset = strokeWidth / 2;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset(tl, inset), Offset(tl + len, inset), paint);
    canvas.drawLine(Offset(inset, tl), Offset(inset, tl + len), paint);
    // Top-right
    canvas.drawLine(Offset(w - tr, inset), Offset(w - tr - len, inset), paint);
    canvas.drawLine(Offset(w - inset, tr), Offset(w - inset, tr + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(bl, h - inset), Offset(bl + len, h - inset), paint);
    canvas.drawLine(Offset(inset, h - bl), Offset(inset, h - bl - len), paint);
    // Bottom-right
    canvas.drawLine(
        Offset(w - br, h - inset), Offset(w - br - len, h - inset), paint);
    canvas.drawLine(
        Offset(w - inset, h - br), Offset(w - inset, h - br - len), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketsPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.strokeWidth != strokeWidth;
}

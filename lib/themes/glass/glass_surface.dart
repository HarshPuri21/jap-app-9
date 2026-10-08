import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_tokens.dart';
import 'glass_tokens.dart';

/// Paints one pane of Glass.
///
/// Layer order, bottom to top:
///   backdrop (the user's wallpaper / the theme's own gradient)
///     -> backdrop blur          (skipped when effects are off, or when the
///                                caller says this surface repeats a lot)
///     -> dark ink + frost body  (holds text contrast over bright photos)
///     -> specular top sheen
///     -> press sweep            (a soft band of light that slides across
///                                while the pane is held)
///     -> content
///   ...with a hairline border and an *outer-only* ambient shadow around it.
///
/// ### Sizing
///
/// [SurfaceRequest.width] and `height` may be [double.infinity], meaning
/// "fill the parent on this axis". They are applied with a [SizedBox] and the
/// resulting constraints are handed to the pane untouched
/// ([StackFit.passthrough]).
///
/// This is load-bearing. An earlier version tightened the pane against
/// `constraints.biggest`, which is correct only when both axes are bounded.
/// Every full-bleed panel inside a scroll view -- the answer explanation in
/// Practice, the radical's usage and example cards -- has an *unbounded*
/// vertical axis, so that tightening produced an infinite height constraint,
/// the surface failed to lay out, and its content silently disappeared. The
/// explanation was never missing from the app; it was being dropped here, by
/// the theme, on exactly the surfaces that asked to be full width.
///
/// `test/theme_surface_contract_test.dart` renders this case for every theme
/// in the registry so it cannot come back unnoticed.
class GlassSurface extends StatelessWidget {
  final SurfaceRequest request;

  /// Comes from the global "visual effects" switch in Settings.
  final bool effectsEnabled;

  const GlassSurface({
    super.key,
    required this.request,
    required this.effectsEnabled,
  });

  double _byLevel(double subtle, double standard, double elevated) {
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
    final br = r.borderRadius;

    final sigma = _byLevel(
      GlassMetrics.blurSubtle,
      GlassMetrics.blurStandard,
      GlassMetrics.blurElevated,
    );
    final inkOpacity = _byLevel(
      GlassMetrics.inkSubtle,
      GlassMetrics.inkStandard,
      GlassMetrics.inkElevated,
    );
    final frostOpacity = _byLevel(
      GlassMetrics.frostSubtle,
      GlassMetrics.frostStandard,
      GlassMetrics.frostElevated,
    );
    final sheenOpacity = _byLevel(
      GlassMetrics.sheenSubtle,
      GlassMetrics.sheenStandard,
      GlassMetrics.sheenElevated,
    );
    var borderOpacity = _byLevel(
      GlassMetrics.borderSubtle,
      GlassMetrics.borderStandard,
      GlassMetrics.borderElevated,
    );
    final shadowOpacity = _byLevel(
      GlassMetrics.shadowSubtle,
      GlassMetrics.shadowStandard,
      GlassMetrics.shadowElevated,
    );

    // A selected surface gets a distinctly stronger outline, so selection is
    // legible even for someone who can't see the tint colour, and so it
    // survives after any selection animation has finished.
    var borderWidth = r.level == SurfaceLevel.elevated ? 1.2 : 1.0;
    if (r.selected) {
      borderOpacity = (borderOpacity + 0.16).clamp(0.0, 1.0);
      borderWidth = 1.4;
    }

    final useBlur = effectsEnabled && r.allowHeavyEffects;
    // A pane that wanted blur but can't have it darkens slightly, so text
    // contrast is identical either way.
    final inkBoost = (!useBlur && r.allowHeavyEffects)
        ? GlassMetrics.noBlurInkCompensation
        : 0.0;

    final tint = r.tint;

    final borderColor = tint == null
        ? GlassPalette.sheen.withOpacity(borderOpacity)
        : Color.alphaBlend(
            tint.withOpacity(0.55),
            GlassPalette.sheen.withOpacity(borderOpacity),
          );

    // --- body -------------------------------------------------------------
    // Everything that reacts to the press lives inside this one animated
    // layer. The pane's content is deliberately *outside* it, passed to the
    // Stack directly, so holding a button repaints a couple of gradients and
    // never rebuilds the text, icons or Japanese inside the card.
    final body = Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: r.pressAmount),
          duration: kGlassTokens.motion.fast,
          curve: Curves.easeOut,
          builder: (context, press, _) => _GlassBody(
            press: press,
            selected: r.selected,
            inkOpacity: inkOpacity + inkBoost,
            frostOpacity: frostOpacity,
            sheenOpacity: sheenOpacity,
            tint: tint,
            tintStrength: r.tintStrength,
          ),
        ),
      ),
    );

    Widget content = Stack(
      children: [
        body,
        // The only non-positioned child, so it is what the pane sizes to.
        Padding(padding: r.padding, child: r.child),
      ],
    );

    if (useBlur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }

    Widget pane = ClipRRect(borderRadius: br, child: content);

    // Blurred panes are isolated so an unrelated repaint (a score ticking, a
    // progress bar animating) can't force the expensive filter to re-run.
    if (useBlur) {
      pane = RepaintBoundary(child: pane);
    }

    pane = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: br,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: pane,
    );

    if (!r.enabled) {
      pane = Opacity(opacity: 0.55, child: pane);
    }

    final sized = r.width != null || r.height != null;

    Widget result = SizedBox(
      width: r.width,
      height: r.height,
      child: Stack(
        // passthrough hands this Stack's own constraints to the pane
        // unchanged, so `width: double.infinity` stretches horizontally while
        // an unbounded height stays unbounded. See the class doc -- tightening
        // here is what dropped the explanation panels.
        //
        // With no explicit size the pane shrink-wraps, exactly as before.
        fit: sized ? StackFit.passthrough : StackFit.loose,
        children: [
          if (r.showShadow)
            Positioned.fill(
              child: IgnorePointer(
                child: _OuterShadow(
                  borderRadius: br,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withOpacity(shadowOpacity),
                      blurRadius: _byLevel(12, 22, 34),
                      offset: Offset(0, _byLevel(4, 10, 16)),
                    ),
                    if (tint != null)
                      BoxShadow(
                        color: tint.withOpacity(0.16),
                        blurRadius: _byLevel(10, 18, 27),
                        offset: Offset(0, _byLevel(2, 5, 8)),
                      ),
                  ],
                ),
              ),
            ),
          pane,
        ],
      ),
    );

    final pressScale = kGlassTokens.motion.pressScale;
    if (r.pressAmount > 0 || pressScale != 1.0) {
      result = AnimatedScale(
        scale: r.pressAmount > 0 ? pressScale : 1.0,
        duration: kGlassTokens.motion.fast,
        curve: Curves.easeOut,
        child: result,
      );
    }

    return result;
  }
}

/// The translucent body of a pane at a given press amount.
///
/// Three stacked gradients, no blur, no clipping -- the parent already clips.
/// Cheap enough to repaint every frame of a 120ms press.
class _GlassBody extends StatelessWidget {
  final double press;
  final bool selected;
  final double inkOpacity;
  final double frostOpacity;
  final double sheenOpacity;
  final Color? tint;
  final double tintStrength;

  const _GlassBody({
    required this.press,
    required this.selected,
    required this.inkOpacity,
    required this.frostOpacity,
    required this.sheenOpacity,
    required this.tint,
    required this.tintStrength,
  });

  @override
  Widget build(BuildContext context) {
    final brightness =
        press * GlassMetrics.pressBrightness + (selected ? 0.04 : 0.0);

    final ink =
        GlassPalette.ink.withOpacity((inkOpacity - brightness).clamp(0.0, 1.0));

    Color top = Color.alphaBlend(
      GlassPalette.sheen.withOpacity(
          (frostOpacity + sheenOpacity * 0.5 + brightness).clamp(0.0, 1.0)),
      ink,
    );
    Color bottom = Color.alphaBlend(
      GlassPalette.sheen
          .withOpacity((frostOpacity * 0.45 + brightness * 0.5).clamp(0.0, 1.0)),
      ink,
    );

    final tintColor = tint;
    if (tintColor != null) {
      final strength = (0.22 * tintStrength).clamp(0.0, 1.0);
      top = Color.alphaBlend(tintColor.withOpacity(strength), top);
      bottom = Color.alphaBlend(tintColor.withOpacity(strength * 0.55), bottom);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ),
          ),
        ),
        // The specular sheen along the top edge is what makes this read as a
        // physical pane rather than a flat translucent rectangle.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                GlassPalette.sheen.withOpacity(sheenOpacity),
                GlassPalette.sheen.withOpacity(sheenOpacity * 0.22),
                Colors.transparent,
              ],
              stops: const [0.0, 0.18, 0.55],
            ),
          ),
        ),
        // Press sweep: a soft band of light that slides across the pane while
        // it is held. This is the "fluid light" half of the theme's identity
        // -- no bounce, no overshoot, just the highlight moving.
        if (press > 0.001)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.6 + press * 1.4, -1),
                end: Alignment(-0.4 + press * 1.4, 1),
                colors: [
                  Colors.transparent,
                  GlassPalette.sheen.withOpacity(0.10 * press),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
      ],
    );
  }
}

/// Drops an ambient shadow *around* a rounded rectangle without filling it.
///
/// A plain `BoxDecoration` shadow paints the blurred shape solid, which would
/// sit directly behind the translucent pane and turn the glass into a grey
/// slab. Clipping the shadow to everything-except-the-pane keeps the backdrop
/// visible while still giving the surface real depth.
class _OuterShadow extends StatelessWidget {
  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  const _OuterShadow({required this.borderRadius, required this.shadows});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _InverseRRectClipper(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadows,
        ),
      ),
    );
  }
}

class _InverseRRectClipper extends CustomClipper<Path> {
  final BorderRadius borderRadius;
  const _InverseRRectClipper(this.borderRadius);

  @override
  Path getClip(Size size) {
    // Generous margin so the blur tail isn't cut off at the edges.
    const spread = 120.0;
    final outer = Path()
      ..addRect(Rect.fromLTRB(
        -spread,
        -spread,
        size.width + spread,
        size.height + spread,
      ));
    final inner = Path()..addRRect(borderRadius.toRRect(Offset.zero & size));
    return Path.combine(PathOperation.difference, outer, inner);
  }

  @override
  bool shouldReclip(_InverseRRectClipper oldClipper) =>
      oldClipper.borderRadius != borderRadius;
}

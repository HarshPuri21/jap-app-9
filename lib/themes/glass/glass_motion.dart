import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import 'glass_tokens.dart';

/// Glass's motion language: fluid, soft, premium.
///
/// Everything here is one [TweenAnimationBuilder] driving opacity, a small
/// translation and — only while the animation is actually running — a soft
/// bloom of the moment's colour. Nothing loops. Nothing continues once the
/// content has settled: the builder returns the child untouched at `v >= 1`,
/// so a revealed explanation panel costs exactly one plain widget to keep on
/// screen for as long as the user reads it.
///
/// The child is passed through the builder's `child` slot, so the content
/// being revealed is built once and never rebuilt per frame.
class GlassReveal extends StatelessWidget {
  final RevealRequest request;

  const GlassReveal({super.key, required this.request});

  /// How the moment behaves. Glass keeps all of these gentle — the difference
  /// between a correct and a wrong answer is carried by colour and by the
  /// icons the app already draws, not by how violently the panel arrives.
  Duration get _duration {
    switch (request.moment) {
      case ThemeMoment.success:
      case ThemeMoment.error:
        return kGlassTokens.motion.base;
      case ThemeMoment.explanationReveal:
      case ThemeMoment.cardReveal:
        return kGlassTokens.motion.slow;
      case ThemeMoment.selection:
      case ThemeMoment.kanjiReveal:
      case ThemeMoment.radicalReveal:
        return kGlassTokens.motion.fast;
    }
  }

  double get _rise {
    switch (request.moment) {
      case ThemeMoment.explanationReveal:
        return 10;
      case ThemeMoment.cardReveal:
        return 8;
      default:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reduced-motion is an accessibility setting, not a preference to
    // second-guess: hand the content straight through, unanimated.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return request.child;
    }

    final wobble = request.moment == ThemeMoment.error;
    // Null means "no bloom": either the moment has no colour, or this is the
    // cheap path. Kept as a nullable colour rather than a bool so the null
    // check inside the builder is what unlocks the non-null use.
    final Color? bloomTint =
        request.allowHeavyEffects ? request.tint : null;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      child: request.child,
      builder: (context, v, child) {
        // Settled: drop every wrapper. No residual opacity layer, no
        // transform, nothing left running.
        if (v >= 1.0) return child!;

        final t = v.clamp(0.0, 1.0);

        // A gentle damped sway for a wrong answer — a couple of pixels, dying
        // out as it settles. Never a screen shake.
        final dx = wobble ? math.sin(t * math.pi * 3) * (1 - t) * 3.0 : 0.0;
        final dy = (1 - t) * _rise;

        Widget content = child!;

        final bloom = bloomTint;
        if (bloom != null) {
          // A soft pool of the moment's colour blooming through the glass and
          // fading out again: strongest halfway through, gone by the end.
          final strength = math.sin(t * math.pi) * 0.22;
          content = Stack(
            children: [
              content,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.1,
                        colors: [
                          bloom.withOpacity(strength),
                          bloom.withOpacity(strength * 0.25),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: content,
          ),
        );
      },
    );
  }
}

/// Glass's progress fill: a translucent accent body with a soft light crest
/// that only exists while the bar is actually moving.
class GlassProgressFill extends StatelessWidget {
  final ProgressFillRequest request;

  const GlassProgressFill({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final c = request.color;

    if (!request.animating || !request.allowHeavyEffects) {
      // Static state: one flat fill, which is all a settled bar needs.
      return ColoredBox(color: c);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            c,
            c,
            Color.alphaBlend(GlassPalette.sheen.withOpacity(0.55), c),
          ],
          stops: const [0.0, 0.72, 1.0],
        ),
      ),
    );
  }
}

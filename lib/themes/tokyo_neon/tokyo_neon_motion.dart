import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import 'tokyo_neon_tokens.dart';

/// Tokyo Neon's motion language: precise, digital, quick.
///
/// Each moment is one short [TweenAnimationBuilder]. There is no controller,
/// no repetition and nothing left running once the content has settled — the
/// builder returns the child untouched at `v >= 1`, so a revealed explanation
/// panel is a plain widget for as long as the user reads it.
///
/// The revealed content is passed through the builder's `child` slot, so it
/// is built once and never rebuilt per frame. The overlays that move are
/// gradients over the top of it.
class NeonReveal extends StatelessWidget {
  final RevealRequest request;

  const NeonReveal({super.key, required this.request});

  Duration get _duration {
    switch (request.moment) {
      case ThemeMoment.selection:
        return kTokyoNeonTokens.motion.fast;
      case ThemeMoment.success:
      case ThemeMoment.error:
      case ThemeMoment.kanjiReveal:
      case ThemeMoment.radicalReveal:
        return kTokyoNeonTokens.motion.base;
      case ThemeMoment.explanationReveal:
      case ThemeMoment.cardReveal:
        return kTokyoNeonTokens.motion.slow;
    }
  }

  /// Which overlay treatment this moment gets.
  _NeonEffect get _effect {
    switch (request.moment) {
      case ThemeMoment.success:
        return _NeonEffect.pulse;
      case ThemeMoment.error:
        return _NeonEffect.glitch;
      case ThemeMoment.explanationReveal:
      case ThemeMoment.cardReveal:
        return _NeonEffect.verticalScan;
      case ThemeMoment.kanjiReveal:
      case ThemeMoment.radicalReveal:
        return _NeonEffect.horizontalScan;
      case ThemeMoment.selection:
        return _NeonEffect.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reduced-motion is an accessibility setting, not a preference to
    // second-guess: hand the content straight through, unanimated.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return request.child;
    }

    final accent = request.tint ??
        (request.moment == ThemeMoment.error
            ? NeonPalette.magenta
            : NeonPalette.cyan);

    // On the cheap path the scans and pulses go, but the fade and the small
    // scale stay: they are what make the theme feel responsive, and they cost
    // one opacity layer for a sixth of a second.
    final effect = request.allowHeavyEffects ? _effect : _NeonEffect.none;
    final shake = _effect == _NeonEffect.glitch;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      child: request.child,
      builder: (context, v, child) {
        if (v >= 1.0) return child!;

        final t = v.clamp(0.0, 1.0);

        Widget content = child!;

        final overlay = _overlayFor(effect, t, accent);
        if (overlay != null) {
          content = Stack(
            children: [
              content,
              Positioned.fill(child: IgnorePointer(child: overlay)),
            ],
          );
        }

        // A short, tight shudder for a wrong answer. Three pixels, damped to
        // nothing — enough to register, nowhere near a screen shake.
        final dx = shake ? math.sin(t * math.pi * 4) * (1 - t) * 3.0 : 0.0;

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(dx, 0),
            // Snapping up the last 1.5% reads as a HUD element locking into
            // place rather than as something growing.
            child: Transform.scale(
              scale: 0.985 + 0.015 * t,
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget? _overlayFor(_NeonEffect effect, double t, Color accent) {
    switch (effect) {
      case _NeonEffect.none:
        return null;

      case _NeonEffect.pulse:
        // A flash that expands outward and fades: bright at the start,
        // nothing by the end.
        final strength = (1 - t) * 0.30;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.35 + t * 1.1,
              colors: [
                accent.withOpacity(strength),
                accent.withOpacity(strength * 0.3),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        );

      case _NeonEffect.glitch:
        // A brief magenta wash across the whole panel, gone almost at once.
        final strength = math.max(0.0, (1 - t * 2.2)) * 0.26;
        if (strength <= 0) return null;
        return ColoredBox(color: accent.withOpacity(strength));

      case _NeonEffect.verticalScan:
        // A bright line sweeping top to bottom, as if the panel were being
        // drawn by a beam.
        return _scanBand(t, accent, vertical: true);

      case _NeonEffect.horizontalScan:
        return _scanBand(t, accent, vertical: false);
    }
  }

  /// A narrow band of light travelling across the panel. Fades out over the
  /// last third so it never lingers on top of text.
  Widget _scanBand(double t, Color accent, {required bool vertical}) {
    final strength = (1 - math.pow(t, 2).toDouble()) * 0.28;
    if (strength <= 0.001) return const SizedBox.shrink();

    // Travels from just before the panel to just past it.
    final pos = -1.4 + t * 2.8;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: vertical ? Alignment(0, pos - 0.35) : Alignment(pos - 0.35, 0),
          end: vertical ? Alignment(0, pos + 0.35) : Alignment(pos + 0.35, 0),
          colors: [
            Colors.transparent,
            accent.withOpacity(strength),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

enum _NeonEffect { none, pulse, glitch, verticalScan, horizontalScan }

/// Tokyo Neon's progress fill: a cyan-to-purple bar with a bright crest that
/// only exists while the value is actually moving.
class NeonProgressFill extends StatelessWidget {
  final ProgressFillRequest request;

  const NeonProgressFill({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final c = request.color;
    final isAccent = c == NeonPalette.cyan;

    // Semantic colours (a red bar, a green bar) keep their own hue; only the
    // neutral accent bar gets the cyan-to-purple ramp.
    final end = isAccent ? NeonPalette.purple : c;

    if (!request.animating || !request.allowHeavyEffects) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [c, end],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            c,
            end,
            // The leading edge runs hot while the bar is filling.
            Color.alphaBlend(Colors.white.withOpacity(0.75), end),
          ],
          stops: const [0.0, 0.8, 1.0],
        ),
      ),
    );
  }
}

/// The page transition: a fast HUD scan.
///
/// The incoming screen slides a short distance and fades, while a single thin
/// cyan line crosses the viewport. It runs for 160ms — a transition sits
/// between the tap and the thing the user asked for, so anything longer reads
/// as lag rather than as style.
class NeonPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const NeonPageTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Stack(
      children: [
        FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
        // The sweep. AnimatedBuilder with no child of its own, so it rebuilds
        // one DecoratedBox per frame and nothing else; it disappears from the
        // tree the moment the transition ends.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = animation.value;
                if (t <= 0.0 || t >= 1.0) return const SizedBox.shrink();
                final strength = math.sin(t * math.pi) * 0.5;
                final pos = -1.2 + t * 2.4;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(pos - 0.12, 0),
                      end: Alignment(pos + 0.12, 0),
                      colors: [
                        Colors.transparent,
                        NeonPalette.cyan.withOpacity(strength),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

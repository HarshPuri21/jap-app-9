import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import 'glass_tokens.dart';

/// The Glass backdrop.
///
/// Two jobs, and it must do both without ever touching the app's settings
/// code -- it only receives a [BackgroundRequest]:
///
///   * When the user is on "app default", paint the theme's own signature
///     backdrop: a deep indigo-to-slate wash with two soft light pools, so
///     there is something worth seeing *through* the glass.
///   * When the user has chosen a photo or a colour, put that underneath
///     instead, apply the dimness they picked, and then add the theme's own
///     readability treatment on top.
///
/// Every layer here is static: no animation, no blur, no rebuilds. It costs a
/// couple of gradient fills per frame, which is what lets the panes above it
/// stay thin and translucent without ever compromising contrast.
class GlassBackground extends StatelessWidget {
  final BackgroundRequest request;
  final Widget child;

  const GlassBackground({
    super.key,
    required this.request,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: request.userBackground ?? const _DefaultBackdrop(),
        ),
        // The user's own dimness control, applied exactly as before.
        if (request.hasUserBackground)
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withOpacity(request.userDimOpacity),
            ),
          ),
        // Ambient wash: a cool accent glow top-left, an ink pool bottom-right.
        // Never opaque, so the user's wallpaper still reads through.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GlassPalette.accent.withOpacity(0.10),
                  Colors.transparent,
                  GlassPalette.ink.withOpacity(0.22),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // Vignette: slightly darker edges keep floating panes visually
        // separated from the frame of the screen.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.24),
                ],
                stops: const [0.62, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DefaultBackdrop extends StatelessWidget {
  const _DefaultBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF162138),
                Color(0xFF0F172A),
                Color(0xFF080D18),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.75, -0.85),
              radius: 1.0,
              colors: [
                GlassPalette.accent.withOpacity(0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.95, 0.75),
              radius: 0.9,
              colors: [
                const Color(0xFF6366F1).withOpacity(0.16),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

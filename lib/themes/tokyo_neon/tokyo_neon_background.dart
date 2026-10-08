import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import 'tokyo_neon_tokens.dart';

/// The Tokyo Neon backdrop.
///
/// The user still owns what is behind the UI. This widget only receives a
/// [BackgroundRequest] and follows the same priority every theme does:
///
///   user-selected background -> the theme's readability treatment
///
/// and only when there is no user background:
///
///   the theme's own procedural backdrop
///
/// No image assets ship with this theme. The default backdrop is a handful of
/// gradients plus one painter for the grid and scanlines — all of it static,
/// none of it animated, the whole thing behind a [RepaintBoundary] so it is
/// rasterised once and then costs nothing per frame. An animated background
/// is the single easiest way to lose a steady 60 FPS on a mid-range phone,
/// and it is the least valuable place to spend the budget.
class TokyoNeonBackground extends StatelessWidget {
  final BackgroundRequest request;
  final bool effectsEnabled;
  final Widget child;

  const TokyoNeonBackground({
    super.key,
    required this.request,
    required this.effectsEnabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: request.userBackground ??
              _NeonBackdrop(effectsEnabled: effectsEnabled),
        ),

        // The user's own dimness control, applied exactly as they set it.
        if (request.hasUserBackground)
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withOpacity(request.userDimOpacity),
            ),
          ),

        // Readability treatment. Over a photo this is what keeps white text
        // and thin cyan rules legible; the grid and scanlines are dropped
        // here on purpose, because laying a pattern over someone's own
        // wallpaper is noise, not theming.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NeonPalette.cyan.withOpacity(0.07),
                  NeonPalette.voidBlack.withOpacity(
                    request.hasUserBackground ? 0.30 : 0.10,
                  ),
                  NeonPalette.purple.withOpacity(0.10),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Vignette: darker edges, so glowing panels read as lit objects
        // against the frame rather than washing into it.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [
                  Colors.transparent,
                  NeonPalette.voidBlack.withOpacity(0.55),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),

        child,
      ],
    );
  }
}

/// The theme's signature backdrop, used when the user is on "app default".
class _NeonBackdrop extends StatelessWidget {
  final bool effectsEnabled;

  const _NeonBackdrop({required this.effectsEnabled});

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
                NeonPalette.navy,
                NeonPalette.voidBlack,
                NeonPalette.indigo,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Cyan pool, high left — the city's light source.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.9),
              radius: 1.05,
              colors: [
                NeonPalette.cyan.withOpacity(0.20),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Purple pool, low right.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.95, 0.85),
              radius: 0.95,
              colors: [
                NeonPalette.purple.withOpacity(0.18),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // A faint magenta bloom along the bottom edge — the hot pink of the
        // palette, used at the one place it can't compete with content.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.center,
              colors: [
                NeonPalette.magenta.withOpacity(0.10),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Grid and scanlines. Painted once; skipped entirely on the cheap
        // path, where the gradients above already carry the theme.
        if (effectsEnabled)
          const CustomPaint(painter: _GridAndScanlinesPainter()),
      ],
    );
  }
}

/// A very faint perspective-free grid with even fainter scanlines over it.
///
/// Both are drawn at opacities low enough that they read as texture rather
/// than pattern — at 0.035 and 0.022 they are invisible against text and
/// visible against flat dark areas, which is the whole intent.
class _GridAndScanlinesPainter extends CustomPainter {
  const _GridAndScanlinesPainter();

  static const double _gridStep = 46;
  static const double _scanStep = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final grid = Paint()
      ..color = NeonPalette.cyan.withOpacity(0.035)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += _gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final scan = Paint()
      ..color = NeonPalette.voidBlack.withOpacity(0.22)
      ..strokeWidth = 1;

    for (double y = 0; y <= size.height; y += _scanStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }
  }

  // Nothing here depends on state, so this never repaints after the first
  // layout at a given size.
  @override
  bool shouldRepaint(_GridAndScanlinesPainter oldDelegate) => false;
}

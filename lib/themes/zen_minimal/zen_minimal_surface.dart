import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_tokens.dart';
import 'zen_minimal_tokens.dart';

/// Paints one Zen Minimal surface: a sheet of washi paper.
///
/// Deliberately the opposite of Glass -- opaque, flat, hairline-ruled,
/// almost no shadow. It is also the cheapest possible implementation of the
/// surface contract (no blur, no clip paths, one DecoratedBox), which makes
/// this theme the comfortable choice on low-end hardware.
class ZenMinimalSurface extends StatelessWidget {
  final SurfaceRequest request;

  const ZenMinimalSurface({super.key, required this.request});

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

    // Depth is expressed by how bright the paper is and how firm its rule
    // is, rather than by blur or elevation.
    Color paper = _byLevel(
      ZenPalette.paperSunk,
      ZenPalette.paper,
      ZenPalette.paperRaised,
    );
    var ruleOpacity = _byLevel(0.28, 0.42, 0.60);
    var ruleWidth = _byLevel(1.0, 1.0, 1.2);

    final tint = r.tint;
    if (tint != null) {
      paper = Color.alphaBlend(
        tint.withOpacity(0.14 * r.tintStrength),
        paper,
      );
    }

    if (r.selected) {
      ruleOpacity = (ruleOpacity + 0.3).clamp(0.0, 1.0);
      ruleWidth = 1.6;
    }

    // Pressing sinks the sheet slightly into the page.
    if (r.pressAmount > 0) {
      paper = Color.alphaBlend(ZenPalette.ink.withOpacity(0.05), paper);
    }

    final ruleColor =
        (tint ?? ZenPalette.ink).withOpacity(ruleOpacity.clamp(0.0, 1.0));

    Widget pane = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: r.width,
      height: r.height,
      padding: r.padding,
      decoration: BoxDecoration(
        color: paper,
        borderRadius: r.borderRadius,
        border: Border.all(color: ruleColor, width: ruleWidth),
        boxShadow: (r.showShadow && r.level == SurfaceLevel.elevated)
            ? [
                BoxShadow(
                  color: ZenPalette.ink.withOpacity(0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: r.child,
    );

    if (!r.enabled) {
      pane = Opacity(opacity: 0.5, child: pane);
    }
    return pane;
  }
}

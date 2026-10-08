import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import 'zen_minimal_tokens.dart';

/// The Zen Minimal backdrop: a quiet warm paper field.
///
/// When the user has picked their own wallpaper it stays visible, but a warm
/// paper veil is laid over it afterwards. A light theme needs its backdrop to
/// stay light or the ink-on-paper text loses contrast, so this veil is the
/// theme's readability treatment -- the same role the vignette plays in
/// Glass.
class ZenMinimalBackground extends StatelessWidget {
  final BackgroundRequest request;
  final Widget child;

  const ZenMinimalBackground({
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
          child: request.userBackground ?? const _PaperField(),
        ),
        if (request.hasUserBackground) ...[
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withOpacity(request.userDimOpacity),
            ),
          ),
          IgnorePointer(
            child: ColoredBox(color: ZenPalette.paperBase.withOpacity(0.62)),
          ),
        ],
        child,
      ],
    );
  }
}

class _PaperField extends StatelessWidget {
  const _PaperField();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F4EE), Color(0xFFEDE8DF)],
        ),
      ),
    );
  }
}

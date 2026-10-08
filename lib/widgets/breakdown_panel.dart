import 'package:flutter/material.dart';

import '../models/sentence.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import 'themed/themed_surface.dart';

/// Word-by-word explanation of a sentence.
///
/// The panel is themed; the Japanese inside it is always full-opacity study
/// text at a comfortable size. Decoration goes *around* the lesson content,
/// never in front of it.
class BreakdownPanel extends StatelessWidget {
  final List<BreakdownChunk> chunks;
  const BreakdownPanel({super.key, required this.chunks});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      padding: EdgeInsets.all(t.spacing.md),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BREAKDOWN', style: t.text.overline),
          SizedBox(height: t.spacing.sm),
          ...chunks.map((c) => _row(context, c)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, BreakdownChunk c) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(c.chunk, style: t.text.jp(18, weight: FontWeight.w700)),
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.reading != null && c.reading!.isNotEmpty)
                  Text(
                    c.reading!,
                    style: t.text.jp(12.5, color: t.colors.textSecondary),
                  ),
                if (c.meaning != null && c.meaning!.isNotEmpty)
                  Text(c.meaning!, style: t.text.body),
                if (c.note != null && c.note!.isNotEmpty)
                  Text(
                    c.note!,
                    style: t.text.secondary.copyWith(
                      color: t.colors.accent,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

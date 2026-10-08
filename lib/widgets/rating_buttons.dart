import 'package:flutter/material.dart';

import '../models/item_progress.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import 'themed/themed_surface.dart';

/// The four SRS rating buttons.
///
/// The ratings, the interval previews and the `enabled` guard against
/// double-taps are application logic and are untouched; only the presentation
/// is delegated to the theme.
class RatingButtons extends StatelessWidget {
  final ItemProgress previewFrom;
  final ValueChanged<Rating> onRate;
  final bool enabled;

  const RatingButtons({
    super.key,
    required this.previewFrom,
    required this.onRate,
    this.enabled = true,
  });

  String _formatDays(int days) => days >= 30
      ? '${(days / 30).round()}mo'
      : (days == 1 ? '1d' : '${days}d');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // Rating-to-colour is a presentation decision, so it reads from tokens
    // and changes with the theme.
    final specs = <(Rating, String, Color)>[
      (Rating.again, 'Again', t.colors.bad),
      (Rating.hard, 'Hard', t.colors.warn),
      (Rating.good, 'Good', t.colors.good),
      (Rating.easy, 'Easy', t.colors.accent),
    ];

    return Row(
      children: specs.map((spec) {
        final (rating, label, color) = spec;
        final preview = previewFrom.previewIntervalDays(rating);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ThemedCard(
              onTap: enabled ? () => onRate(rating) : null,
              enabled: enabled,
              level: SurfaceLevel.standard,
              radius: t.radii.sm,
              allowHeavyEffects: false,
              tint: color,
              tintStrength: 0.85,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              semanticLabel: '$label, next in ${_formatDays(preview)}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDays(preview),
                    maxLines: 1,
                    style: t.text.caption.copyWith(
                      color: color.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

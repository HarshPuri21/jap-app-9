import 'package:flutter/material.dart';

import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import 'themed/themed_controls.dart';
import 'themed/themed_surface.dart';

/// A compact square-ish "how am I doing" entry point, meant to sit two-up
/// at the top of the home screen (see [DashboardCardRow]). Visually it's
/// built from the same pieces [ModeCard] uses -- [ThemedCard],
/// [ThemedIconPlate], [ThemedProgressBar] -- just arranged in a column
/// instead of a row, so it reads as a small stat tile rather than a list
/// entry.
class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;

  /// The one headline number/phrase ("12 day streak", "24 reviews due").
  final String mainStat;

  /// A small line under the progress bar ("8 / 10 goal", "3 done today").
  /// Optional -- omitted rather than padded with a stat that isn't real.
  final String? subStat;

  /// 0..1, shown as a hairline bar. Optional -- a card with nothing
  /// meaningful to show progress toward (e.g. a brand new install) just
  /// omits the bar rather than drawing an empty or fake one.
  final double? progress;

  final Color accentColor;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.mainStat,
    required this.accentColor,
    required this.onTap,
    this.subStat,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ThemedCard(
      onTap: onTap,
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      tint: accentColor,
      tintStrength: 0.55,
      width: double.infinity,
      semanticLabel: subStat != null
          ? '$title. $mainStat. $subStat'
          : '$title. $mainStat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemedIconPlate(
            icon: icon,
            color: accentColor,
            size: 40,
            iconSize: 20,
          ),
          SizedBox(height: t.spacing.sm),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.overline.copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: 3),
          Text(
            mainStat,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.text.cardTitle.copyWith(fontSize: 15),
          ),
          if (progress != null) ...[
            SizedBox(height: t.spacing.xs),
            ThemedProgressBar(value: progress!, color: accentColor, height: 5),
          ],
          if (subStat != null) ...[
            const SizedBox(height: 4),
            Text(
              subStat!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.text.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays two [DashboardCard]s side by side, equal width and equal height
/// (the taller of the two decides the row's height for both), with a gap
/// that scales with the theme's spacing scale rather than a fixed pixel gap.
class DashboardCardRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const DashboardCardRow({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two-up is the normal dashboard presentation. On genuinely narrow
        // layouts (e.g. a 320 px device after screen gutters) or when the
        // user has substantially enlarged system text, stack the cards so
        // neither headline has to become a tiny ellipsis.
        final stackCards = constraints.maxWidth < 300 || textScale > 1.35;

        if (stackCards) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              SizedBox(height: t.spacing.sm),
              right,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              SizedBox(width: t.spacing.sm),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }
}

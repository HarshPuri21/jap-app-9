import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_progress.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_surface.dart';

class ReviewResultsScreen extends StatelessWidget {
  final Map<Rating, int> tally;

  const ReviewResultsScreen({super.key, required this.tally});

  int get _total => tally.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = _total;
    final again = tally[Rating.again] ?? 0;
    final hard = tally[Rating.hard] ?? 0;
    final good = tally[Rating.good] ?? 0;
    final easy = tally[Rating.easy] ?? 0;
    final smooth = total == 0 ? 0 : (100 * (good + easy) / total).round();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: t.spacing.xl,
                vertical: t.spacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ThemedIconPlate(
                    icon: Icons.check_rounded,
                    color: t.colors.good,
                    size: 64,
                    iconSize: 32,
                  ),
                  SizedBox(height: t.spacing.md),
                  Text(
                    'Review complete — $total item${total == 1 ? '' : 's'}',
                    textAlign: TextAlign.center,
                    style: t.text.display.copyWith(fontSize: 21),
                  ),
                  if (total > 0) ...[
                    SizedBox(height: t.spacing.xxs),
                    Text(
                      '$smooth% remembered smoothly',
                      style: t.text.secondary,
                    ),
                  ],
                  SizedBox(height: t.spacing.lg),
                  ThemedSurface(
                    level: SurfaceLevel.elevated,
                    radius: t.radii.lg,
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spacing.sm,
                      vertical: t.spacing.lg,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat(context, 'Again', again, t.colors.bad),
                        _stat(context, 'Hard', hard, t.colors.warn),
                        _stat(context, 'Good', good, t.colors.good),
                        _stat(context, 'Easy', easy, t.colors.accent),
                      ],
                    ),
                  ),
                  SizedBox(height: t.spacing.xxl),
                  ThemedButton(
                    label: 'Back to Home',
                    icon: Icons.home_outlined,
                    onPressed: () {
                      context.read<AudioService>().playMenuClick();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value, Color color) {
    final t = context.tokens;
    return Column(
      children: [
        Text(
          '$value',
          style: t.text.title.copyWith(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: t.text.caption),
      ],
    );
  }
}

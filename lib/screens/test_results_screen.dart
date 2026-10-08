import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_surface.dart';

class TestResultsScreen extends StatelessWidget {
  final int score;
  final int total;

  const TestResultsScreen({
    super.key,
    required this.score,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = total == 0 ? 0 : (100 * score / total).round();
    final (emoji, message) = _messageFor(pct);

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
                  Text(emoji, style: const TextStyle(fontSize: 58)),
                  SizedBox(height: t.spacing.md),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: t.text.display.copyWith(fontSize: 22),
                  ),
                  SizedBox(height: t.spacing.xl),
                  ThemedSurface(
                    level: SurfaceLevel.elevated,
                    radius: t.radii.lg,
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spacing.xl,
                      vertical: t.spacing.lg,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$score / $total',
                          style: t.text.display.copyWith(
                            color: t.colors.accent,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: t.spacing.xs),
                        Text('$pct% correct', style: t.text.secondary),
                        SizedBox(height: t.spacing.sm),
                        SizedBox(
                          width: 180,
                          child:
                              ThemedProgressBar(value: pct / 100, height: 6),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: t.spacing.xxl),
                  ThemedButton(
                    label: 'Try Another Test',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      context.read<AudioService>().playMenuClick();
                      Navigator.of(context).pop();
                    },
                  ),
                  SizedBox(height: t.spacing.sm),
                  ThemedButton(
                    label: 'Back to Home',
                    variant: ThemedButtonVariant.secondary,
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

  (String, String) _messageFor(int pct) {
    if (pct >= 90) return ('🎉', 'Excellent work!');
    if (pct >= 70) return ('😊', 'Great job!');
    if (pct >= 50) return ('🙂', 'Good effort — keep practicing!');
    return ('📚', 'Keep at it — practice makes perfect!');
  }
}

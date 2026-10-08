import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/radical_entry.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/difficulty_badge.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

class RadicalDetailScreen extends StatelessWidget {
  final RadicalEntry radical;
  const RadicalDetailScreen({super.key, required this.radical});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The character gets the forward surface and all the
                      // room it needs -- it is the lesson, so it also gets
                      // the theme's radical reveal.
                      ThemedReveal(
                        moment: ThemeMoment.radicalReveal,
                        child: ThemedSurface(
                        level: SurfaceLevel.elevated,
                        radius: t.radii.lg,
                        padding: EdgeInsets.all(t.spacing.lg),
                        child: Column(
                          children: [
                            DifficultyBadge(difficulty: radical.difficulty),
                            SizedBox(height: t.spacing.md),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                radical.char,
                                style:
                                    t.text.jp(96, weight: FontWeight.w700),
                              ),
                            ),
                            SizedBox(height: t.spacing.md),
                            Text(
                              radical.meaning,
                              textAlign: TextAlign.center,
                              style: t.text.display.copyWith(fontSize: 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              radical.name,
                              textAlign: TextAlign.center,
                              style: t.text
                                  .jp(16, color: t.colors.textSecondary),
                            ),
                          ],
                          ),
                        ),
                      ),
                      SizedBox(height: t.spacing.md),
                      _infoCard(
                        context,
                        title: 'USAGE',
                        child: Text(radical.usage, style: t.text.body),
                      ),
                      if (radical.examples.isNotEmpty) ...[
                        SizedBox(height: t.spacing.sm),
                        _infoCard(
                          context,
                          title:
                              'EXAMPLE KANJI (${radical.examples.length})',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: radical.examples
                                .map((ex) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            child: Text(
                                              ex.kanji,
                                              style: t.text.jp(26,
                                                  weight: FontWeight.w700),
                                            ),
                                          ),
                                          SizedBox(width: t.spacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ex.reading,
                                                  style: t.text.jp(13,
                                                      color: t.colors
                                                          .textSecondary),
                                                ),
                                                Text(ex.meaning,
                                                    style: t.text.body),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.text.overline),
          SizedBox(height: t.spacing.xs),
          child,
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Radical Detail',
      subtitle: '部首',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}

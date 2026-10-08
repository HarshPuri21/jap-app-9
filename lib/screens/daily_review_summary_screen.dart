import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vocab_entry.dart';
import '../models/kanji_entry.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'daily_review_screen.dart';

/// What you see *before* a review session -- what's due, what you've
/// already done today, a breakdown by type, and a "Start Review" button.
///
/// This screen only ever reports on the existing review engine; it doesn't
/// run any reviewing itself. "Start Review" pushes the same
/// [DailyReviewScreen] the app already had, unmodified.
class DailyReviewSummaryScreen extends StatelessWidget {
  const DailyReviewSummaryScreen({super.key});

  void _startReview(BuildContext context) {
    context.read<AudioService>().playMenuClick();
    Navigator.of(context)
        .push(themedRoute(context, (_) => const DailyReviewScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressService>();
    final remaining = progress.todayQueueSize;
    final completedToday = progress.reviewedTodayCount;
    final totalToday = completedToday + remaining;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: remaining == 0
                    ? _caughtUpState(context, progress, completedToday)
                    : _summaryState(
                        context,
                        progress,
                        remaining: remaining,
                        completedToday: completedToday,
                        totalToday: totalToday,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryState(
    BuildContext context,
    ProgressService progress, {
    required int remaining,
    required int completedToday,
    required int totalToday,
  }) {
    final t = context.tokens;
    final weakest = progress.weakestItemIds(count: 3);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        t.spacing.gutter,
        t.spacing.xs,
        t.spacing.gutter,
        t.spacing.xl,
      ),
      children: [
        ThemedSurface(
          level: SurfaceLevel.elevated,
          radius: t.radii.lg,
          padding: EdgeInsets.symmetric(
            horizontal: t.spacing.sm,
            vertical: t.spacing.lg,
          ),
          tint: t.colors.accent,
          tintStrength: 0.5,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(context, 'Remaining', remaining, t.colors.accent),
                  _stat(context, 'Reviewed', completedToday, t.colors.good),
                  _stat(
                    context,
                    'New today',
                    progress.newItemsIntroducedTodayCount,
                    t.colors.warn,
                  ),
                ],
              ),
              SizedBox(height: t.spacing.md),
              ThemedProgressBar(
                value: totalToday == 0 ? 0.0 : completedToday / totalToday,
                color: t.colors.good,
              ),
            ],
          ),
        ),
        SizedBox(height: t.spacing.lg),
        const ThemedSectionLabel("What's Remaining"),
        ThemedSurface(
          level: SurfaceLevel.standard,
          radius: t.radii.lg,
          padding: EdgeInsets.all(t.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _typeRow(
                context,
                'Vocabulary reviews',
                progress.dueCountByPrefix('vocab:'),
              ),
              SizedBox(height: t.spacing.sm),
              _typeRow(
                context,
                'Kanji reviews',
                progress.dueCountByPrefix('kanji:'),
              ),
              SizedBox(height: t.spacing.sm),
              _allowanceRow(context, progress),
              SizedBox(height: t.spacing.xs),
              Text(
                'New items are drawn from unseen vocabulary and kanji. '
                "Sentences, Radicals and Kana aren't part of spaced review "
                'yet — practice them anytime from Home.',
                style: t.text.caption,
              ),
            ],
          ),
        ),
        if (weakest.isNotEmpty) ...[
          SizedBox(height: t.spacing.lg),
          const ThemedSectionLabel('Needs Extra Practice'),
          ThemedSurface(
            level: SurfaceLevel.standard,
            radius: t.radii.lg,
            padding: EdgeInsets.all(t.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in weakest) ...[
                  _weakRow(context, progress, entry.key, entry.value),
                  if (entry.key != weakest.last.key)
                    SizedBox(height: t.spacing.sm),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: t.spacing.xl),
        ThemedButton(
          label: 'Start Review',
          icon: Icons.bolt_rounded,
          onPressed: () => _startReview(context),
        ),
      ],
    );
  }

  Widget _caughtUpState(
    BuildContext context,
    ProgressService progress,
    int completedToday,
  ) {
    final t = context.tokens;
    final reachedNewLimit = progress.newAvailableCount > 0 &&
        progress.newItemAllowanceRemaining == 0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.spacing.xl),
        child: ThemedSurface(
          level: SurfaceLevel.elevated,
          radius: t.radii.xl,
          padding: EdgeInsets.all(t.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemedIconPlate(
                icon: Icons.check_rounded,
                color: t.colors.good,
                size: 60,
                iconSize: 30,
              ),
              SizedBox(height: t.spacing.md),
              Text(
                "You're all caught up!",
                textAlign: TextAlign.center,
                style: t.text.title,
              ),
              SizedBox(height: t.spacing.xs),
              Text(
                reachedNewLimit
                    ? 'You introduced $kNewItemsPerDay new items today and '
                        'have no scheduled reviews due. Come back tomorrow '
                        'for another new batch.'
                    : completedToday > 0
                    ? 'You reviewed $completedToday item'
                        '${completedToday == 1 ? '' : 's'} today. Check back '
                        'later, or use Flashcards for extra practice.'
                    : 'No reviews due right now. Check back later, or '
                        'use Flashcards for extra practice.',
                textAlign: TextAlign.center,
                style: t.text.secondary,
              ),
              SizedBox(height: t.spacing.lg),
              ThemedButton(
                label: 'Back to Home',
                variant: ThemedButtonVariant.secondary,
                onPressed: () {
                  context.read<AudioService>().playLessonClick();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeRow(BuildContext context, String label, int due) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(child: Text(label, style: t.text.body)),
        Text('$due due', style: t.text.caption.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _allowanceRow(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final available = progress.newItemsAvailableToday;
    final introduced = progress.newItemsIntroducedTodayCount;
    return Row(
      children: [
        Expanded(child: Text('New items', style: t.text.body)),
        Text(
          '$available available · $introduced/$kNewItemsPerDay introduced',
          style: t.text.caption.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _weakRow(
    BuildContext context,
    ProgressService progress,
    String itemId,
    int lapses,
  ) {
    final t = context.tokens;
    final resolved = progress.resolveItem(itemId);
    String display = itemId;
    if (resolved is VocabEntry) display = resolved.jp;
    if (resolved is KanjiEntry) display = resolved.kanji;
    return Row(
      children: [
        Expanded(
          child: Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.jp(15),
          ),
        ),
        Text(
          '$lapses miss${lapses == 1 ? '' : 'es'}',
          style: t.text.caption.copyWith(color: t.colors.warn),
        ),
      ],
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

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Daily Review',
      subtitle: '復習',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}

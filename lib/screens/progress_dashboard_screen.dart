import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vocab_entry.dart';
import '../models/kanji_entry.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import '../services/progress_service.dart';
import '../services/activity_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

/// Display names for the quiz categories SettingsService tracks per-mode
/// accuracy for (see the `category:` argument at each quiz screen's
/// `recordAnswer` call).
const Map<QuizCategory, String> _kCategoryLabels = {
  QuizCategory.sentences: 'Sentences',
  QuizCategory.kanji: 'Kanji Quiz',
  QuizCategory.radicals: 'Radicals',
  QuizCategory.kana: 'Kana Quiz',
  QuizCategory.test: 'Mixed Test',
};

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
  }

  @override
  void dispose() {
    // Not every path back to Home goes through a pop the way lesson screens
    // do (this screen has no "finish" action) -- ensureMenuMusicPlaying is
    // safe to call unconditionally, so cover it here instead of on every
    // possible exit.
    context.read<AudioService>().ensureMenuMusicPlaying();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final activity = context.watch<ActivityService>();
    final settings = context.watch<SettingsService>();
    final progress = context.watch<ProgressService>();
    final ds = DataService.instance;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  children: [
                    _streakSection(context, activity),
                    SizedBox(height: t.spacing.md),
                    _goalSection(context, activity),
                    SizedBox(height: t.spacing.md),
                    _weeklySection(context, activity),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Overall Accuracy'),
                    _accuracySection(context, settings),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Learning Coverage'),
                    _coverageSection(context, progress, ds),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Accuracy by Mode'),
                    _categorySection(context, settings),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Weak Items'),
                    _weakItemsSection(context, progress),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Recent Activity'),
                    _recentActivitySection(context, progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Streak -------------------------------------------------------------

  Widget _streakSection(BuildContext context, ActivityService activity) {
    final t = context.tokens;
    final streak = activity.currentStreak;
    return ThemedSurface(
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      tint: t.colors.warn,
      tintStrength: 0.5,
      child: Row(
        children: [
          ThemedIconPlate(
            icon: Icons.local_fire_department,
            color: t.colors.warn,
            size: 48,
            iconSize: 24,
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  streak == 0
                      ? 'No active streak'
                      : '$streak day streak${streak == 1 ? '' : 's'}',
                  style: t.text.cardTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  'Longest: ${activity.longestStreak} day'
                  '${activity.longestStreak == 1 ? '' : 's'}',
                  style: t.text.secondary.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Daily goal -----------------------------------------------------

  Widget _goalSection(BuildContext context, ActivityService activity) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Today's goal", style: t.text.overline),
              ),
              _goalStepper(context, activity),
            ],
          ),
          SizedBox(height: t.spacing.sm),
          Text(
            '${activity.todayCount} / ${activity.dailyGoal}',
            style: t.text.display.copyWith(fontSize: 22),
          ),
          SizedBox(height: t.spacing.xs),
          ThemedProgressBar(value: activity.goalProgress, color: t.colors.good),
        ],
      ),
    );
  }

  Widget _goalStepper(BuildContext context, ActivityService activity) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(context, Icons.remove_rounded, () {
          if (activity.dailyGoal > 1) {
            context.read<AudioService>().playLessonClick();
            activity.setDailyGoal(activity.dailyGoal - 1);
          }
        }),
        SizedBox(width: t.spacing.xxs),
        _stepButton(context, Icons.add_rounded, () {
          context.read<AudioService>().playLessonClick();
          activity.setDailyGoal(activity.dailyGoal + 1);
        }),
      ],
    );
  }

  Widget _stepButton(BuildContext context, IconData icon, VoidCallback onTap) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: t.radii.sm,
      allowHeavyEffects: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radii.sm),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: t.colors.textSecondary),
        ),
      ),
    );
  }

  // -- Weekly activity ------------------------------------------------

  Widget _weeklySection(BuildContext context, ActivityService activity) {
    final t = context.tokens;
    final days = activity.lastNDays(7);
    final maxVal = days.fold<int>(1, (m, v) => v > m ? v : m);
    final labels = List<String>.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return names[(d.weekday - 1) % 7];
    });

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This week', style: t.text.overline),
          SizedBox(height: t.spacing.sm),
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final v = days[i];
                final h = v == 0 ? 3.0 : 6.0 + (v / maxVal) * 42.0;
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: t.spacing.xxs / 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          v == 0 ? '' : '$v',
                          style: t.text.caption.copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isToday
                                ? t.colors.accent
                                : t.colors.accent.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(labels[i],
                            style: t.text.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // -- Overall accuracy -------------------------------------------------

  Widget _accuracySection(BuildContext context, SettingsService settings) {
    final t = context.tokens;
    final answered = settings.statsAnsweredTotal;
    final correct = settings.statsCorrectTotal;

    if (answered == 0) {
      return _emptyCard(
        context,
        'No quiz answers yet — accuracy will show up here once you start '
        'practicing.',
      );
    }

    final pct = (100 * correct / answered).round();
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lifetime accuracy', style: t.text.overline),
                SizedBox(height: t.spacing.xs),
                ThemedProgressBar(value: pct / 100),
              ],
            ),
          ),
          SizedBox(width: t.spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: t.text.title.copyWith(
                  color: t.colors.accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('$correct / $answered', style: t.text.caption),
            ],
          ),
        ],
      ),
    );
  }

  // -- SRS coverage -------------------------------------------------------

  Widget _coverageSection(
    BuildContext context,
    ProgressService progress,
    DataService ds,
  ) {
    final t = context.tokens;
    final kanjiStudied = progress.countByPrefix('kanji:');
    final vocabStudied = progress.countByPrefix('vocab:');

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _coverageRow(context, 'Kanji', kanjiStudied, ds.kanjiEntries.length),
          SizedBox(height: t.spacing.sm),
          _coverageRow(context, 'Vocabulary', vocabStudied, ds.vocab.length),
          SizedBox(height: t.spacing.xs),
          Text(
            "Sentences, Radicals and Kana aren't part of spaced review yet "
            '— practice them anytime from Home.',
            style: t.text.caption,
          ),
        ],
      ),
    );
  }

  Widget _coverageRow(
      BuildContext context, String label, int done, int total) {
    final t = context.tokens;
    final frac = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.text.body)),
            Text('$done / $total', style: t.text.caption),
          ],
        ),
        const SizedBox(height: 4),
        ThemedProgressBar(value: frac, height: 5),
      ],
    );
  }

  // -- Per-mode quiz accuracy ----------------------------------------

  Widget _categorySection(BuildContext context, SettingsService settings) {
    final t = context.tokens;
    final stats = settings.categoryStats.entries
        .where((e) => e.value.answered > 0)
        .toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    if (stats.isEmpty) {
      return _emptyCard(
        context,
        "No quiz-mode results yet — each mode's accuracy will appear here "
        'as you practice.',
      );
    }

    // The lowest-accuracy mode with a reasonable sample size, called out as
    // the one place practice would help most.
    final candidates = stats.where((e) => e.value.answered >= 5).toList()
      ..sort((a, b) =>
          (a.value.percent ?? 100).compareTo(b.value.percent ?? 100));
    final weakestKey = candidates.isEmpty ? null : candidates.first.key;

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in stats) ...[
            _categoryRow(context, e.key, e.value,
                isWeakest: e.key == weakestKey),
            if (e.key != stats.last.key) SizedBox(height: t.spacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(
    BuildContext context,
    QuizCategory key,
    CategoryStat stat, {
    required bool isWeakest,
  }) {
    final t = context.tokens;
    final label = _kCategoryLabels[key] ?? key.name;
    final pct = stat.percent ?? 0;
    final color = isWeakest ? t.colors.warn : t.colors.accent;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(label,
                    style: t.text.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (isWeakest) ...[
                SizedBox(width: t.spacing.xxs),
                Icon(Icons.flag_outlined, size: 13, color: t.colors.warn),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 80,
          child: ThemedProgressBar(value: pct / 100, color: color, height: 5),
        ),
        SizedBox(width: t.spacing.xs),
        SizedBox(
          width: 36,
          child: Text(
            '$pct%',
            textAlign: TextAlign.end,
            style: t.text.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // -- Weak items -----------------------------------------------------

  Widget _weakItemsSection(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final weakest = progress.weakestItemIds(count: 5);

    if (weakest.isEmpty) {
      return _emptyCard(
        context,
        'No repeatedly-missed items yet — nice and clean.',
      );
    }

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in weakest) ...[
            _weakItemRow(context, progress, entry.key, entry.value),
            if (entry.key != weakest.last.key) SizedBox(height: t.spacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _weakItemRow(
    BuildContext context,
    ProgressService progress,
    String itemId,
    int lapses,
  ) {
    final t = context.tokens;
    final resolved = progress.resolveItem(itemId);
    final display = _displayFor(resolved) ?? itemId;
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

  // -- Recent activity --------------------------------------------------

  Widget _recentActivitySection(
      BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final recent = progress.recentlyReviewed(count: 5);

    if (recent.isEmpty) {
      return _emptyCard(
        context,
        'Nothing reviewed yet — your recent sessions will show up here.',
      );
    }

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in recent) ...[
            _recentRow(context, progress, entry.key, entry.value.lastReviewed!),
            if (entry.key != recent.last.key) SizedBox(height: t.spacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _recentRow(
    BuildContext context,
    ProgressService progress,
    String itemId,
    DateTime when,
  ) {
    final t = context.tokens;
    final resolved = progress.resolveItem(itemId);
    final display = _displayFor(resolved) ?? itemId;
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
        Text(_timeAgo(when), style: t.text.caption),
      ],
    );
  }

  String? _displayFor(dynamic item) {
    if (item is VocabEntry) return item.jp;
    if (item is KanjiEntry) return item.kanji;
    return null;
  }

  String _timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _emptyCard(BuildContext context, String message) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: t.radii.lg,
      allowHeavyEffects: false,
      padding: EdgeInsets.all(t.spacing.md),
      child: Text(message, style: t.text.secondary),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Progress Dashboard',
      subtitle: '進捗',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}

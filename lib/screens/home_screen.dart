import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/progress_service.dart';
import '../services/activity_service.dart';
import '../services/audio_service.dart';
import '../services/data_service.dart';
import '../services/route_observer.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/mode_card.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_controls.dart';
import 'sentence_mode_screen.dart';
import 'kanji_mode_screen.dart';
import 'flashcard_screen.dart';
import 'test_setup_screen.dart';
import 'settings_screen.dart';
import 'daily_review_summary_screen.dart';
import 'progress_dashboard_screen.dart';
import 'radical_list_screen.dart';
import 'radical_quiz_screen.dart';
import 'kana_mode_screen.dart';
import 'kana_quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  @override
  void initState() {
    super.initState();
    // Covers the very first appearance (app launch) -- subsequent returns
    // from a lesson screen are covered by didPopNext below, since popping
    // back to an already-built screen does not re-run initState.
    context.read<AudioService>().ensureMenuMusicPlaying();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // We're visible again after a pushed screen (a lesson, settings, etc.)
    // was popped off -- resume the menu music if it isn't already playing.
    context.read<AudioService>().ensureMenuMusicPlaying();
  }

  void _openScreen(Widget screen) {
    context.read<AudioService>().playMenuClick();
    Navigator.of(context).push(themedRoute(context, (_) => screen));
  }

  /// Calm, distinguishable hues for the learning modes, derived from the
  /// active theme so they change with it rather than being hard-coded.
  List<Color> _modeHues(ThemeTokens t) => [
        t.colors.accent,
        Color.lerp(t.colors.accent, const Color(0xFF6366F1), 0.55)!,
        t.colors.good,
        Color.lerp(t.colors.accent, t.colors.good, 0.5)!,
        t.colors.warn,
        Color.lerp(t.colors.warn, t.colors.bad, 0.35)!,
        Color.lerp(t.colors.accent, t.colors.warn, 0.5)!,
        Color.lerp(t.colors.good, t.colors.accent, 0.4)!,
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = context.watch<ProgressService>();
    final activity = context.watch<ActivityService>();
    final hues = _modeHues(t);

    final remaining = progress.todayQueueSize;
    final completedToday = progress.reviewedTodayCount;
    final totalToday = completedToday + remaining;
    final hasReviews = remaining > 0;
    final streak = activity.currentStreak;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  children: [
                    const _HomeSectionHeader(
                      title: 'Today',
                      subtitle: 'Keep your momentum and clear what is due.',
                    ),
                    DashboardCardRow(
                      left: DashboardCard(
                        icon: Icons.local_fire_department,
                        title: 'Daily Progress',
                        mainStat: streak == 0
                            ? 'No streak yet'
                            : '$streak day streak${streak == 1 ? '' : 's'}',
                        subStat: '${activity.todayCount} / '
                            '${activity.dailyGoal} goal',
                        progress: activity.goalProgress,
                        accentColor: t.colors.warn,
                        onTap: () =>
                            _openScreen(const ProgressDashboardScreen()),
                      ),
                      right: DashboardCard(
                        icon: Icons.book_outlined,
                        title: 'Daily Review',
                        mainStat: hasReviews
                            ? '$remaining review${remaining == 1 ? '' : 's'} remaining'
                            : 'All caught up',
                        subStat: completedToday > 0
                            ? '$completedToday done · '
                                '${progress.newItemsIntroducedTodayCount}/$kNewItemsPerDay new'
                            : '${progress.newItemsIntroducedTodayCount}/$kNewItemsPerDay new today',
                        progress: totalToday == 0
                            ? null
                            : completedToday / totalToday,
                        accentColor: hasReviews ? t.colors.accent : t.colors.good,
                        onTap: () =>
                            _openScreen(const DailyReviewSummaryScreen()),
                      ),
                    ),
                    SizedBox(height: t.spacing.xl),
                    const _HomeSectionHeader(
                      title: 'Learn',
                      subtitle: 'Build Japanese from foundations to JLPT N1.',
                    ),
                    ModeCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Learn Sentences',
                      subtitle:
                          '${DataService.instance.sentences.length} examples · grammar forms · JLPT N5 → N1',
                      accentColor: hues[0],
                      onTap: () => _openScreen(const SentenceModeScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.brush_outlined,
                      title: 'Learn Kanji',
                      subtitle:
                          '${DataService.instance.kanjiEntries.length} kanji · meanings & readings · JLPT N5 → N1',
                      accentColor: hues[1],
                      onTap: () => _openScreen(const KanjiModeScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.translate,
                      title: 'Learn Kana',
                      subtitle:
                          '${DataService.instance.kana.length} kana · hiragana & katakana · staged learning',
                      accentColor: hues[6],
                      onTap: () => _openScreen(const KanaModeScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.category_outlined,
                      title: 'Radicals',
                      subtitle:
                          '${DataService.instance.radicals.length} radicals · browse meanings & forms',
                      accentColor: hues[3],
                      onTap: () => _openScreen(const RadicalListScreen()),
                    ),
                    SizedBox(height: t.spacing.xl),
                    const _HomeSectionHeader(
                      title: 'Practice',
                      subtitle: 'Recall, review, and test what you know.',
                    ),
                    ModeCard(
                      icon: Icons.style_outlined,
                      title: 'Flashcards',
                      subtitle: 'Vocabulary & kanji · quick recall practice',
                      accentColor: hues[2],
                      onTap: () => _openScreen(const FlashcardScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.quiz_outlined,
                      title: 'Take a Test',
                      subtitle: 'Custom quiz · choose content and length',
                      accentColor: hues[5],
                      onTap: () => _openScreen(const TestSetupScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.spellcheck,
                      title: 'Kana Quiz',
                      subtitle: 'Kana ↔ romaji · recognition practice',
                      accentColor: hues[7],
                      onTap: () => _openScreen(const KanaQuizScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.extension_outlined,
                      title: 'Radical Quiz',
                      subtitle: 'Match radicals to their meanings',
                      accentColor: hues[4],
                      onTap: () => _openScreen(const RadicalQuizScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The masthead. Deliberately not a themed bar: on the home screen the
  /// title reads as printed onto the backdrop, with the surfaces beginning
  /// below it -- that contrast is what gives the cards their depth.
  Widget _buildHeader(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.gutter,
        t.spacing.md,
        t.spacing.sm,
        t.spacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '日本語トレーニング',
                  style: t.text
                      .jp(13, color: t.colors.textSecondary)
                      .copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 4),
                Text('Nihongo Trainer', style: t.text.display),
              ],
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Padding(
            padding: EdgeInsets.only(top: 6, right: t.spacing.xs),
            child: ThemedIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onPressed: () => _openScreen(const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small hierarchy cue for the home screen. The main app already has a
/// strong visual language in its cards; this keeps the grouping semantic and
/// lightweight instead of introducing another container style just for home.
class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HomeSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: t.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: t.text.overline),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: t.text.caption.copyWith(color: t.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_progress.dart';
import '../models/vocab_entry.dart';
import '../models/kanji_entry.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';
import '../services/activity_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/rating_buttons.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'review_results_screen.dart';

class DailyReviewScreen extends StatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  State<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends State<DailyReviewScreen> {
  late List<String> _queue;
  int _index = 0;
  bool _flipped = false;
  bool _busy = false; // guards against double-tapping a rating button

  final Map<Rating, int> _tally = {
    Rating.again: 0,
    Rating.hard: 0,
    Rating.good: 0,
    Rating.easy: 0,
  };

  @override
  void initState() {
    super.initState();
    _queue = context.read<ProgressService>().buildDailyQueue();
    context.read<AudioService>().stopMenuMusic();
  }

  String get _currentId => _queue[_index];

  Future<void> _rate(Rating rating) async {
    if (_busy) return; // prevents a double-tap from recording twice
    setState(() => _busy = true);
    context.read<AudioService>().playLessonClick();

    await context.read<ProgressService>().rate(_currentId, rating);
    context.read<ActivityService>().recordActivity();
    _tally[rating] = (_tally[rating] ?? 0) + 1;

    if (!mounted) return;

    if (_index >= _queue.length - 1) {
      context.read<AudioService>().ensureMenuMusicPlaying();
      Navigator.of(context).pushReplacement(
        themedRoute(
          context,
          (_) => ReviewResultsScreen(tally: Map.of(_tally)),
        ),
      );
      return;
    }

    setState(() {
      _index += 1;
      _flipped = false;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_queue.isEmpty) {
      return _buildEmptyState(context);
    }

    final progressService = context.read<ProgressService>();
    final itemId = _currentId;
    final item = progressService.resolveItem(itemId);
    final existingProgress = progressService.progressFor(itemId);
    final previewSource = existingProgress ?? ItemProgress();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
                child: ThemedProgressBar(
                  value: _queue.isEmpty ? 0 : _index / _queue.length,
                ),
              ),
              Expanded(
                child: item == null
                    ? Center(
                        child: Text(
                          'This item is no longer available.',
                          style: t.text.secondary,
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.all(t.spacing.lg),
                        child: GestureDetector(
                          onTap: () {
                            context.read<AudioService>().playLessonClick();
                            setState(() => _flipped = !_flipped);
                          },
                          child: _buildCard(context, item),
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.sm,
                  0,
                  t.spacing.sm,
                  t.spacing.md,
                ),
                child: _flipped
                    ? RatingButtons(
                        previewFrom: previewSource,
                        enabled: !_busy,
                        onRate: _rate,
                      )
                    : Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: t.spacing.xs),
                        child: ThemedButton(
                          label: 'Show Answer',
                          icon: Icons.visibility_outlined,
                          onPressed: () {
                            context.read<AudioService>().playLessonClick();
                            setState(() => _flipped = true);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One stable surface; only the face inside cross-fades on flip.
  Widget _buildCard(BuildContext context, dynamic item) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.elevated,
      radius: t.radii.xl,
      padding: EdgeInsets.all(t.spacing.xl),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            duration: t.motion.base,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey('$_index-$_flipped'),
              child: item is VocabEntry
                  ? _vocabFace(context, item)
                  : _kanjiFace(context, item as KanjiEntry),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vocabFace(BuildContext context, VocabEntry v) {
    final t = context.tokens;
    if (!_flipped) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              v.jp,
              textAlign: TextAlign.center,
              style: t.text.jp(52, weight: FontWeight.w700),
            ),
          ),
          SizedBox(height: t.spacing.sm),
          Text(
            v.kana,
            textAlign: TextAlign.center,
            style: t.text.jp(20, color: t.colors.textSecondary),
          ),
          SizedBox(height: t.spacing.lg),
          Text('Tap to reveal meaning', style: t.text.caption),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v.jp,
          textAlign: TextAlign.center,
          style: t.text.jp(30, weight: FontWeight.w700),
        ),
        SizedBox(height: t.spacing.sm),
        Text(
          v.meaning,
          textAlign: TextAlign.center,
          style: t.text.display.copyWith(
            color: t.colors.accent,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        SizedBox(height: t.spacing.xxs),
        Text(v.romaji, style: t.text.secondary),
      ],
    );
  }

  Widget _kanjiFace(BuildContext context, KanjiEntry k) {
    final t = context.tokens;
    if (!_flipped) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(k.kanji, style: t.text.jp(92, weight: FontWeight.w700)),
          ),
          SizedBox(height: t.spacing.lg),
          Text('Tap to reveal meaning', style: t.text.caption),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k.kanji, style: t.text.jp(56, weight: FontWeight.w700)),
        SizedBox(height: t.spacing.sm),
        Text(
          k.meaning,
          textAlign: TextAlign.center,
          style: t.text.display.copyWith(
            color: t.colors.accent,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        SizedBox(height: t.spacing.xxs),
        if (k.onyomi.isNotEmpty)
          Text(
            'On: ${k.onyomi.join("、")}',
            textAlign: TextAlign.center,
            style: t.text.jp(15),
          ),
        if (k.kunyomi.isNotEmpty)
          Text(
            'Kun: ${k.kunyomi.join("、")}',
            textAlign: TextAlign.center,
            style: t.text.jp(15),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = context.tokens;
    final progress = context.read<ProgressService>();
    final reachedNewLimit = progress.newAvailableCount > 0 &&
        progress.newItemAllowanceRemaining == 0;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Center(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: t.spacing.xl),
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
                                ? 'You introduced $kNewItemsPerDay new items '
                                    'today and have no scheduled reviews due. '
                                    'Come back tomorrow for another new batch.'
                                : 'No reviews due right now. Check back later, '
                                    'or use Flashcards for extra practice.',
                            textAlign: TextAlign.center,
                            style: t.text.secondary,
                          ),
                          SizedBox(height: t.spacing.lg),
                          ThemedButton(
                            label: 'Back to Home',
                            variant: ThemedButtonVariant.secondary,
                            onPressed: () {
                              final audio = context.read<AudioService>();
                              audio.playLessonClick();
                              audio.ensureMenuMusicPlaying();
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Daily Review',
      subtitle: '復習',
      leadingIcon: Icons.close_rounded,
      onLeadingTap: () {
        final audio = context.read<AudioService>();
        audio.playLessonClick();
        audio.ensureMenuMusicPlaying();
        Navigator.of(context).pop();
      },
      trailing: _queue.isNotEmpty
          ? ThemedStatPill(text: '${_index + 1} / ${_queue.length}')
          : null,
    );
  }
}

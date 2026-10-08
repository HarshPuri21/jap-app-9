import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/jlpt_level.dart';
import '../models/kanji_question.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import '../services/activity_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../utils/quiz_options.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/jlpt_level_badge.dart';
import '../widgets/option_button.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

class KanjiModeScreen extends StatefulWidget {
  const KanjiModeScreen({super.key});

  @override
  State<KanjiModeScreen> createState() => _KanjiModeScreenState();
}

class _KanjiModeScreenState extends State<KanjiModeScreen> {
  JlptLevel? _level = JlptLevel.n5; // beginner-safe default; null = All
  late List<KanjiQuestion> _deck;
  List<String> _options = const [];
  int _index = 0;
  String? _selected;
  int _score = 0;
  int _answered = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    // Lesson screens are always freshly created on entry, so a plain
    // initState call (unlike a menu screen returned to via pop) is enough.
    context.read<AudioService>().stopMenuMusic();
  }

  void _reload() {
    _deck = DataService.instance.drawKanjiByJlpt(_level, 0);
    _index = 0;
    _selected = null;
    _score = 0;
    _answered = 0;
    _prepareOptions();
  }

  KanjiQuestion get _current => _deck[_index];

  void _prepareOptions() {
    _options = _deck.isEmpty
        ? const []
        : shuffledCopy<String>(_current.options);
  }

  void _choose(String option) {
    if (_selected != null) return;
    final correct = option == _current.answer;
    setState(() {
      _selected = option;
      _answered += 1;
      if (correct) _score += 1;
    });
    final audio = context.read<AudioService>();
    if (correct) {
      audio.playLessonClick();
    } else {
      audio.playError();
    }
    context.read<SettingsService>().recordAnswer(correct: correct, category: QuizCategory.kanji);
    context.read<ActivityService>().recordActivity();
  }

  void _next() {
    context.read<AudioService>().playLessonClick();
    setState(() {
      if (_index < _deck.length - 1) {
        _index += 1;
      } else {
        _deck.shuffle();
        _index = 0;
      }
      _selected = null;
      _prepareOptions();
    });
  }

  void _setLevel(JlptLevel? level) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _level = level;
      _reload();
    });
  }

  OptionState _stateFor(String option) {
    if (_selected == null) return OptionState.idle;
    if (option == _current.answer) return OptionState.selectedCorrect;
    if (option == _selected) return OptionState.selectedWrong;
    return OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_deck.isEmpty) {
      return Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No kanji found for this JLPT level.',
                        textAlign: TextAlign.center,
                        style: t.text.secondary,
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

    final q = _current;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -200) _next();
            },
            child: Column(
              children: [
                _buildAppBar(context),
                _buildLevelChips(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      t.spacing.gutter,
                      t.spacing.xs,
                      t.spacing.gutter,
                      t.spacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Each new character gets the theme's own reveal: a
                        // neon scan under Tokyo Neon, a soft fade under
                        // Glass, a plain fade under Zen Minimal. The key
                        // is what makes it run again on the next question.
                        ThemedReveal(
                          key: ValueKey<int>(_index),
                          moment: ThemeMoment.kanjiReveal,
                          child: ThemedSurface(
                            level: SurfaceLevel.elevated,
                            radius: t.radii.lg,
                            padding: EdgeInsets.all(t.spacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    JlptLevelBadge(
                                      level: q.jlptLevel,
                                      difficulty: q.difficulty,
                                    ),
                                    Text(
                                      '${_index + 1} / ${_deck.length}',
                                      style: t.text.caption,
                                    ),
                                  ],
                                ),
                                SizedBox(height: t.spacing.md),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    q.kanji,
                                    textAlign: TextAlign.center,
                                    style: t.text
                                        .jp(92, weight: FontWeight.w700),
                                  ),
                                ),
                                SizedBox(height: t.spacing.xs),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: t.spacing.lg),
                        ..._options.map(
                          (opt) => Padding(
                            padding: EdgeInsets.only(bottom: t.spacing.sm),
                            child: OptionButton(
                              text: opt,
                              state: _stateFor(opt),
                              onTap: () => _choose(opt),
                            ),
                          ),
                        ),
                        // The app decides *that* the answer was right or
                        // wrong and *that* there is an explanation; the theme
                        // decides only how the two arrive. Both widgets are
                        // built unconditionally, so no animation, and no
                        // theme, can gate the lesson content.
                        if (_selected != null) ...[
                          ThemedReveal(
                            moment: _selected == q.answer
                                ? ThemeMoment.success
                                : ThemeMoment.error,
                            tint: _selected == q.answer
                                ? t.colors.good
                                : t.colors.bad,
                            child: _buildFeedback(context, q),
                          ),
                          SizedBox(height: t.spacing.sm),
                          ThemedReveal(
                            moment: ThemeMoment.explanationReveal,
                            child: _buildReveal(context, q),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback(BuildContext context, KanjiQuestion q) {
    final t = context.tokens;
    final correct = _selected == q.answer;
    final color = correct ? t.colors.good : t.colors.bad;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: t.radii.sm,
      allowHeavyEffects: false,
      tint: color,
      tintStrength: 0.7,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.sm,
        vertical: t.spacing.xs + 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              correct ? 'Correct!' : 'Not quite — correct answer highlighted',
              style: t.text.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReveal(BuildContext context, KanjiQuestion q) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('READINGS', style: t.text.overline),
          SizedBox(height: t.spacing.sm),
          if (q.onyomi.isNotEmpty)
            _readingRow(context, "On'yomi", q.onyomi.join('、')),
          if (q.kunyomi.isNotEmpty)
            _readingRow(context, "Kun'yomi", q.kunyomi.join('、')),
          if (q.breakdown != null && q.breakdown!.isNotEmpty)
            _readingRow(context, 'Breakdown', q.breakdown!),
          if (q.commonWords.isNotEmpty) ...[
            SizedBox(height: t.spacing.sm),
            Text('COMMON WORDS', style: t.text.overline),
            SizedBox(height: t.spacing.xs),
            ...q.commonWords.map(
              (w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        w.word,
                        style: t.text.jp(16, weight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: t.spacing.xs),
                    Expanded(
                      child: Text(
                        '${w.reading} — ${w.meaning}',
                        style: t.text.jp(13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readingRow(BuildContext context, String label, String value) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: t.text.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Expanded(child: Text(value, style: t.text.jp(13.5))),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Learn Kanji',
      subtitle: '漢字',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
      trailing: ThemedStatPill(
        text: '$_score/$_answered',
        icon: Icons.military_tech_outlined,
      ),
    );
  }

  Widget _buildLevelChips(BuildContext context) {
    final t = context.tokens;
    const options = <(JlptLevel?, String)>[
      (null, 'All'),
      (JlptLevel.n5, 'N5'),
      (JlptLevel.n4, 'N4'),
      (JlptLevel.n3, 'N3'),
      (JlptLevel.n2, 'N2'),
      (JlptLevel.n1, 'N1'),
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
        children: options.map((o) {
          final level = o.$1;
          final color = level == null
              ? null
              : t.colors.forDifficulty(_difficultyForLevel(level));
          return Padding(
            padding: EdgeInsets.only(right: t.spacing.xs),
            child: Center(
              child: ThemedChip(
                label: o.$2,
                selected: level == _level,
                color: color,
                onTap: () => _setLevel(level),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.gutter,
        t.spacing.xs,
        t.spacing.gutter,
        t.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: ThemedButton(
              label: 'Skip',
              icon: Icons.skip_next_rounded,
              variant: ThemedButtonVariant.secondary,
              onPressed: _next,
            ),
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: ThemedButton(
              label: 'Next',
              icon: Icons.arrow_forward_rounded,
              onPressed: _selected == null ? null : _next,
            ),
          ),
        ],
      ),
    );
  }
}

String _difficultyForLevel(JlptLevel level) => switch (level) {
      JlptLevel.n5 || JlptLevel.n4 => 'easy',
      JlptLevel.n3 => 'normal',
      JlptLevel.n2 || JlptLevel.n1 => 'hard',
    };

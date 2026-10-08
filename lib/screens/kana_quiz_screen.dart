import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import '../services/activity_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/option_button.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

enum _Direction { kanaToRomaji, romajiToKana }

class KanaQuizScreen extends StatefulWidget {
  const KanaQuizScreen({super.key});

  @override
  State<KanaQuizScreen> createState() => _KanaQuizScreenState();
}

class _KanaQuizScreenState extends State<KanaQuizScreen> {
  KanaType? _typeFilter; // null = mixed (both types)
  _Direction _direction = _Direction.kanaToRomaji;

  late List<KanaEntry> _pool; // everything quizzable at the current filter
  late List<KanaEntry> _deck; // this session's shuffled run through _pool
  late List<String> _currentOptions;
  int _index = 0;
  String? _selected;
  int _score = 0;
  int _answered = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    context.read<AudioService>().stopMenuMusic();
  }

  /// The sokuon (っ/ッ) has no romaji of its own, so it's excluded from the
  /// quiz pool -- there's no single correct "answer" to show for it in
  /// either direction.
  void _reload() {
    final all = DataService.instance.kana.where((k) => k.romaji.isNotEmpty);
    _pool = (_typeFilter == null ? all : all.where((k) => k.type == _typeFilter))
        .toList();
    _deck = List<KanaEntry>.from(_pool)..shuffle();
    _index = 0;
    _selected = null;
    _score = 0;
    _answered = 0;
    _currentOptions = _deck.isEmpty ? [] : _buildOptions(_deck[_index]);
  }

  KanaEntry get _current => _deck[_index];

  String _prompt(KanaEntry e) =>
      _direction == _Direction.kanaToRomaji ? e.character : e.romaji;
  String _answerFor(KanaEntry e) =>
      _direction == _Direction.kanaToRomaji ? e.romaji : e.character;

  /// Four options: the correct answer plus three distractors drawn from the
  /// same pool, de-duplicated by display string (romaji collisions like
  /// じ/ぢ both reading "ji" are rare enough not to special-case here).
  List<String> _buildOptions(KanaEntry entry) {
    final correct = _answerFor(entry);
    final candidates = _pool.where((k) => k.character != entry.character).toList()
      ..shuffle(Random());

    final options = <String>{correct};
    for (final c in candidates) {
      if (options.length >= 4) break;
      options.add(_answerFor(c));
    }
    final list = options.toList()..shuffle(Random());
    return list;
  }

  void _choose(String option) {
    if (_selected != null) return;
    final correct = option == _answerFor(_current);
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
    // Matches how the Radical and Kanji quizzes record progress: the shared
    // lifetime-accuracy stat, not the vocab/kanji spaced-repetition system.
    context.read<SettingsService>().recordAnswer(correct: correct, category: QuizCategory.kana);
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
      _currentOptions = _buildOptions(_deck[_index]);
    });
  }

  void _setTypeFilter(KanaType? type) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _typeFilter = type;
      _reload();
    });
  }

  void _setDirection(_Direction d) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _direction = d;
      _selected = null;
      _currentOptions = _deck.isEmpty ? [] : _buildOptions(_deck[_index]);
    });
  }

  OptionState _stateFor(String option) {
    if (_selected == null) return OptionState.idle;
    final correct = _answerFor(_current);
    if (option == correct) return OptionState.selectedCorrect;
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
                _buildFilterChips(context),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No kana found for this filter.',
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

    final e = _current;
    final promptIsKana = _direction == _Direction.kanaToRomaji;

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
                _buildFilterChips(context),
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
                                    _TypeTag(type: e.type),
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
                                    _prompt(e),
                                    textAlign: TextAlign.center,
                                    style: promptIsKana
                                        ? t.text.jp(92, weight: FontWeight.w700)
                                        : t.text.display.copyWith(
                                            fontSize: 56,
                                            fontWeight: FontWeight.w800,
                                          ),
                                  ),
                                ),
                                SizedBox(height: t.spacing.xs),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: t.spacing.lg),
                        ..._currentOptions.map(
                          (opt) => Padding(
                            padding: EdgeInsets.only(bottom: t.spacing.sm),
                            child: OptionButton(
                              text: opt,
                              state: _stateFor(opt),
                              onTap: () => _choose(opt),
                            ),
                          ),
                        ),
                        if (_selected != null) ...[
                          ThemedReveal(
                            moment: _selected == _answerFor(e)
                                ? ThemeMoment.success
                                : ThemeMoment.error,
                            tint: _selected == _answerFor(e)
                                ? t.colors.good
                                : t.colors.bad,
                            child: _buildFeedback(context, e),
                          ),
                          if (e.notes != null && e.notes!.isNotEmpty) ...[
                            SizedBox(height: t.spacing.sm),
                            ThemedReveal(
                              moment: ThemeMoment.explanationReveal,
                              child: _buildNoteReveal(context, e),
                            ),
                          ],
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

  Widget _buildFeedback(BuildContext context, KanaEntry e) {
    final t = context.tokens;
    final correct = _selected == _answerFor(e);
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

  Widget _buildNoteReveal(BuildContext context, KanaEntry e) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GOOD TO KNOW', style: t.text.overline),
          SizedBox(height: t.spacing.xs),
          Text(e.notes!, style: t.text.jp(13.5)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Kana Quiz',
      subtitle: '仮名クイズ',
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

  Widget _buildFilterChips(BuildContext context) {
    final t = context.tokens;
    const typeOptions = <(KanaType?, String)>[
      (null, 'Mixed'),
      (KanaType.hiragana, 'Hiragana'),
      (KanaType.katakana, 'Katakana'),
    ];
    const directionOptions = [
      (_Direction.kanaToRomaji, 'Kana → Romaji'),
      (_Direction.romajiToKana, 'Romaji → Kana'),
    ];
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
            children: typeOptions.map((o) {
              return Padding(
                padding: EdgeInsets.only(right: t.spacing.xs),
                child: Center(
                  child: ThemedChip(
                    label: o.$2,
                    selected: o.$1 == _typeFilter,
                    onTap: () => _setTypeFilter(o.$1),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: t.spacing.xs),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
            children: directionOptions.map((o) {
              return Padding(
                padding: EdgeInsets.only(right: t.spacing.xs),
                child: Center(
                  child: ThemedChip(
                    label: o.$2,
                    selected: o.$1 == _direction,
                    onTap: () => _setDirection(o.$1),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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

/// Tiny "Hiragana"/"Katakana" tag on each quiz card, so it's always clear
/// which alphabet the prompt belongs to -- most useful with the 'Mixed'
/// type filter, but shown unconditionally for consistency.
class _TypeTag extends StatelessWidget {
  final KanaType type;
  const _TypeTag({required this.type});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        type.label.toUpperCase(),
        style: t.text.caption.copyWith(
          color: t.colors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sentence.dart';
import '../models/kanji_question.dart';
import '../models/radical_question.dart';
import '../models/jlpt_level.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import '../services/activity_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../utils/quiz_options.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/jlpt_level_badge.dart';
import '../widgets/option_button.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'test_results_screen.dart';

/// One graded question in a test run, in a shape that works for a Sentence,
/// a KanjiQuestion, or a RadicalQuestion so the UI code below doesn't need
/// to branch everywhere.
class _TestItem {
  final String prompt; // jp sentence text, or the kanji/radical character
  final bool isSingleChar; // true for kanji & radicals -- shown big
  final String difficulty;
  final JlptLevel? jlptLevel;
  final List<String> options;
  final String answer;

  _TestItem.fromSentence(Sentence s)
      : prompt = s.jp,
        isSingleChar = false,
        difficulty = s.difficulty,
        jlptLevel = s.jlptLevel,
        options = shuffledCopy<String>(s.options),
        answer = s.answer;

  _TestItem.fromKanji(KanjiQuestion k)
      : prompt = k.kanji,
        isSingleChar = true,
        difficulty = k.difficulty,
        jlptLevel = k.jlptLevel,
        options = shuffledCopy<String>(k.options),
        answer = k.answer;

  _TestItem.fromRadical(RadicalQuestion r)
      : prompt = r.char,
        isSingleChar = true,
        difficulty = r.difficulty,
        jlptLevel = null,
        options = shuffledCopy<String>(r.options),
        answer = r.answer;
}

class TestRunScreen extends StatefulWidget {
  final String qtype; // sentences | kanji | radicals | mixed
  final JlptLevel? level;
  final String difficulty;
  final int count;

  const TestRunScreen({
    super.key,
    required this.qtype,
    this.level,
    required this.difficulty,
    required this.count,
  });

  @override
  State<TestRunScreen> createState() => _TestRunScreenState();
}

class _TestRunScreenState extends State<TestRunScreen> {
  late List<_TestItem> _items;
  int _index = 0;
  String? _selected;
  int _score = 0;
  final List<bool> _correctness = [];

  @override
  void initState() {
    super.initState();
    _items = _buildItems();
    context.read<AudioService>().stopMenuMusic();
  }

  List<_TestItem> _buildItems() {
    switch (widget.qtype) {
      case 'kanji':
        return DataService.instance
            .drawKanjiByJlpt(widget.level, widget.count)
            .map((k) => _TestItem.fromKanji(k))
            .toList();
      case 'radicals':
        return DataService.instance
            .drawRadicals(widget.difficulty, widget.count)
            .map((r) => _TestItem.fromRadical(r))
            .toList();
      case 'mixed':
        final raw =
            DataService.instance.drawMixed(widget.difficulty, widget.count);
        return raw.map((q) {
          if (q is Sentence) return _TestItem.fromSentence(q);
          if (q is KanjiQuestion) return _TestItem.fromKanji(q);
          return _TestItem.fromRadical(q as RadicalQuestion);
        }).toList();
      case 'sentences':
      default:
        return DataService.instance
            .drawSentencesByJlpt(widget.level, widget.count)
            .map((s) => _TestItem.fromSentence(s))
            .toList();
    }
  }

  _TestItem get _current => _items[_index];
  bool get _isLast => _index == _items.length - 1;

  void _choose(String option) {
    if (_selected != null) return;
    final correct = option == _current.answer;
    setState(() {
      _selected = option;
      _correctness.add(correct);
      if (correct) _score += 1;
    });
    final audio = context.read<AudioService>();
    if (correct) {
      audio.playLessonClick();
    } else {
      audio.playError();
    }
    context.read<SettingsService>().recordAnswer(correct: correct, category: QuizCategory.test);
    context.read<ActivityService>().recordActivity();
  }

  void _advance() {
    context.read<AudioService>().playLessonClick();
    if (_isLast) {
      // Resume the menu music now -- the test is over, even though we're
      // showing the results screen rather than a true menu screen yet.
      context.read<AudioService>().ensureMenuMusicPlaying();
      Navigator.of(context).pushReplacement(
        themedRoute(
          context,
          (_) => TestResultsScreen(
            score: _score,
            total: _items.length,
          ),
        ),
      );
      return;
    }
    setState(() {
      _index += 1;
      _selected = null;
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

    if (_items.isEmpty) {
      return Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(t.spacing.xl),
                child: ThemedSurface(
                  level: SurfaceLevel.elevated,
                  radius: t.radii.lg,
                  padding: EdgeInsets.all(t.spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No questions available for this combination.',
                        textAlign: TextAlign.center,
                        style: t.text.body,
                      ),
                      SizedBox(height: t.spacing.md),
                      ThemedButton(
                        label: 'Back',
                        expand: false,
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
        ),
      );
    }

    final item = _current;
    final progress = (_index + (_selected != null ? 1 : 0)) / _items.length;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
                child: ThemedProgressBar(value: progress),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.md,
                    t.spacing.gutter,
                    t.spacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ThemedSurface(
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
                                  level: item.jlptLevel,
                                  difficulty: item.difficulty,
                                ),
                                Text(
                                  'Question ${_index + 1} / ${_items.length}',
                                  style: t.text.caption,
                                ),
                              ],
                            ),
                            SizedBox(height: t.spacing.md),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.prompt,
                                textAlign: TextAlign.center,
                                style: t.text.jp(
                                  item.isSingleChar ? 88 : 27,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(height: t.spacing.xs),
                          ],
                        ),
                      ),
                      SizedBox(height: t.spacing.lg),
                      ...item.options.map(
                        (opt) => Padding(
                          padding: EdgeInsets.only(bottom: t.spacing.sm),
                          child: OptionButton(
                            text: opt,
                            state: _stateFor(opt),
                            onTap: () => _choose(opt),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.gutter,
                  0,
                  t.spacing.gutter,
                  t.spacing.md,
                ),
                child: ThemedButton(
                  label: _isLast ? 'Finish' : 'Next',
                  icon: _isLast
                      ? Icons.flag_outlined
                      : Icons.arrow_forward_rounded,
                  onPressed: _selected == null ? null : _advance,
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
      title: 'Test',
      subtitle: 'テスト',
      leadingIcon: Icons.close_rounded,
      onLeadingTap: () {
        final audio = context.read<AudioService>();
        audio.playLessonClick();
        audio.ensureMenuMusicPlaying();
        Navigator.of(context).pop();
      },
      trailing: ThemedStatPill(
        text: '$_score/${_correctness.length}',
        icon: Icons.military_tech_outlined,
      ),
    );
  }
}

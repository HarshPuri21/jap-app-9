import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/jlpt_level.dart';
import '../models/sentence.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import '../services/activity_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../utils/quiz_options.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/breakdown_panel.dart';
import '../widgets/option_button.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

class SentenceModeScreen extends StatefulWidget {
  const SentenceModeScreen({super.key});

  @override
  State<SentenceModeScreen> createState() => _SentenceModeScreenState();
}

class _SentenceModeScreenState extends State<SentenceModeScreen> {
  JlptLevel? _level = JlptLevel.n5; // beginner-safe default; null = All
  late List<Sentence> _deck;
  List<String> _options = const [];
  int _index = 0;
  String? _selected;
  int _score = 0;
  int _answered = 0;

  // Shows the current sentence's casual/formal PAIR instead of the drawn
  // sentence itself. Deliberately independent of `_selected`/`_score` --
  // the pair shares the same en/options/answer (see
  // tool/generate_sentence_questions.py), so toggling never touches
  // scoring, before or after answering.
  bool _showPaired = false;

  // Collapsed by default, per the confirmed scope -- the family list is a
  // browse aid, not something that should compete with the question itself
  // for attention.
  bool _familyExpanded = false;

  @override
  void initState() {
    super.initState();
    _reload();
    // Lesson screens are always freshly created on entry, so a plain
    // initState call (unlike a menu screen returned to via pop) is enough.
    context.read<AudioService>().stopMenuMusic();
  }

  void _reload() {
    _deck = DataService.instance.drawSentencesByJlpt(_level, 0);
    _index = 0;
    _selected = null;
    _score = 0;
    _answered = 0;
    _showPaired = false;
    _familyExpanded = false;
    _prepareOptions();
  }

  Sentence get _current => _deck[_index];

  void _prepareOptions() {
    _options = _deck.isEmpty
        ? const []
        : shuffledCopy<String>(_current.options);
  }

  /// The other tone of the current sentence's (family, form) -- its
  /// casual/formal twin -- or null if there isn't one (te-form,
  /// conditional-tara, or a sentence with no family at all).
  Sentence? get _pairedSentence {
    final familyId = _current.familyId;
    final form = _current.form;
    if (familyId == null || form == null) return null;
    final wantTone = _current.tone == SentenceTone.casual
        ? SentenceTone.formal
        : SentenceTone.casual;
    if (_current.tone == SentenceTone.neutral) return null;
    final family = DataService.instance.sentenceFamilies[familyId] ?? const [];
    for (final s in family) {
      if (s.form == form && s.tone == wantTone) return s;
    }
    return null;
  }

  /// What the card actually shows for jp/reading -- the drawn sentence, or
  /// its pair if toggled. Everything quiz-related (options/answer/score)
  /// always reads from [_current] regardless of this.
  Sentence get _displaySentence =>
      _showPaired ? (_pairedSentence ?? _current) : _current;

  List<SentenceFormVariants> get _familyVariants {
    final familyId = _current.familyId;
    if (familyId == null) return const [];
    final all = DataService.instance.sentenceFamilies[familyId] ?? const [];
    final byForm = <SentenceForm, List<Sentence>>{};
    for (final s in all) {
      final f = s.form;
      if (f == null) continue;
      (byForm[f] ??= <Sentence>[]).add(s);
    }
    final forms = byForm.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return [
      for (final f in forms)
        SentenceFormVariants(
          form: f,
          variants: byForm[f]!
            ..sort((a, b) =>
                (a.tone?.index ?? 0).compareTo(b.tone?.index ?? 0)),
        ),
    ];
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
    context.read<SettingsService>().recordAnswer(correct: correct, category: QuizCategory.sentences);
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
      _showPaired = false;
      _familyExpanded = false;
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

  void _togglePaired() {
    context.read<AudioService>().playLessonClick();
    setState(() => _showPaired = !_showPaired);
  }

  void _toggleFamilyExpanded() {
    context.read<AudioService>().playLessonClick();
    setState(() => _familyExpanded = !_familyExpanded);
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
                _buildLevelChips(context),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No sentences found for this level.',
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
    final display = _displaySentence;
    final paired = _pairedSentence;

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
                        // Each new sentence gets the theme's own reveal. The key
                        // is what makes it run again on the next question --
                        // deliberately NOT keyed on _showPaired too, since
                        // toggling the tone shouldn't replay the reveal
                        // animation, only navigating to a new question should.
                        ThemedReveal(
                          key: ValueKey<int>(_index),
                          moment: ThemeMoment.cardReveal,
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
                                    _LevelFormBadge(sentence: q),
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
                                    display.jp,
                                    textAlign: TextAlign.center,
                                    style: t.text
                                        .jp(27, weight: FontWeight.w700),
                                  ),
                                ),
                                if (display.reading != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    display.reading!,
                                    textAlign: TextAlign.center,
                                    style: t.text.jp(14).copyWith(
                                        color: t.colors.textSecondary),
                                  ),
                                ],
                                if (paired != null) ...[
                                  SizedBox(height: t.spacing.sm),
                                  Center(
                                    child: _ToneToggle(
                                      current: display.tone!, // non-null: guaranteed whenever a pair exists, see _pairedSentence
                                      onTap: _togglePaired,
                                    ),
                                  ),
                                ],
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
                        if (q.familyId != null && _familyVariants.isNotEmpty) ...[
                          SizedBox(height: t.spacing.sm),
                          _buildFamilySection(context),
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

  Widget _buildFeedback(BuildContext context, Sentence q) {
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

  /// Familial sentences show their grammar [Sentence.explanation]; the
  /// handful of sentences with no family (none currently ship, but this
  /// stays as a safety fallback -- see the integration notes) show the
  /// original word-by-word breakdown panel unchanged.
  Widget _buildReveal(BuildContext context, Sentence q) {
    if (q.familyId != null && q.explanation != null) {
      final t = context.tokens;
      return ThemedSurface(
        level: SurfaceLevel.standard,
        radius: t.radii.md,
        width: double.infinity,
        padding: EdgeInsets.all(t.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GRAMMAR', style: t.text.overline),
            SizedBox(height: t.spacing.xs),
            Text(q.explanation!, style: t.text.body),
          ],
        ),
      );
    }
    return BreakdownPanel(chunks: q.breakdown);
  }

  Widget _buildFamilySection(BuildContext context) {
    final t = context.tokens;
    // Computed once into a local: SentenceFormVariants has no overridden
    // ==, and _familyVariants rebuilds fresh instances on every call, so
    // comparing against a second call's `.last` would never match by
    // reference and silently break the "no divider after the last item"
    // logic below.
    final variants = _familyVariants;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggleFamilyExpanded,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All forms in this family (${variants.length})',
                    style: t.text.overline,
                  ),
                ),
                AnimatedRotation(
                  turns: _familyExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more,
                      size: 20, color: t.colors.textSecondary),
                ),
              ],
            ),
          ),
          if (_familyExpanded) ...[
            SizedBox(height: t.spacing.sm),
            for (final variant in variants) ...[
              _FamilyFormRow(
                variant: variant,
                isCurrentForm: variant.form == _current.form,
              ),
              if (variant.form != variants.last.form) ...[
                SizedBox(height: t.spacing.xs),
                Divider(height: 1, color: t.colors.textTertiary.withOpacity(0.2)),
                SizedBox(height: t.spacing.xs),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Learn Sentences',
      subtitle: '文章',
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
              : t.colors.forDifficulty(_kDifficultyForLevel(level));
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

/// Mirrors the same N5/N4/N3/N2/N1 -> easy/normal/hard mapping baked into
/// tool/generate_sentence_questions.py and tool/regenerate_kanji_questions.py,
/// just for picking a chip color here -- not a source of truth for anything
/// persisted.
String _kDifficultyForLevel(JlptLevel level) => switch (level) {
      JlptLevel.n5 || JlptLevel.n4 => 'easy',
      JlptLevel.n3 => 'normal',
      JlptLevel.n2 || JlptLevel.n1 => 'hard',
    };

/// Small pill on the question card: JLPT level + grammatical form, when
/// known (falls back to just the difficulty badge look for sentences with
/// no family/level -- none ship currently, but see _buildReveal's note).
class _LevelFormBadge extends StatelessWidget {
  final Sentence sentence;
  const _LevelFormBadge({required this.sentence});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final level = sentence.jlptLevel;
    final color = t.colors.forDifficulty(sentence.difficulty);
    final label = level != null
        ? (sentence.form != null
            ? '${level.label} · ${sentence.form!.label}'
            : level.label)
        : sentence.difficulty.toUpperCase();

    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      tint: color,
      tintStrength: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: t.text.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// The in-place casual/formal switch on the question card. Shows which tone
/// is currently displayed and what tapping it switches to; only ever built
/// when a pair actually exists (te-form/conditional-tara hide it entirely
/// by never reaching this widget -- see the `paired != null` guard in build).
class _ToneToggle extends StatelessWidget {
  final SentenceTone current;
  final VoidCallback onTap;
  const _ToneToggle({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final showing = current == SentenceTone.formal ? 'Formal' : 'Casual';
    final switchTo = current == SentenceTone.formal ? 'Casual' : 'Formal';
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(ThemeRadii.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_alt, size: 14, color: t.colors.accent),
              const SizedBox(width: 6),
              Text(
                'Showing $showing — tap for $switchTo',
                style: t.text.caption.copyWith(
                  color: t.colors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in the "All forms in this family" list: the form's label,
/// explanation, and its tone(s) as plain lines (never a toggle here --
/// the whole point of this view is comparing forms, so both tones of a
/// pair are shown together rather than hidden behind another switch).
class _FamilyFormRow extends StatelessWidget {
  final SentenceFormVariants variant;
  final bool isCurrentForm;
  const _FamilyFormRow({required this.variant, required this.isCurrentForm});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                variant.form.label,
                style: t.text.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (isCurrentForm) ...[
              const SizedBox(width: 6),
              Icon(Icons.radio_button_checked,
                  size: 12, color: t.colors.accent),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(variant.explanation, style: t.text.caption),
        const SizedBox(height: 6),
        for (final v in variant.variants)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    () {
                      final tone = v.tone;
                      return tone != null && tone != SentenceTone.neutral
                          ? tone.label
                          : '';
                    }(),
                    style: t.text.caption.copyWith(
                      color: t.colors.textTertiary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(v.jp, style: t.text.jp(14)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/jlpt_level.dart';
import '../services/audio_service.dart';
import '../services/route_observer.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'test_run_screen.dart';

class TestSetupScreen extends StatefulWidget {
  const TestSetupScreen({super.key});

  @override
  State<TestSetupScreen> createState() => _TestSetupScreenState();
}

class _TestSetupScreenState extends State<TestSetupScreen> with RouteAware {
  String _qtype = 'sentences'; // sentences | kanji | radicals | mixed
  // Beginner-safe default for sentence/kanji tests.
  JlptLevel? _level = JlptLevel.n5;
  String _difficulty = 'all'; // all | easy | normal | hard
  double _count = 15;

  bool get _usesJlpt => _qtype == 'sentences' || _qtype == 'kanji';

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
    // Returning here after "Try Another Test" pops the results screen off.
    context.read<AudioService>().ensureMenuMusicPlaying();
  }

  void _click() => context.read<AudioService>().playMenuClick();

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
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.lg,
                  ),
                  children: [
                    const ThemedSectionLabel('Test me on'),
                    _panel(
                      context,
                      child: _segmented(
                        context,
                        value: _qtype,
                        options: const [
                          ('sentences', 'Sentences'),
                          ('kanji', 'Kanji'),
                          ('radicals', 'Radicals'),
                          ('mixed', 'Mixed'),
                        ],
                        onChanged: (v) {
                          _click();
                          setState(() {
                            _qtype = v;
                            _level = (v == 'sentences' || v == 'kanji')
                                ? JlptLevel.n5
                                : null;
                            _difficulty = 'all';
                          });
                        },
                      ),
                    ),
                    SizedBox(height: t.spacing.xl),
                    if (_usesJlpt) ...[
                      const ThemedSectionLabel('JLPT Level'),
                      _panel(
                        context,
                        child: _jlptSegmented(context),
                      ),
                    ] else ...[
                      const ThemedSectionLabel('Difficulty'),
                      _panel(
                        context,
                        child: _segmented(
                          context,
                          value: _difficulty,
                          options: const [
                            ('all', 'All'),
                            ('easy', 'Easy'),
                            ('normal', 'Normal'),
                            ('hard', 'Hard'),
                          ],
                          onChanged: (v) {
                            _click();
                            setState(() => _difficulty = v);
                          },
                          colorFor: (v) =>
                              v == 'all' ? null : t.colors.forDifficulty(v),
                        ),
                      ),
                    ],
                    SizedBox(height: t.spacing.xl),
                    const ThemedSectionLabel('Length'),
                    _panel(
                      context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Number of questions',
                                  style: t.text.secondary,
                                ),
                              ),
                              Text(
                                '${_count.round()}',
                                style: t.text.title.copyWith(
                                  color: t.colors.accent,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _count,
                            min: 5,
                            max: 50,
                            divisions: 9,
                            label: '${_count.round()}',
                            onChanged: (v) => setState(() => _count = v),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  label: 'Start Test',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    _click();
                    Navigator.of(context).push(
                      themedRoute(
                        context,
                        (_) => TestRunScreen(
                          qtype: _qtype,
                          level: _usesJlpt ? _level : null,
                          difficulty: _difficulty,
                          count: _count.round(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jlptSegmented(BuildContext context) {
    final t = context.tokens;
    const options = <(JlptLevel?, String)>[
      (null, 'All'),
      (JlptLevel.n5, 'N5'),
      (JlptLevel.n4, 'N4'),
      (JlptLevel.n3, 'N3'),
      (JlptLevel.n2, 'N2'),
      (JlptLevel.n1, 'N1'),
    ];
    return Wrap(
      spacing: t.spacing.xs,
      runSpacing: t.spacing.xs,
      children: options.map((o) {
        final level = o.$1;
        return ThemedChip(
          label: o.$2,
          selected: level == _level,
          color: level == null
              ? null
              : t.colors.forDifficulty(_difficultyForLevel(level)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          onTap: () {
            _click();
            setState(() => _level = level);
          },
        );
      }).toList(),
    );
  }

  Widget _panel(BuildContext context, {required Widget child}) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      padding: EdgeInsets.all(t.spacing.md),
      child: child,
    );
  }

  Widget _segmented(
    BuildContext context, {
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
    Color? Function(String)? colorFor,
  }) {
    final t = context.tokens;
    return Wrap(
      spacing: t.spacing.xs,
      runSpacing: t.spacing.xs,
      children: options.map((o) {
        return ThemedChip(
          label: o.$2,
          selected: o.$1 == value,
          color: colorFor?.call(o.$1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          onTap: () => onChanged(o.$1),
        );
      }).toList(),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Take a Test',
      subtitle: 'テスト',
      onLeadingTap: () {
        _click();
        Navigator.of(context).pop();
      },
    );
  }
}

String _difficultyForLevel(JlptLevel level) => switch (level) {
      JlptLevel.n5 || JlptLevel.n4 => 'easy',
      JlptLevel.n3 => 'normal',
      JlptLevel.n2 || JlptLevel.n1 => 'hard',
    };

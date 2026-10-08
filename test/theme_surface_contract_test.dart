import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nihongo_trainer/theming/theme_definition.dart';
import 'package:nihongo_trainer/theming/theme_registry.dart';
import 'package:nihongo_trainer/theming/theme_scope.dart';
import 'package:nihongo_trainer/theming/theme_tokens.dart';
import 'package:nihongo_trainer/widgets/themed/themed_motion.dart';
import 'package:nihongo_trainer/widgets/themed/themed_surface.dart';

/// These tests exist because of one specific bug.
///
/// The Glass theme applied `SurfaceRequest.width` / `height` by tightening
/// the pane against `constraints.biggest`. That is correct only when both
/// axes are bounded. Every full-bleed panel inside a scroll view — the answer
/// explanation in Practice and Radical, the radical's usage and example
/// cards, the sentence breakdown — has an *unbounded* vertical axis, so the
/// tightening produced an infinite height constraint, the surface failed to
/// lay out, and the educational content silently vanished for anyone using
/// that theme. Zen Minimal, which applies the size with a plain
/// `AnimatedContainer`, was unaffected, which is why the bug looked like a
/// theme owning the explanation rather than a theme dropping it.
///
/// The tests below run against *every* theme in the registry, so a new theme
/// that makes the same mistake fails here rather than in someone's study
/// session.
void main() {
  Widget harness(
    AppThemeDefinition theme, {
    required Widget child,
    bool effectsEnabled = true,
  }) {
    return MaterialApp(
      theme: theme.buildMaterialTheme(),
      home: ThemeScope(
        theme: theme,
        effectsEnabled: effectsEnabled,
        child: Scaffold(body: child),
      ),
    );
  }

  group('surface sizing contract', () {
    for (final theme in ThemeRegistry.themes) {
      testWidgets(
        '${theme.name}: a full-width surface in a scroll view keeps its '
        'content',
        (tester) async {
          await tester.pumpWidget(
            harness(
              theme,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    ThemedSurface(
                      level: SurfaceLevel.standard,
                      // The exact shape every explanation panel uses.
                      width: double.infinity,
                      child: Text('MEANING AND EXPLANATION'),
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('MEANING AND EXPLANATION'), findsOneWidget);

          // Not just present in the tree — actually laid out with a real,
          // finite size. A surface that "renders" at zero or infinite height
          // is exactly as useless to the learner.
          final box = tester.getSize(find.text('MEANING AND EXPLANATION'));
          expect(box.height, greaterThan(0));
          expect(box.height.isFinite, isTrue);
          expect(box.width, greaterThan(0));
        },
      );

      testWidgets(
        '${theme.name}: a surface sized on both axes fills its parent',
        (tester) async {
          await tester.pumpWidget(
            harness(
              theme,
              child: Center(
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: ThemedSurface(
                    level: SurfaceLevel.elevated,
                    width: double.infinity,
                    height: double.infinity,
                    padding: EdgeInsets.zero,
                    child: const SizedBox.expand(
                      child: Text('FLASHCARD FACE'),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('FLASHCARD FACE'), findsOneWidget);
          expect(
            tester.getSize(find.byType(ThemedSurface)),
            const Size(300, 200),
          );
        },
      );

      testWidgets(
        '${theme.name}: content survives with heavy effects disabled',
        (tester) async {
          await tester.pumpWidget(
            harness(
              theme,
              effectsEnabled: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    ThemedSurface(
                      width: double.infinity,
                      allowHeavyEffects: false,
                      child: Text('CHEAP PATH EXPLANATION'),
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('CHEAP PATH EXPLANATION'), findsOneWidget);
        },
      );
    }
  });

  group('reveal contract', () {
    for (final theme in ThemeRegistry.themes) {
      for (final moment in ThemeMoment.values) {
        testWidgets(
          '${theme.name}: $moment shows its child on the first frame',
          (tester) async {
            await tester.pumpWidget(
              harness(
                theme,
                child: ThemedReveal(
                  moment: moment,
                  tint: theme.tokens.colors.good,
                  child: const Text('LESSON CONTENT'),
                ),
              ),
            );

            // Deliberately no settle: the content must be in the tree from
            // the very first frame of the animation. An animation is allowed
            // to change how it *looks*, never whether it exists.
            expect(tester.takeException(), isNull);
            expect(find.text('LESSON CONTENT'), findsOneWidget);

            await tester.pumpAndSettle();
            expect(find.text('LESSON CONTENT'), findsOneWidget);
          },
        );
      }

      testWidgets(
        '${theme.name}: reveals leave nothing running once settled',
        (tester) async {
          await tester.pumpWidget(
            harness(
              theme,
              child: const ThemedReveal(
                moment: ThemeMoment.explanationReveal,
                child: Text('SETTLED'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // pumpAndSettle returning means no frame was scheduled. If a theme
          // ever adds a looping controller to a reveal, this times out.
          expect(find.text('SETTLED'), findsOneWidget);
        },
      );
    }
  });

  group('theme identity', () {
    test('ids are unique and stable', () {
      final ids = ThemeRegistry.themes.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);

      // The Glass theme shipped as "Liquid Glass". The user-facing name
      // changed; the persisted id must not, or every existing user silently
      // falls back to the default theme on upgrade.
      expect(ids, contains('liquid_glass'));
      expect(ids, contains('zen_minimal'));
      expect(ids, contains('tokyo_neon'));
    });

    test('an unknown persisted id falls back rather than throwing', () {
      expect(ThemeRegistry.byId('no_such_theme').id,
          ThemeRegistry.defaultThemeId);
      expect(ThemeRegistry.byId(null).id, ThemeRegistry.defaultThemeId);
    });

    test('the renamed theme is user-visible as Glass', () {
      expect(ThemeRegistry.byId('liquid_glass').name, 'Glass');
    });
  });
}

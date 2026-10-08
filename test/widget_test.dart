import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nihongo_trainer/main.dart';
import 'package:nihongo_trainer/screens/home_screen.dart';

void main() {
  testWidgets(
    'App boots past the splash screen onto Home without throwing',
    (WidgetTester tester) async {
      await tester.pumpWidget(const NihongoTrainerApp());

      // The app's first frame is a branded splash screen while bundled JSON
      // and saved settings load (see main.dart's _AppLoader). Its spinner is
      // an indeterminate CircularProgressIndicator, which schedules another
      // frame forever while it's on screen -- so this deliberately pumps a
      // bounded number of fixed steps rather than calling pumpAndSettle,
      // which would time out waiting for an animation that never finishes
      // on its own.
      for (var i = 0;
          i < 20 && find.byType(HomeScreen).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget, reason:
          'Expected the loader to reach HomeScreen once app data finished '
          'loading.');
      expect(find.text('Nihongo Trainer'), findsOneWidget);

      // Home is intentionally grouped into three clear lanes. These labels
      // are a small regression guard for the hierarchy introduced in the
      // final UI-refinement pass; individual cards can evolve without the
      // screen collapsing back into one undifferentiated list of modes.
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('LEARN'), findsOneWidget);
      expect(find.text('PRACTICE'), findsOneWidget);
    },
  );
}

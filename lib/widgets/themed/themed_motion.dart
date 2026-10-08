import 'package:flutter/material.dart';

import '../../theming/theme_definition.dart';
import '../../theming/theme_scope.dart';

/// Announces that something meaningful just appeared, and lets the active
/// theme decide what that looks like.
///
/// This is the motion counterpart of [ThemedSurface]. A screen says
///
/// ```dart
/// ThemedReveal(
///   moment: ThemeMoment.explanationReveal,
///   child: _buildReveal(context, q),
/// )
/// ```
///
/// and never names a curve, a duration or a colour. Glass answers with a soft
/// bloom, Tokyo Neon with a neon scan, Zen Minimal with a plain fade.
///
/// **The child is always built.** This widget only ever wraps content that is
/// already in the tree — it cannot decide *whether* something is shown, only
/// how it arrives. That is deliberate: the explanation regression this engine
/// caused once already must not be reachable from the motion layer either.
class ThemedReveal extends StatelessWidget {
  final Widget child;
  final ThemeMoment moment;

  /// The semantic colour of the moment, when it has one.
  final Color? tint;

  /// Set false when several of these appear at once, so themes with an
  /// expensive reveal use their cheap path.
  final bool allowHeavyEffects;

  const ThemedReveal({
    super.key,
    required this.child,
    required this.moment,
    this.tint,
    this.allowHeavyEffects = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    // The global effects switch folds into the per-request flag, so a theme
    // only has to read one value to know whether it may be expensive.
    final heavy = allowHeavyEffects && ThemeScope.effectsEnabledOf(context);

    return theme.buildReveal(
      context,
      RevealRequest(
        child: child,
        moment: moment,
        tint: tint,
        allowHeavyEffects: heavy,
      ),
    );
  }
}

/// A route that uses the active theme's page transition.
///
/// Drop-in replacement for `MaterialPageRoute(builder: ...)`. Navigation
/// behaviour — push, pop, back gesture, the route observer the audio service
/// listens to — is unchanged; only the transition is themed.
Route<T> themedRoute<T>(BuildContext context, WidgetBuilder builder) {
  final duration = ThemeScope.of(context).pageTransitionDuration;

  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    // Resolved per frame rather than captured, so switching theme while a
    // transition is in flight doesn't mix two themes' motion.
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        ThemeScope.of(context).buildPageTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    ),
    transitionDuration: duration,
    reverseTransitionDuration: duration,
  );
}

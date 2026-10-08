import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// ---------------------------------------------------------------------------
/// The theme contract
/// ---------------------------------------------------------------------------
/// A theme answers exactly two questions the app can't answer for itself:
///
///   1. What does a *surface* look like?  (`buildSurface`)
///   2. What sits *behind* everything?    (`buildBackground`)
///
/// Everything else -- cards, buttons, chips, app bars, progress bars -- is
/// assembled by the shared `widgets/themed/` components out of those two
/// answers plus the theme's tokens. That is what keeps the contract small
/// enough to implement a new theme in one sitting, while still allowing two
/// themes to look nothing alike.
///
/// A theme must not import services, models or screens. It receives
/// everything it needs as arguments.

/// A request to paint one surface. The app describes the surface's *role*
/// and *state*; the theme decides entirely how that looks.
@immutable
class SurfaceRequest {
  final Widget child;

  /// Visual depth. See [SurfaceLevel].
  final SurfaceLevel level;

  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  /// A semantic colour this surface should take on -- the green of a correct
  /// answer, the red of a wrong one, the accent of a selected chip. Null
  /// means "use the theme's neutral surface".
  final Color? tint;

  /// How strongly to apply [tint], 0..1.
  final double tintStrength;

  /// Persistent selected state (a chosen chip, the active background option).
  final bool selected;

  /// Live press feedback, 0 = released, 1 = fully pressed.
  final double pressAmount;

  /// Disabled surfaces should read as clearly non-interactive.
  final bool enabled;

  final bool showShadow;

  /// `false` asks the theme to use its cheap path, because this surface is
  /// repeated many times on one screen (answer options, list rows). Themes
  /// with expensive effects -- a backdrop blur, a shader -- must honour this
  /// or a long list will stutter on mid-range hardware.
  final bool allowHeavyEffects;

  /// Explicit size. Null means "size to the child".
  ///
  /// Either value may legitimately be [double.infinity], which means "fill
  /// whatever the parent offers on that axis" -- callers use
  /// `width: double.infinity` for full-bleed panels. A theme must therefore
  /// never convert these into tight constraints derived from
  /// `constraints.biggest`: a panel inside a scroll view has an *unbounded*
  /// cross axis, and tightening against it produces an infinite constraint
  /// that fails layout and silently drops the surface's content.
  ///
  /// The safe pattern, used by every shipped theme, is to apply the size with
  /// a [SizedBox] and let the incoming constraints pass through untouched
  /// (`StackFit.passthrough` if the theme composes layers in a [Stack]).
  /// `test/theme_surface_contract_test.dart` enforces this for every theme in
  /// the registry.
  final double? width;
  final double? height;

  const SurfaceRequest({
    required this.child,
    this.level = SurfaceLevel.standard,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.tintStrength = 1.0,
    this.selected = false,
    this.pressAmount = 0.0,
    this.enabled = true,
    this.showShadow = true,
    this.allowHeavyEffects = true,
    this.width,
    this.height,
  });
}

/// What the user chose in Settings, handed to the theme as plain values.
///
/// The theme never reads `SettingsService` -- it is told "here is a widget
/// painting the user's wallpaper, dim it by this much" and decides how its
/// own backdrop treatment combines with that.
@immutable
class BackgroundRequest {
  /// The user's own background (a photo or a flat colour), already built.
  /// Null means the user is on "app default", so the theme should paint its
  /// own signature backdrop.
  final Widget? userBackground;

  /// The dimness the user picked, 0..1. Only meaningful when
  /// [userBackground] is non-null.
  final double userDimOpacity;

  const BackgroundRequest({
    required this.userBackground,
    required this.userDimOpacity,
  });

  bool get hasUserBackground => userBackground != null;
}

/// ---------------------------------------------------------------------------
/// Semantic motion
/// ---------------------------------------------------------------------------
/// The same split as surfaces, applied to movement. The app reports *what
/// happened* -- "this answer was correct", "the explanation is now on screen"
/// -- and the theme decides what that looks like. A screen never asks for a
/// "cyan neon pulse"; it asks for [ThemeMoment.success].
///
/// Motion is presentation only. Every widget wrapped in a reveal is built and
/// laid out unconditionally; the animation only affects how it fades in. When
/// animations are switched off the child is returned untouched, so no piece of
/// learning content can ever depend on an animation running.
enum ThemeMoment {
  /// An option/card became the selected one.
  selection,

  /// The answer was correct.
  success,

  /// The answer was wrong.
  error,

  /// A card face turned over.
  cardReveal,

  /// The meaning/explanation panel just became visible.
  explanationReveal,

  /// A kanji was revealed.
  kanjiReveal,

  /// A radical was revealed.
  radicalReveal,
}

/// A request to animate [child] appearing, for a given [moment].
@immutable
class RevealRequest {
  final Widget child;
  final ThemeMoment moment;

  /// The semantic colour of the moment when it has one (the green of a
  /// correct answer, the red of a wrong one). Null for neutral moments.
  final Color? tint;

  /// Same meaning as on [SurfaceRequest]: `false` asks the theme for its
  /// cheap path because this animation is one of many on screen.
  final bool allowHeavyEffects;

  const RevealRequest({
    required this.child,
    required this.moment,
    this.tint,
    this.allowHeavyEffects = true,
  });
}

/// A request to paint the filled portion of a progress bar.
@immutable
class ProgressFillRequest {
  /// The fraction currently painted, 0..1. Already interpolated by the app.
  final double value;

  /// True while [value] is still travelling towards its target. Themes should
  /// only run a travelling highlight while this is true -- a bar that glows
  /// forever costs a frame's work every frame for no information gain.
  final bool animating;

  final Color color;
  final double height;
  final bool allowHeavyEffects;

  const ProgressFillRequest({
    required this.value,
    required this.animating,
    required this.color,
    required this.height,
    this.allowHeavyEffects = true,
  });
}

/// Small, cheap description used to draw a theme's thumbnail in Settings,
/// so the picker doesn't have to instantiate a whole screen to preview one.
@immutable
class ThemePreview {
  final List<Color> swatch;
  final IconData icon;

  const ThemePreview({required this.swatch, required this.icon});
}

/// Implement this to add a theme. Instances are stateless and long-lived --
/// one per theme, created once in the registry.
abstract class AppThemeDefinition {
  const AppThemeDefinition();

  /// Stable identifier persisted in preferences. Never change it once
  /// shipped, or users will silently fall back to the default theme.
  String get id;

  /// Shown in the Settings picker.
  String get name;

  /// One short line in the picker.
  String get description;

  ThemePreview get preview;

  ThemeTokens get tokens;

  /// Material-level styling for the widgets the app doesn't wrap: sliders,
  /// switches, text fields, snackbars, the text-selection handles.
  ThemeData buildMaterialTheme();

  /// Paint the backdrop and place [request] content on top of it.
  Widget buildBackground(
    BuildContext context,
    BackgroundRequest request,
    Widget child,
  );

  /// Paint one surface. This is the heart of a theme.
  Widget buildSurface(BuildContext context, SurfaceRequest request);

  /// Optional: animate [RevealRequest.child] appearing.
  ///
  /// The default is a short fade with a small rise, which is a reasonable
  /// answer for any theme -- Zen Minimal keeps it deliberately. Override to
  /// give a theme its own motion language.
  ///
  /// Two rules bind every implementation:
  ///
  ///  * `request.child` must be returned in the tree on the *first* frame,
  ///    already laid out. Animate opacity or transform around it; never gate
  ///    its construction on an animation, a timer or a completed callback.
  ///  * The result must stay correct if the animation never runs.
  Widget buildReveal(BuildContext context, RevealRequest request) {
    return DefaultReveal(request: request, motion: tokens.motion);
  }

  /// Optional: paint the filled part of a progress bar. The default is a
  /// flat fill in the requested colour.
  Widget buildProgressFill(BuildContext context, ProgressFillRequest request) {
    return ColoredBox(color: request.color);
  }

  /// How long a themed page transition lasts.
  Duration get pageTransitionDuration => tokens.motion.base;

  /// Optional: the transition used when pushing a route. The default is a
  /// fade-through with a small rise, matching [buildReveal]'s restraint.
  ///
  /// Keep these short. A page transition sits directly between a tap and the
  /// content the user asked for, so anything slow reads as lag rather than
  /// polish.
  Widget buildPageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: tokens.motion.curve,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  /// Optional: a decorative plate behind an icon (mode-card icons, settings
  /// rows). The default is a tinted rounded square, which suits most themes;
  /// override it if yours wants something else.
  Widget buildIconPlate(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.sm),
        color: color.withOpacity(0.16),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

/// The default reveal: a short fade with a small rise.
///
/// Written so that the animation is pure decoration around content that is
/// already in the tree:
///
///  * `request.child` is passed through [TweenAnimationBuilder]'s `child`
///    slot, so it is built once and *not* rebuilt on every animation frame.
///  * Once the animation settles, the [Opacity] and [Transform] wrappers are
///    dropped entirely, so a revealed panel costs nothing to keep on screen.
///  * If the platform or the user has asked for reduced motion, the child is
///    returned as-is on the first frame.
class DefaultReveal extends StatelessWidget {
  final RevealRequest request;
  final ThemeMotion motion;

  /// How far the content rises, in logical pixels.
  final double rise;

  const DefaultReveal({
    super.key,
    required this.request,
    required this.motion,
    this.rise = 6,
  });

  @override
  Widget build(BuildContext context) {
    // Reduced-motion is an accessibility setting, not a preference to
    // second-guess: hand the content straight through, unanimated.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return request.child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: motion.base,
      curve: motion.curve,
      child: request.child,
      builder: (context, v, child) {
        if (v >= 1.0) return child!;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * rise),
            child: child,
          ),
        );
      },
    );
  }
}

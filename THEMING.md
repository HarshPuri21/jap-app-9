# Theming — how it works, and how to add a theme

This app's visuals are a separate layer from its logic. This file explains
the layer and walks through adding a new theme end to end.

## The core idea

> The app owns **what** happens. The theme owns **how** it looks.

"This answer is correct" is the app's decision. "What does a correct answer
look like" is the theme's. Nothing else needs to change when you add a theme,
because every screen already talks to the theme layer in those terms —
`SurfaceLevel.elevated`, `t.colors.good`, `t.text.cardTitle` — never in raw
colours, radii or font sizes.

## The three pieces

```
lib/theming/            the contract every theme implements
lib/themes/<name>/       one theme's implementation
lib/widgets/themed/      shared components screens actually use
```

**`theming/theme_tokens.dart`** — the vocabulary. `ThemeColors`,
`ThemeRadii`, `ThemeSpacing`, `ThemeMotion`, `ThemeTypography`, bundled as
`ThemeTokens`. Pure values, no widgets.

**`theming/theme_definition.dart`** — the contract. `AppThemeDefinition` is
the abstract class every theme implements: `tokens`, `buildMaterialTheme()`,
`buildBackground()`, `buildSurface()`, and — all optional, all with working
defaults — `buildIconPlate()`, `buildReveal()`, `buildProgressFill()` and
`buildPageTransition()`. `SurfaceRequest`, `BackgroundRequest`,
`RevealRequest` and `ProgressFillRequest` are what the app hands a theme —
read them before writing a theme, they're the entire input you get.

**`theming/theme_scope.dart` / `theme_registry.dart` / `theme_controller.dart`**
— plumbing. `ThemeScope` is an `InheritedWidget` installed in
`MaterialApp.builder`, so every pushed route can see the active theme via
`context.appTheme` / `context.tokens` / `context.palette`. `ThemeRegistry` is
the list of shipped themes. `ThemeController` owns which one is active and
persists the choice (reusing the app's existing `SharedPreferences` store,
under its own keys).

**`widgets/themed/`** — `ThemedSurface`, `ThemedCard`, `ThemedButton`,
`ThemedChip`, `ThemedAppBar`, `ThemedProgressBar`, etc. Screens use these,
never a theme's internals directly. This is what keeps a screen from ever
needing to know which theme is active.

## Adding a theme: step by step

Say you want **Sakura Washi**. This is genuinely the whole job:

### 1. Create the folder

```
lib/themes/sakura_washi/
    sakura_washi_tokens.dart      colours, radii, spacing, typography
    sakura_washi_surface.dart     paints one SurfaceRequest
    sakura_washi_background.dart  paints one BackgroundRequest
    sakura_washi_theme.dart       the AppThemeDefinition itself
```

Copy `themes/zen_minimal/` as your starting skeleton if your theme is flat
and cheap; copy `themes/glass/` if it needs an expensive effect (blur, a
shader, an animated gradient) and you need to see how that theme respects
`request.allowHeavyEffects` and the global `effectsEnabled` switch;
`themes/tokyo_neon/` is the middle case — opaque and cheap to paint, with all
of its character in the interaction animations.

A theme may also add `<n>_motion.dart` for its `buildReveal` /
`buildProgressFill` implementations. See "Motion" below.

### 2. Write the tokens

```dart
const ThemeTokens kSakuraWashiTokens = ThemeTokens(
  colors: ThemeColors(
    accent: Color(0xFFE8A0B0),      // sakura pink
    onAccent: Color(0xFF3A2A2E),
    textPrimary: Color(0xFF2E2A26), // sumi ink
    textSecondary: ...,
    textTertiary: ...,
    good: ..., bad: ..., warn: ...,
    border: ...,
  ),
  radii: ThemeRadii(xs: ..., sm: ..., md: ..., lg: ..., xl: ...),
  spacing: ThemeSpacing(),   // defaults are almost always fine
  motion: ThemeMotion(curve: Curves.easeOut, pressScale: 1.0),
  text: ThemeTypography(
    jpFontFamily: 'NotoJP',  // keep this: it's the bundled font that
                             // guarantees every kana/kanji renders crisply
    jpColor: ...,
    display: TextStyle(...), title: TextStyle(...), ...
  ),
);
```

`jpFontFamily` should stay `'NotoJP'` unless you're bundling a different
Japanese-capable font as a theme asset (see "Theme assets" below) — this is
the one place legibility of the study content is non-negotiable.

### 3. Implement `buildSurface`

This is the heart of the theme. You receive a `SurfaceRequest` describing
the *role* (level, tint, selected, pressAmount, enabled, allowHeavyEffects)
and return a widget. Zen Minimal's implementation is the shortest example —
read it first. Glass's is the most involved — read it if your theme
needs a real effect.

Rules that keep a theme well-behaved:

- **Apply `width` / `height` with a `SizedBox` and pass the incoming
  constraints through untouched.** Both may be `double.infinity`, meaning
  "fill the parent on this axis", and a full-bleed panel inside a scroll view
  has an *unbounded* cross axis. Tightening against `constraints.biggest` —
  `StackFit.expand`, `BoxConstraints.tight(constraints.biggest)` — produces an
  infinite constraint there, the surface fails to lay out, and its content
  silently disappears. This is not hypothetical: it is exactly how the Glass
  theme once made every answer explanation in Practice and Radical vanish
  while Zen Minimal, which used a plain `AnimatedContainer`, looked fine. If
  you compose layers in a `Stack`, use `StackFit.passthrough`.
  `test/theme_surface_contract_test.dart` runs this case against every theme
  in the registry, so you will find out at test time rather than from a user.
- Respect `allowHeavyEffects == false` and the effects-off case
  (`ThemeScope.effectsEnabledOf(context)`) by falling back to something
  cheap. Layout and contrast must stay the same either way.
- Respect `request.selected` with something other than colour alone (a
  stronger border, an icon) — colour-blind users need it too.
- Don't read services, models, or anything outside the `SurfaceRequest`.

### 4. Implement `buildBackground`

You get a `BackgroundRequest`: either `userBackground` is a widget already
painting the user's photo/colour choice (apply your own readability veil on
top of it), or it's `null`, meaning "app default" — paint your own signature
backdrop. Don't reach into `SettingsService` yourself; the request is the
whole interface.

### 5. Write the `AppThemeDefinition`

```dart
class SakuraWashiTheme extends AppThemeDefinition {
  static const String themeId = 'sakura_washi';

  const SakuraWashiTheme();

  @override String get id => themeId;
  @override String get name => 'Sakura Washi';
  @override String get description => '...';
  @override ThemePreview get preview => const ThemePreview(swatch: [...], icon: ...);
  @override ThemeTokens get tokens => kSakuraWashiTokens;

  @override
  ThemeData buildMaterialTheme() { ... } // sliders, switches, snackbars

  @override
  Widget buildBackground(BuildContext c, BackgroundRequest r, Widget child) =>
      SakuraWashiBackground(request: r, child: child);

  @override
  Widget buildSurface(BuildContext c, SurfaceRequest r) =>
      SakuraWashiSurface(request: r);
}
```

`id` is persisted — never change it once shipped, *including when the theme
is renamed*. The Glass theme is still `liquid_glass` internally for exactly
this reason: the user-facing name changed, the id did not, and nobody lost
their selected theme on upgrade. If an id ever genuinely has to change, it
needs a migration step in `ThemeController.load` that rewrites the old value
before `ThemeRegistry.byId` falls the user back to the default.

### 6. Motion, if your theme wants its own

Override `buildReveal` and you get the theme's own animation language for
free everywhere the app reports something happening:

```dart
@override
Widget buildReveal(BuildContext context, RevealRequest request) =>
    MyThemeReveal(request: request);
```

`RevealRequest.moment` is one of `success`, `error`, `selection`,
`cardReveal`, `explanationReveal`, `kanjiReveal`, `radicalReveal`. The app
never says what the animation should be; it says what happened. Glass answers
a `success` with a soft bloom, Tokyo Neon with a neon pulse, Zen Minimal
takes the default fade.

Three rules, and the first is non-negotiable:

- **`request.child` must be in the tree, laid out, on the first frame.** An
  animation may change how content looks; it must never decide *whether*
  content exists. Wrap the child in opacity and transforms — never gate its
  construction on a controller, a timer or a callback. The reveal tests
  assert the child is findable before a single frame of animation has run.
- Pass the child through the builder's `child:` slot so it isn't rebuilt
  every frame, and drop your wrappers entirely once the animation settles
  (`if (v >= 1.0) return child!`). A revealed panel should cost nothing to
  keep on screen.
- Honour `MediaQuery.disableAnimations` and `request.allowHeavyEffects`.

`buildProgressFill` and `buildPageTransition` work the same way and both have
sensible defaults, so ignoring them is a valid choice.

### 7. Register it

One line in `lib/theming/theme_registry.dart`:

```dart
static const List<AppThemeDefinition> themes = <AppThemeDefinition>[
  GlassTheme(),
  ZenMinimalTheme(),
  TokyoNeonTheme(),
  SakuraWashiTheme(),   // <- this
];
```

It now appears in Settings → Theme automatically, with its `preview` as the
thumbnail. Nothing else changes: not a single screen file.

### 8. Add theme assets, if any

If the theme needs its own image (a washi paper texture, a pattern), put it
under `lib/themes/sakura_washi/assets/` and add the path to `pubspec.yaml`'s
asset list. Reference it only from inside that theme's own files. Keep
theme-specific assets small — every asset listed in `pubspec.yaml` ships in
the APK for everyone, whether or not they use that theme, so avoid bundling
anything heavy (large textures, video) for a theme most users won't select.

### 9. Build

That's it — commit and let the existing GitHub Actions workflow build the
APK as normal. No manual copying, no separate pipeline for themes.

## What must never live in a theme

A theme file must never import from `services/`, `models/`, or `screens/`,
and must never contain: scoring, spaced-repetition scheduling, data loading,
audio state, navigation decisions, or persistence. If a theme "needs" one of
these, it's a sign the app should be handing it a value through
`SurfaceRequest`/`BackgroundRequest` instead — extend those structs rather
than reaching around them.

## When the app itself changes

Adding a screen, a new kind of card, a streak calendar — none of it should
require touching every theme. If the new UI can be expressed with the
existing `ThemedSurface`/`ThemedCard`/`ThemedButton` vocabulary, it just
works, in every theme, immediately.

Only extend the contract (add a field to `SurfaceRequest`, or a new method to
`AppThemeDefinition`) when something is visually unprecedented — and even
then, give existing themes a sensible default so they don't all need an
edit on the same day.

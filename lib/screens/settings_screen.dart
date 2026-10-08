import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../notifications/notifications.dart';
import '../theming/theme_controller.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_registry.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'reminder_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _click(BuildContext context) =>
      context.read<AudioService>().playMenuClick();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsService>();
    final audio = context.watch<AudioService>();
    final themeController = context.watch<ThemeController>();
    final reminders = context.watch<NotificationSettingsService>();

    return Scaffold(
      body: AppBackground(
        // Wrapping the settings screen itself in AppBackground means every
        // change below is visible live, right behind these controls --
        // the same way WhatsApp lets you preview a chat wallpaper. It now
        // previews the theme too: tapping one repaints this screen instantly.
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
                    t.spacing.xxl,
                  ),
                  children: [
                    // --- Appearance -------------------------------------
                    // A compact row rather than the full list: themes are
                    // chosen rarely, and every extra permanent card here
                    // pushes Background and Sound further off the screen.
                    const ThemedSectionLabel('Appearance'),
                    _ThemeSelectorTile(
                      definition: themeController.theme,
                      onTap: () => _openThemePicker(context),
                    ),
                    SizedBox(height: t.spacing.md),
                    ThemedSurface(
                      level: SurfaceLevel.standard,
                      radius: t.radii.md,
                      padding: EdgeInsets.all(t.spacing.sm),
                      child: _effectsToggleTile(context, themeController),
                    ),

                    SizedBox(height: t.spacing.xl),

                    // --- Background -------------------------------------
                    const ThemedSectionLabel('Background'),
                    ThemedSurface(
                      level: SurfaceLevel.standard,
                      radius: t.radii.md,
                      padding: EdgeInsets.all(t.spacing.sm),
                      child: Column(
                        children: [
                          _defaultTile(context, settings),
                          SizedBox(height: t.spacing.xs),
                          _photoTile(context, settings),
                          SizedBox(height: t.spacing.md),
                          _colorGrid(context, settings),
                          if (settings.backgroundType !=
                              BackgroundType.appDefault) ...[
                            SizedBox(height: t.spacing.xs),
                            _sliderRow(
                              context,
                              label: 'Dimness',
                              hint: 'keeps text readable',
                              valueLabel:
                                  '${(settings.overlayOpacity * 100).round()}%',
                              value: settings.overlayOpacity,
                              min: 0.0,
                              max: 0.9,
                              onChanged: (v) => context
                                  .read<SettingsService>()
                                  .setOverlayOpacity(v),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: t.spacing.xl),

                    // --- Sound ------------------------------------------
                    const ThemedSectionLabel('Sound'),
                    ThemedSurface(
                      level: SurfaceLevel.standard,
                      radius: t.radii.md,
                      padding: EdgeInsets.all(t.spacing.sm),
                      child: Column(
                        children: [
                          _musicToggleTile(context, audio),
                          if (audio.menuMusicEnabled) ...[
                            SizedBox(height: t.spacing.xs),
                            _sliderRow(
                              context,
                              label: 'Menu music volume',
                              valueLabel:
                                  '${(audio.menuMusicVolume * 100).round()}%',
                              value: audio.menuMusicVolume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (v) => context
                                  .read<AudioService>()
                                  .setMenuMusicVolume(v),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: t.spacing.xl),

                    // --- Reminders --------------------------------------
                    const ThemedSectionLabel('Reminders'),
                    ThemedSurface(
                      level: SurfaceLevel.standard,
                      radius: t.radii.md,
                      padding: EdgeInsets.all(t.spacing.sm),
                      child: _remindersTile(context, reminders),
                    ),

                    SizedBox(height: t.spacing.xl),

                    // --- Progress ---------------------------------------
                    const ThemedSectionLabel('Your progress'),
                    _statsCard(context, settings),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A labelled slider inside a section. `allowHeavyEffects` is off on the
  /// rows because the section around them is already the expensive surface;
  /// nesting a theme's heavy effect inside itself is the fastest way to make
  /// a settings list stutter.
  Widget _sliderRow(
    BuildContext context, {
    required String label,
    String? hint,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.spacing.xs, t.spacing.xs, t.spacing.xs, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hint == null ? label : '$label — $hint',
                  style: t.text.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: t.spacing.xs),
              Text(
                valueLabel,
                style: t.text.caption.copyWith(
                  color: t.colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// The performance escape hatch. Themes with an expensive signature effect
  /// fall back to a cheap path; layout, colours and contrast stay identical.
  Widget _effectsToggleTile(BuildContext context, ThemeController controller) {
    final t = context.tokens;
    final on = controller.effectsEnabled;
    return _innerTile(
      context,
      selected: on,
      child: Row(
        children: [
          ThemedIconPlate(
            icon: on ? Icons.auto_awesome_rounded : Icons.speed_rounded,
            color: on ? t.colors.accent : t.colors.textTertiary,
            size: 38,
            iconSize: 18,
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Visual effects', style: t.text.body),
                const SizedBox(height: 2),
                Text(
                  on
                      ? 'Full effects, including backdrop blur'
                      : 'Reduced — lighter on older phones',
                  style: t.text.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: (v) {
              _click(context);
              context.read<ThemeController>().setEffectsEnabled(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _musicToggleTile(BuildContext context, AudioService audio) {
    final t = context.tokens;
    return _innerTile(
      context,
      selected: audio.menuMusicEnabled,
      child: Row(
        children: [
          ThemedIconPlate(
            icon: audio.menuMusicEnabled
                ? Icons.music_note_rounded
                : Icons.music_off_rounded,
            color: audio.menuMusicEnabled
                ? t.colors.accent
                : t.colors.textTertiary,
            size: 38,
            iconSize: 18,
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(child: Text('Menu music', style: t.text.body)),
          Switch(
            value: audio.menuMusicEnabled,
            onChanged: (v) {
              _click(context);
              context.read<AudioService>().setMenuMusicEnabled(v);
            },
          ),
        ],
      ),
    );
  }

  /// Entry point to the study-reminders screen, with a one-line summary.
  Widget _remindersTile(
    BuildContext context,
    NotificationSettingsService reminders,
  ) {
    final t = context.tokens;
    final active = reminders.reminders.where((r) => r.enabled).length;
    final on = reminders.enabled;
    final summary = !on
        ? 'Off'
        : active == 0
            ? 'No reminders set'
            : '$active reminder${active == 1 ? '' : 's'} on';
    return _innerTile(
      context,
      selected: on && active > 0,
      onTap: () {
        _click(context);
        Navigator.of(context).push(
          themedRoute(context, (_) => const ReminderSettingsScreen()),
        );
      },
      child: Row(
        children: [
          ThemedIconPlate(
            icon: on && active > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: on && active > 0 ? t.colors.accent : t.colors.textTertiary,
            size: 38,
            iconSize: 18,
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Study reminders', style: t.text.body),
                const SizedBox(height: 2),
                Text(summary, style: t.text.caption),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: t.colors.textSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _defaultTile(BuildContext context, SettingsService settings) {
    final t = context.tokens;
    final selected = settings.backgroundType == BackgroundType.appDefault;
    return _innerTile(
      context,
      selected: selected,
      onTap: () {
        _click(context);
        context.read<SettingsService>().setBackgroundDefault();
      },
      child: Row(
        children: [
          ThemedIconPlate(
            icon: Icons.auto_awesome_mosaic_outlined,
            color: t.colors.accent,
            size: 38,
            iconSize: 18,
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Theme's own backdrop", style: t.text.body),
                const SizedBox(height: 2),
                Text(
                  'Changes with the theme you pick above',
                  style: t.text.caption,
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded,
                color: t.colors.accent, size: 20),
        ],
      ),
    );
  }

  Widget _colorGrid(BuildContext context, SettingsService settings) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solid colour', style: t.text.caption),
          SizedBox(height: t.spacing.xs),
          Wrap(
            spacing: t.spacing.sm,
            runSpacing: t.spacing.sm,
            children: List.generate(kBackgroundColorPresets.length, (index) {
              final color = kBackgroundColorPresets[index];
              final selected =
                  settings.backgroundType == BackgroundType.color &&
                      settings.backgroundColorIndex == index;
              return GestureDetector(
                onTap: () {
                  _click(context);
                  context
                      .read<SettingsService>()
                      .setBackgroundColorIndex(index);
                },
                child: AnimatedContainer(
                  duration: t.motion.fast,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? t.colors.accent : t.colors.border,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(BuildContext context, SettingsService settings) {
    final t = context.tokens;
    final selected = settings.backgroundType == BackgroundType.photo;
    return _innerTile(
      context,
      selected: selected,
      onTap: () async {
        _click(context);
        final ok = await context.read<SettingsService>().pickBackgroundPhoto();
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No photo selected')),
          );
        }
      },
      child: Row(
        children: [
          ThemedIconPlate(
            icon: Icons.photo_outlined,
            color: t.colors.accent,
            size: 38,
            iconSize: 18,
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Text(
              'Choose a photo from your gallery',
              style: t.text.body,
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded,
                color: t.colors.accent, size: 20),
        ],
      ),
    );
  }

  /// A row inside a section.
  Widget _innerTile(
    BuildContext context, {
    required bool selected,
    VoidCallback? onTap,
    required Widget child,
  }) {
    final t = context.tokens;
    return ThemedCard(
      onTap: onTap,
      level: SurfaceLevel.subtle,
      radius: t.radii.sm,
      allowHeavyEffects: false,
      showShadow: false,
      tint: selected ? t.colors.accent : null,
      tintStrength: 0.55,
      selected: selected,
      padding: EdgeInsets.all(t.spacing.sm),
      child: child,
    );
  }

  Widget _statsCard(BuildContext context, SettingsService settings) {
    final t = context.tokens;
    final answered = settings.statsAnsweredTotal;
    final correct = settings.statsCorrectTotal;
    final pct = answered == 0 ? 0 : (100 * correct / answered).round();
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statColumn(context, '$answered', 'Answered'),
          _statColumn(context, '$correct', 'Correct'),
          _statColumn(context, '$pct%', 'Accuracy'),
        ],
      ),
    );
  }

  Widget _statColumn(BuildContext context, String value, String label) {
    final t = context.tokens;
    return Column(
      children: [
        Text(
          value,
          style: t.text.title.copyWith(
            color: t.colors.accent,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: t.text.caption),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Settings',
      subtitle: '設定',
      onLeadingTap: () {
        _click(context);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Opens the theme picker.
///
/// A bottom sheet rather than a dialog: it is thumb-reachable, it grows with
/// the number of themes without ever needing a scrollbar for three of them,
/// and it leaves most of the screen visible — which matters here, because
/// tapping a theme applies it immediately and the app repaints *behind* the
/// sheet. The choice is previewed for real, not as a swatch.
Future<void> _openThemePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    isScrollControlled: true,
    builder: (_) => const _ThemePickerSheet(),
  );
}

/// The collapsed Theme row: current theme, its swatch, and a chevron.
class _ThemeSelectorTile extends StatelessWidget {
  final AppThemeDefinition definition;
  final VoidCallback onTap;

  const _ThemeSelectorTile({required this.definition, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ThemedCard(
      onTap: onTap,
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      padding: EdgeInsets.all(t.spacing.sm + 2),
      semanticLabel: 'Theme. Currently ${definition.name}. Tap to change.',
      child: Row(
        children: [
          _Swatch(
            colors: definition.preview.swatch,
            icon: definition.preview.icon,
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Theme', style: t.text.caption),
                const SizedBox(height: 2),
                Text(
                  definition.name,
                  style: t.text.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Icon(
            Icons.expand_more_rounded,
            color: t.colors.textSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }
}

/// The picker itself.
///
/// Watches [ThemeController], so when a theme is chosen the sheet restyles
/// itself along with the rest of the app instead of staying in the old
/// theme's clothes until it is dismissed.
class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final controller = context.watch<ThemeController>();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(t.spacing.sm),
        child: ThemedSurface(
          level: SurfaceLevel.elevated,
          radius: t.radii.lg,
          padding: EdgeInsets.all(t.spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select theme', style: t.text.title),
              SizedBox(height: t.spacing.sm),
              ...ThemeRegistry.themes.map(
                (theme) => Padding(
                  padding: EdgeInsets.only(bottom: t.spacing.xs),
                  child: _ThemeOption(
                    definition: theme,
                    selected: theme.id == controller.themeId,
                    onTap: () {
                      context.read<AudioService>().playMenuClick();
                      // Applied immediately, and persisted by the controller
                      // exactly as before — the selector changed, not the
                      // storage behind it.
                      context.read<ThemeController>().setThemeId(theme.id);
                    },
                  ),
                ),
              ),
              SizedBox(height: t.spacing.xs),
              ThemedButton(
                label: 'Done',
                variant: ThemedButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in the theme picker, with a small live swatch so the choice is
/// visible before committing to it.
class _ThemeOption extends StatelessWidget {
  final AppThemeDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final preview = definition.preview;

    return ThemedCard(
      onTap: onTap,
      level: selected ? SurfaceLevel.elevated : SurfaceLevel.standard,
      radius: t.radii.md,
      tint: selected ? t.colors.accent : null,
      tintStrength: 0.6,
      selected: selected,
      padding: EdgeInsets.all(t.spacing.sm + 2),
      semanticLabel: '${definition.name}. ${definition.description}',
      child: Row(
        children: [
          _Swatch(colors: preview.swatch, icon: preview.icon),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(definition.name, style: t.text.cardTitle),
                const SizedBox(height: 2),
                Text(
                  definition.description,
                  style: t.text.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? t.colors.accent : t.colors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// A theme's thumbnail: its own colours, drawn cheaply, without having to
/// instantiate the theme's real surfaces.
class _Swatch extends StatelessWidget {
  final List<Color> colors;
  final IconData icon;

  const _Swatch({required this.colors, required this.icon});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radii.sm),
        border: Border.all(color: t.colors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.length >= 2 ? colors : [...colors, ...colors],
        ),
      ),
      child: Icon(
        icon,
        size: 22,
        color: colors.length > 2 ? colors.last : Colors.white,
      ),
    );
  }
}

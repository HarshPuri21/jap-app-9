import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifications/notifications.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

/// The study-reminders screen, in the app's own visual language.
///
/// The notification package ships a plain Material screen on purpose (it must
/// not depend on this app's theme system). This is the host-side version: it
/// uses the same themed components as Settings, and drives the package's
/// [NotificationSettingsService] and [NotificationService] unchanged.
///
/// Every call into the notification subsystem is guarded. A failure becomes a
/// snackbar; it never throws into the framework.
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen>
    with WidgetsBindingObserver {
  /// Whether Android currently lets this app post notifications. Null until
  /// known (or if it could not be determined).
  bool? _osAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshOsPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have just flipped the switch in Android's system settings.
    if (state == AppLifecycleState.resumed) _refreshOsPermission();
  }

  Future<void> _refreshOsPermission() async {
    try {
      final allowed =
          await NotificationService.instance.areNotificationsEnabled();
      if (mounted) setState(() => _osAllowed = allowed);
    } catch (e) {
      debugPrint('ReminderSettingsScreen: permission check failed: $e');
    }
  }

  void _click() => context.read<AudioService>().playMenuClick();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs [action], turning any failure into a message instead of an
  /// unhandled exception.
  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('ReminderSettingsScreen: action failed: $e');
      _toast("Couldn't update reminders. Please try again.");
    }
  }

  /// Asks Android for notification permission (from a user tap, as Android 13+
  /// requires). Returns false, with an explanation, when it isn't granted.
  Future<bool> _ensurePermission() async {
    try {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        _toast(
          'Notification permission was not granted. You can allow it in '
          'Android settings to receive reminders.',
        );
      }
      await _refreshOsPermission();
      return granted;
    } catch (e) {
      debugPrint('ReminderSettingsScreen: permission request failed: $e');
      _toast("Couldn't ask for notification permission.");
      return false;
    }
  }

  Future<void> _setEnabled(bool value) => _guarded(() async {
        _click();
        final service = context.read<NotificationSettingsService>();
        if (value && !await _ensurePermission()) return;
        await service.setEnabled(value);
      });

  Future<void> _toggleReminder(ReminderSchedule reminder, bool value) =>
      _guarded(() async {
        _click();
        final service = context.read<NotificationSettingsService>();
        if (value && service.enabled && !await _ensurePermission()) return;
        await service.toggleReminder(reminder.id, value);
      });

  Future<void> _deleteReminder(ReminderSchedule reminder) => _guarded(() async {
        _click();
        await context
            .read<NotificationSettingsService>()
            .removeReminder(reminder.id);
      });

  Future<void> _openEditor({ReminderSchedule? existing}) async {
    _click();
    final draft = await showModalBottomSheet<_ReminderDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      isScrollControlled: true,
      builder: (_) => _ReminderEditorSheet(existing: existing),
    );
    if (draft == null || !mounted) return;

    await _guarded(() async {
      final service = context.read<NotificationSettingsService>();
      if (service.enabled && !await _ensurePermission()) return;
      if (existing == null) {
        await service.addReminder(
          hour: draft.hour,
          minute: draft.minute,
          weekdays: draft.weekdays,
          label: draft.label,
        );
      } else {
        await service.updateReminder(
          existing.copyWith(
            hour: draft.hour,
            minute: draft.minute,
            weekdays: draft.weekdays,
            label: draft.label,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final service = context.watch<NotificationSettingsService>();
    final reminders = service.reminders;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              ThemedAppBar(
                title: 'Reminders',
                subtitle: 'リマインダー',
                onLeadingTap: () {
                  _click();
                  Navigator.of(context).pop();
                },
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xxl,
                  ),
                  children: [
                    ThemedSurface(
                      level: SurfaceLevel.standard,
                      radius: t.radii.md,
                      padding: EdgeInsets.all(t.spacing.sm),
                      child: _masterToggle(context, service),
                    ),
                    if (service.enabled && _osAllowed == false) ...[
                      SizedBox(height: t.spacing.sm),
                      _permissionWarning(context),
                    ],
                    SizedBox(height: t.spacing.xl),
                    const ThemedSectionLabel('Study times'),
                    if (reminders.isEmpty)
                      _emptyState(context)
                    else
                      for (final reminder in reminders) ...[
                        _reminderCard(context, service, reminder),
                        SizedBox(height: t.spacing.sm),
                      ],
                    SizedBox(height: t.spacing.md),
                    ThemedButton(
                      label: 'Add reminder',
                      icon: Icons.add_alarm_rounded,
                      onPressed: _openEditor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _masterToggle(
    BuildContext context,
    NotificationSettingsService service,
  ) {
    final t = context.tokens;
    final on = service.enabled;
    return ThemedCard(
      level: SurfaceLevel.subtle,
      radius: t.radii.sm,
      allowHeavyEffects: false,
      showShadow: false,
      tint: on ? t.colors.accent : null,
      tintStrength: 0.55,
      selected: on,
      padding: EdgeInsets.all(t.spacing.sm),
      child: Row(
        children: [
          ThemedIconPlate(
            icon: on
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
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
                Text('Study reminders', style: t.text.body),
                const SizedBox(height: 2),
                Text(
                  on
                      ? 'Get notified at your chosen study times'
                      : 'Off — your schedules are kept and return when '
                          'you turn this on',
                  style: t.text.caption,
                ),
              ],
            ),
          ),
          Switch(value: on, onChanged: _setEnabled),
        ],
      ),
    );
  }

  Widget _permissionWarning(BuildContext context) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      tint: t.colors.warn,
      tintStrength: 0.5,
      padding: EdgeInsets.all(t.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: t.colors.warn, size: 20),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Text(
              'Notifications are turned off for this app in Android settings, '
              "so reminders won't appear until you allow them.",
              style: t.text.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      padding: EdgeInsets.all(t.spacing.lg),
      child: Column(
        children: [
          ThemedIconPlate(
            icon: Icons.alarm_add_rounded,
            color: t.colors.accent,
            size: 46,
            iconSize: 22,
          ),
          SizedBox(height: t.spacing.sm),
          Text(
            'No reminders yet',
            textAlign: TextAlign.center,
            style: t.text.cardTitle,
          ),
          const SizedBox(height: 2),
          Text(
            'Add a study time and pick the days you want a nudge.',
            textAlign: TextAlign.center,
            style: t.text.caption,
          ),
        ],
      ),
    );
  }

  Widget _reminderCard(
    BuildContext context,
    NotificationSettingsService service,
    ReminderSchedule reminder,
  ) {
    final t = context.tokens;
    final active = reminder.enabled && service.enabled;
    return ThemedCard(
      onTap: () => _openEditor(existing: reminder),
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      padding: EdgeInsets.all(t.spacing.sm),
      semanticLabel:
          '${formatTimeOfDay(reminder.hour, reminder.minute)} '
          '${reminder.displayLabel}. Tap to edit.',
      child: Row(
        children: [
          ThemedIconPlate(
            icon: active ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
            color: active ? t.colors.accent : t.colors.textTertiary,
            size: 38,
            iconSize: 18,
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${formatTimeOfDay(reminder.hour, reminder.minute)}'
                  ' · ${reminder.displayLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.cardTitle,
                ),
                const SizedBox(height: 2),
                Text(_daysText(reminder.weekdays), style: t.text.caption),
              ],
            ),
          ),
          Switch(
            value: reminder.enabled,
            onChanged: (v) => _toggleReminder(reminder, v),
          ),
          ThemedIconButton(
            icon: Icons.delete_outline_rounded,
            size: 36,
            iconSize: 18,
            tooltip: 'Delete reminder',
            onPressed: () => _deleteReminder(reminder),
          ),
        ],
      ),
    );
  }
}

String _daysText(Set<int> weekdays) {
  final days = weekdays.toList()..sort();
  if (days.length == 7) return 'Every day';
  return days.map((d) => kWeekdayShortLabels[d - 1]).join(' ');
}

class _ReminderDraft {
  const _ReminderDraft(this.hour, this.minute, this.weekdays, this.label);

  final int hour;
  final int minute;
  final Set<int> weekdays;
  final String label;
}

/// Bottom-sheet editor, styled like the theme picker in Settings.
class _ReminderEditorSheet extends StatefulWidget {
  const _ReminderEditorSheet({this.existing});

  final ReminderSchedule? existing;

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _time = TimeOfDay(hour: e?.hour ?? 8, minute: e?.minute ?? 0);
    _weekdays = Set<int>.of(e?.weekdays ?? const {1, 2, 3, 4, 5, 6, 7});
    _labelController = TextEditingController(text: e?.label ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _toggleDay(int day) {
    setState(() {
      if (!_weekdays.add(day)) _weekdays.remove(day);
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _ReminderDraft(
        _time.hour,
        _time.minute,
        Set<int>.unmodifiable(_weekdays),
        _labelController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(t.spacing.sm),
          child: ThemedSurface(
            level: SurfaceLevel.elevated,
            radius: t.radii.lg,
            padding: EdgeInsets.all(t.spacing.md),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.existing == null ? 'New reminder' : 'Edit reminder',
                    style: t.text.title,
                  ),
                  SizedBox(height: t.spacing.md),
                  ThemedSurface(
                    level: SurfaceLevel.standard,
                    radius: t.radii.sm,
                    allowHeavyEffects: false,
                    padding: EdgeInsets.zero,
                    child: TextField(
                      controller: _labelController,
                      maxLength: 60,
                      style: t.text.body,
                      cursorColor: t.colors.accent,
                      decoration: InputDecoration(
                        hintText: 'Label (optional), e.g. Morning kanji',
                        hintStyle: t.text.secondary,
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: t.spacing.sm),
                  ThemedCard(
                    onTap: _pickTime,
                    level: SurfaceLevel.subtle,
                    radius: t.radii.sm,
                    allowHeavyEffects: false,
                    showShadow: false,
                    padding: EdgeInsets.all(t.spacing.sm),
                    semanticLabel: 'Time. Tap to change.',
                    child: Row(
                      children: [
                        ThemedIconPlate(
                          icon: Icons.schedule_rounded,
                          color: t.colors.accent,
                          size: 38,
                          iconSize: 18,
                        ),
                        SizedBox(width: t.spacing.sm),
                        Expanded(child: Text('Time', style: t.text.body)),
                        Text(
                          formatTimeOfDay(_time.hour, _time.minute),
                          style: t.text.cardTitle.copyWith(
                            color: t.colors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: t.spacing.md),
                  const ThemedSectionLabel('Days'),
                  Wrap(
                    spacing: t.spacing.xs,
                    runSpacing: t.spacing.xs,
                    children: [
                      for (var i = 0; i < 7; i++)
                        ThemedChip(
                          label: kWeekdayShortLabels[i],
                          selected: _weekdays.contains(i + 1),
                          onTap: () => _toggleDay(i + 1),
                        ),
                    ],
                  ),
                  SizedBox(height: t.spacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: ThemedButton(
                          label: 'Cancel',
                          variant: ThemedButtonVariant.secondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: t.spacing.sm),
                      Expanded(
                        child: ThemedButton(
                          label: 'Save',
                          onPressed: _weekdays.isEmpty ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

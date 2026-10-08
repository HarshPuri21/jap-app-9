import 'package:flutter/material.dart';

import '../models/reminder_schedule.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';

/// Host-app agnostic settings screen. Pass the service owned by the host app;
/// this package does not depend on Provider/Riverpod or the app's theme system.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.service,
  });

  final NotificationSettingsService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Study Reminders')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SwitchListTile(
              title: const Text('Reminders'),
              subtitle: const Text('Get notified at your chosen study times'),
              value: service.enabled,
              onChanged: (value) => _setGlobalEnabled(context, value),
            ),
            const SizedBox(height: 8),
            if (service.reminders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No reminders yet. Add one below.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...service.reminders.map(
                (r) => _ReminderTile(
                  reminder: r,
                  service: service,
                  onTap: () => _openReminderEditor(context, existing: r),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openReminderEditor(context),
          icon: const Icon(Icons.add_alarm),
          label: const Text('Add reminder'),
        ),
      ),
    );
  }

  Future<void> _setGlobalEnabled(BuildContext context, bool value) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission was not granted.'),
            ),
          );
        }
        return;
      }
    }
    await service.setEnabled(value);
  }

  Future<void> _openReminderEditor(
    BuildContext context, {
    ReminderSchedule? existing,
  }) async {
    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderEditorSheet(existing: existing),
    );
    if (result == null) return;

    if (service.enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission was not granted.'),
            ),
          );
        }
        return;
      }
    }

    if (existing == null) {
      await service.addReminder(
        hour: result.hour,
        minute: result.minute,
        weekdays: result.weekdays,
        label: result.label,
      );
    } else {
      await service.updateReminder(
        existing.copyWith(
          hour: result.hour,
          minute: result.minute,
          weekdays: result.weekdays,
          label: result.label,
        ),
      );
    }
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.service,
    required this.onTap,
  });

  final ReminderSchedule reminder;
  final NotificationSettingsService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = reminder.weekdays.toList()..sort();
    final dayText = days.length == 7
        ? 'Every day'
        : days.map((d) => kWeekdayShortLabels[d - 1]).join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          '${formatTimeOfDay(reminder.hour, reminder.minute)} · ${reminder.displayLabel}',
        ),
        subtitle: Text(dayText),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.enabled,
              onChanged: (v) => service.toggleReminder(reminder.id, v),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete reminder',
              onPressed: () => service.removeReminder(reminder.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorResult {
  const _EditorResult(this.hour, this.minute, this.weekdays, this.label);
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final String label;
}

class _ReminderEditorSheet extends StatefulWidget {
  const _ReminderEditorSheet({this.existing});
  final ReminderSchedule? existing;

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _time = TimeOfDay(hour: e?.hour ?? 8, minute: e?.minute ?? 0);
    _weekdays = Set.of(e?.weekdays ?? {1, 2, 3, 4, 5, 6, 7});
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
      if (_weekdays.contains(day)) {
        _weekdays.remove(day);
      } else {
        _weekdays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'New reminder' : 'Edit reminder',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. Morning kanji',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Time'),
            trailing: Text(
              _time.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text('Days')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final day = i + 1;
              return FilterChip(
                label: Text(kWeekdayShortLabels[i]),
                selected: _weekdays.contains(day),
                onSelected: (_) => _toggleDay(day),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _weekdays.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          _EditorResult(
                            _time.hour,
                            _time.minute,
                            Set.unmodifiable(_weekdays),
                            _labelController.text.trim(),
                          ),
                        ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

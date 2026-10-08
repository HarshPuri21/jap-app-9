import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_schedule.dart';
import 'notification_service.dart';

/// Persistent, UI-facing reminder state. The class deliberately depends only
/// on Flutter's ChangeNotifier and SharedPreferences so it can be hosted by
/// Provider, Riverpod adapters, GetIt, or another state-management system.
class NotificationSettingsService extends ChangeNotifier {
  static const _storageVersion = 1;
  static const _kReminders = 'notif_reminders_v$_storageVersion';
  static const _kEnabled = 'notif_enabled_v$_storageVersion';
  static const _kNextId = 'notif_next_id_v$_storageVersion';

  List<ReminderSchedule> _reminders = const [];
  bool _enabled = true;
  int _nextId = 1;
  Future<void> _mutationQueue = Future<void>.value();

  List<ReminderSchedule> get reminders => List.unmodifiable(_reminders);
  bool get enabled => _enabled;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabled) ?? true;
      _reminders = ReminderSchedule.listFromJsonString(
        prefs.getString(_kReminders),
      );
      _nextId = prefs.getInt(_kNextId) ?? _nextAvailableId();
      _nextId = _repairNextId(_nextId);
    } catch (e) {
      debugPrint('NotificationSettingsService.load failed: $e');
      _enabled = true;
      _reminders = const [];
      _nextId = 1;
    }

    notifyListeners();
    await NotificationService.instance.init();
    // A routine launch-time re-sync must not discard a pending 5-minute
    // snooze while reminders are enabled. When disabled, nothing of ours
    // should remain scheduled, snooze included.
    await NotificationService.instance.rescheduleAll(
      _enabled ? _reminders : const [],
      keepSnooze: _enabled,
    );
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, _enabled);
      await prefs.setInt(_kNextId, _nextId);
      await prefs.setString(
        _kReminders,
        ReminderSchedule.listToJsonString(_reminders),
      );
    } catch (e) {
      debugPrint('NotificationSettingsService.save failed: $e');
      rethrow;
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _mutationQueue.then((_) => operation());
    _mutationQueue = next.catchError((_) {});
    return next;
  }

  Future<void> setEnabled(bool value) => _enqueue(() async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    await _persist();

    if (value) {
      await NotificationService.instance.rescheduleAll(_reminders);
    } else {
      for (final reminder in _reminders) {
        await NotificationService.instance.cancelReminder(reminder);
      }
      // Also sweep anything of ours the OS still has pending (orphans from
      // corrupted storage). Only this subsystem's ID namespace is touched.
      await NotificationService.instance.cancelAllOwnedNotifications();
      await NotificationService.instance.cancelSnooze();
    }
  });

  Future<ReminderSchedule> addReminder({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    String label = '',
  }) async {
    late ReminderSchedule created;
    await _enqueue(() async {
      final id = _takeNextId();
      created = ReminderSchedule(
        id: id,
        hour: hour,
        minute: minute,
        weekdays: weekdays,
        label: label,
      );
      _reminders = [..._reminders, created];
      notifyListeners();
      await _persist();
      if (_enabled) await NotificationService.instance.scheduleReminder(created);
    });
    return created;
  }

  Future<void> updateReminder(ReminderSchedule updated) => _enqueue(() async {
    if (!_reminders.any((r) => r.id == updated.id)) return;
    _reminders = _reminders
        .map((r) => r.id == updated.id ? updated : r)
        .toList(growable: false);
    notifyListeners();
    await _persist();
    if (_enabled) {
      await NotificationService.instance.scheduleReminder(updated);
    } else {
      await NotificationService.instance.cancelReminder(updated);
    }
  });

  Future<void> removeReminder(int id) => _enqueue(() async {
    final removed = _reminders.where((r) => r.id == id).toList(growable: false);
    if (removed.isEmpty) return;
    _reminders = _reminders.where((r) => r.id != id).toList(growable: false);
    notifyListeners();
    await _persist();
    for (final reminder in removed) {
      await NotificationService.instance.cancelReminder(reminder);
    }
  });

  Future<void> toggleReminder(int id, bool value) {
    ReminderSchedule? target;
    for (final reminder in _reminders) {
      if (reminder.id == id) {
        target = reminder;
        break;
      }
    }
    if (target == null) return Future<void>.value();
    return updateReminder(target.copyWith(enabled: value));
  }

  int _takeNextId() {
    final id = _nextId;
    _nextId = id == 0x0FFFFFFF ? 1 : id + 1;
    return id;
  }

  int _nextAvailableId() {
    final ids = _reminders.map((r) => r.id).toSet();
    var id = 1;
    while (ids.contains(id)) {
      id++;
    }
    return id;
  }

  int _repairNextId(int candidate) {
    if (candidate < 1 || candidate > 0x0FFFFFFF) return _nextAvailableId();
    final used = _reminders.map((r) => r.id).toSet();
    var id = candidate;
    while (used.contains(id)) {
      id++;
      if (id > 0x0FFFFFFF) id = 1;
    }
    return id;
  }
}

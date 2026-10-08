import 'package:flutter_test/flutter_test.dart';

import 'package:nihongo_trainer/notifications/notifications.dart';

/// The reminder model is persisted (keys `notif_*_v1`), so its JSON handling
/// is part of the data-format contract: it must round-trip, tolerate bad
/// values, and never throw on corrupted storage.
void main() {
  group('ReminderSchedule JSON', () {
    test('round-trips every field', () {
      const original = ReminderSchedule(
        id: 4,
        hour: 7,
        minute: 5,
        weekdays: {5, 1, 3},
        enabled: false,
        label: 'Morning kanji',
      );
      final restored = ReminderSchedule.listFromJsonString(
        ReminderSchedule.listToJsonString([original]),
      ).single;

      expect(restored.id, 4);
      expect(restored.hour, 7);
      expect(restored.minute, 5);
      expect(restored.weekdays, {1, 3, 5});
      expect(restored.enabled, isFalse);
      expect(restored.label, 'Morning kanji');
    });

    test('clamps out-of-range times and drops invalid weekdays', () {
      final r = ReminderSchedule.fromJson({
        'id': 2,
        'hour': 99,
        'minute': -5,
        'weekdays': [0, 1, 7, 8, 12],
      });
      expect(r.hour, 23);
      expect(r.minute, 0);
      expect(r.weekdays, {1, 7});
    });

    test('missing fields fall back to sensible defaults', () {
      final r = ReminderSchedule.fromJson({'id': 1});
      expect(r.hour, 8);
      expect(r.minute, 0);
      expect(r.weekdays, {1, 2, 3, 4, 5, 6, 7});
      expect(r.enabled, isTrue);
      expect(r.label, '');
    });

    test('null, empty and corrupted storage become an empty list', () {
      expect(ReminderSchedule.listFromJsonString(null), isEmpty);
      expect(ReminderSchedule.listFromJsonString(''), isEmpty);
      expect(ReminderSchedule.listFromJsonString('not json'), isEmpty);
      expect(ReminderSchedule.listFromJsonString('{"a":1}'), isEmpty);
      expect(ReminderSchedule.listFromJsonString('[1,2,3]'), isEmpty);
    });
  });

  group('ReminderSchedule helpers', () {
    test('copyWith keeps the stable id', () {
      const r = ReminderSchedule(id: 9, hour: 8, minute: 0, weekdays: {1});
      final edited = r.copyWith(hour: 21, label: 'Evening');
      expect(edited.id, 9);
      expect(edited.hour, 21);
      expect(edited.label, 'Evening');
    });

    test('blank labels fall back to a generic name', () {
      const blank = ReminderSchedule(
          id: 1, hour: 8, minute: 0, weekdays: {1}, label: '   ');
      expect(blank.displayLabel, 'Study reminder');
    });

    test('formatTimeOfDay zero-pads', () {
      expect(formatTimeOfDay(8, 5), '08:05');
      expect(formatTimeOfDay(21, 30), '21:30');
    });
  });

  group('notification payload protocol', () {
    test('payloads are versioned and stable', () {
      expect(NotificationPayloads.reminder(12), 'v1:reminder:12');
      expect(NotificationPayloads.snooze(12), 'v1:snooze:12');
      expect(NotificationActionIds.snooze5Minutes, 'snooze_5min');
      expect(NotificationActionIds.ignore, 'ignore');
    });
  });
}

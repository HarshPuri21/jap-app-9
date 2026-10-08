import 'dart:convert';

/// Represents a single "study reminder" alarm the user has configured.
///
/// A schedule fires at [hour]:[minute] (24h, device local time) on every
/// weekday in [weekdays]. `weekdays` uses the same numbering as
/// `DateTime.weekday` -- 1 = Monday ... 7 = Sunday -- so it can be compared
/// directly against `DateTime.now().weekday` without a translation layer.
class ReminderSchedule {
  /// Small stable integer, unique within this app install. Doubles as the
  /// seed for the underlying OS notification ids (see NotificationService),
  /// so keep it small -- get it from [NotificationSettingsService], never
  /// invent one by hand.
  final int id;

  final int hour;
  final int minute;

  /// 1 (Monday) through 7 (Sunday), matching `DateTime.weekday`.
  final Set<int> weekdays;

  final bool enabled;

  /// Optional user-facing label, e.g. "Morning kanji" -- shown in the
  /// notification title and the reminder list. Falls back to a generic
  /// name when left blank.
  final String label;

  const ReminderSchedule({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekdays,
    this.enabled = true,
    this.label = '',
  });

  String get displayLabel =>
      label.trim().isEmpty ? 'Study reminder' : label.trim();

  ReminderSchedule copyWith({
    int? hour,
    int? minute,
    Set<int>? weekdays,
    bool? enabled,
    String? label,
  }) {
    return ReminderSchedule(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'weekdays': (weekdays.toList()..sort()),
        'enabled': enabled,
        'label': label,
      };

  factory ReminderSchedule.fromJson(Map<String, dynamic> json) {
    return ReminderSchedule(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hour: (((json['hour'] as int?) ?? 8).clamp(0, 23)).toInt(),
      minute: (((json['minute'] as int?) ?? 0).clamp(0, 59)).toInt(),
      weekdays: ((json['weekdays'] as List?) ?? const [1, 2, 3, 4, 5, 6, 7])
          .map((e) => (e as num).toInt())
          .where((d) => d >= 1 && d <= 7)
          .toSet(),
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String? ?? '',
    );
  }

  static List<ReminderSchedule> listFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => ReminderSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupted prefs shouldn't crash startup -- worst case the user
      // just sees an empty reminder list and can re-add them.
      return [];
    }
  }

  static String listToJsonString(List<ReminderSchedule> list) =>
      jsonEncode(list.map((r) => r.toJson()).toList());
}

/// Mon..Sun, index 0 = weekday 1 (Monday).
const List<String> kWeekdayShortLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// hour/minute -> "08:05" for list rows and notification bodies.
String formatTimeOfDay(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

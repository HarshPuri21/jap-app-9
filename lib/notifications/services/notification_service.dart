import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_schedule.dart';

/// Stable action identifiers. Do not change these after release; Android may
/// deliver them from already-created notifications after an app upgrade.
class NotificationActionIds {
  static const snooze5Minutes = 'snooze_5min';
  static const ignore = 'ignore';

  const NotificationActionIds._();
}

/// Stable payload prefixes. Payloads are versioned so future app releases can
/// add fields without making old notifications impossible to understand.
class NotificationPayloads {
  static const version = 'v1';
  static const reminderPrefix = '$version:reminder:';
  static const snoozePrefix = '$version:snooze:';

  static String reminder(int id) => '$reminderPrefix$id';
  static String snooze(int id) => '$snoozePrefix$id';

  const NotificationPayloads._();
}

const String _channelId = 'study_reminders';
const String _channelName = 'Study reminders';
const String _channelDescription =
    'Scheduled reminders to open the app and study.';

// Reserved namespace for snooze notifications. Reminder IDs use a separate
// deterministic namespace below, so future notification types cannot collide.
const int _snoozeNotificationId = 0x70000000;
const int _reminderIdBase = 0x10000000;
const int _weekdaySlots = 7;

/// App-agnostic local notification bridge.
///
/// The package deliberately does not know about Navigator, Provider, Riverpod,
/// themes, routes, or screens. The host app supplies [onNotificationOpened]
/// and decides what a normal notification tap means.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;
  void Function(String? payload)? onNotificationOpened;

  bool get isInitialized => _initialization != null;

  /// Initializes the plugin once. Safe to call from every entry point.
  ///
  /// [onNotificationOpened] is only replaced when a callback is actually
  /// supplied: internal callers invoke `init()` with no arguments, and that
  /// must never wipe the host app's tap handler.
  ///
  /// If initialization fails, the failure is reported to the caller but is
  /// not cached, so a later call can retry instead of failing forever.
  Future<void> init({void Function(String? payload)? onNotificationOpened}) {
    if (onNotificationOpened != null) {
      this.onNotificationOpened = onNotificationOpened;
    }
    final pending = _initialization ??= _initialize();
    return pending.catchError((Object error, StackTrace stackTrace) {
      if (identical(_initialization, pending)) _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await _setDeviceTimezone();

    const android = AndroidInitializationSettings('ic_notification');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _setDeviceTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Keep the timezone package's default rather than failing app startup.
      debugPrint('NotificationService: timezone lookup failed: $e');
    }
  }

  /// Must only be called from a user interaction on Android 13+.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Whether Android currently allows notifications for this app.
  Future<bool> areNotificationsEnabled() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  void _onForegroundResponse(NotificationResponse response) {
    final action = response.actionId;
    if (action == NotificationActionIds.snooze5Minutes) {
      unawaited(_scheduleSnooze(response.payload));
      return;
    }
    if (action == NotificationActionIds.ignore) return;
    onNotificationOpened?.call(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    if (response.actionId == NotificationActionIds.snooze5Minutes) {
      unawaited(_scheduleSnoozeFromBackground(response.payload));
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _scheduleSnoozeFromBackground(String? payload) async {
    final plugin = FlutterLocalNotificationsPlugin();
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {}

    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );

    final sourceId = _reminderIdFromPayload(payload);
    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));
    await plugin.zonedSchedule(
      id: _snoozeNotificationId,
      title: 'Study reminder (snoozed)',
      body: "You asked to be reminded again — it's time.",
      scheduledDate: when,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationPayloads.snooze(sourceId ?? 0),
    );
  }

  Future<void> _scheduleSnooze(String? payload) async {
    // Invoked via unawaited() from the notification callback, so an error
    // here would otherwise surface as an unhandled async exception.
    try {
      await init();
      final sourceId = _reminderIdFromPayload(payload);
      final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));
      await _plugin.zonedSchedule(
        id: _snoozeNotificationId,
        title: 'Study reminder (snoozed)',
        body: "You asked to be reminded again — it's time.",
        scheduledDate: when,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayloads.snooze(sourceId ?? 0),
      );
    } catch (e) {
      debugPrint('NotificationService: snooze failed: $e');
    }
  }

  Future<void> cancelSnooze() async {
    await init();
    await _plugin.cancel(id: _snoozeNotificationId);
  }

  NotificationDetails _details() => _notificationDetails();

  static NotificationDetails _notificationDetails() =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          actions: [
            AndroidNotificationAction(
              NotificationActionIds.snooze5Minutes,
              'Remind me in 5 min',
            ),
            AndroidNotificationAction(
              NotificationActionIds.ignore,
              'Ignore',
              cancelNotification: true,
            ),
          ],
        ),
      );

  static int _osIdFor(int reminderId, int weekday) {
    if (reminderId < 1 || weekday < 1 || weekday > 7) {
      throw ArgumentError('Invalid reminder id or weekday');
    }
    // 7 slots per reminder; IDs remain deterministic across app restarts.
    return _reminderIdBase + ((reminderId - 1) * _weekdaySlots) + (weekday - 1);
  }

  /// True only for OS notification IDs that this subsystem can have created:
  /// the reserved snooze slot, or the reminder namespace below it. Anything
  /// else (future notification types) belongs to someone else.
  static bool _isOwnedId(int id) =>
      id == _snoozeNotificationId ||
      (id >= _reminderIdBase && id < _snoozeNotificationId);

  /// Cancels every pending notification that belongs to this subsystem --
  /// including orphans whose reminder is no longer in storage (for example
  /// after corrupted preferences) -- by enumerating what the OS actually has
  /// pending and filtering to the owned ID namespace. This deliberately never
  /// calls cancelAll().
  ///
  /// Set [includeSnooze] to false to leave a pending snooze alone.
  Future<void> cancelAllOwnedNotifications({bool includeSnooze = true}) async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (!_isOwnedId(request.id)) continue;
      if (!includeSnooze && request.id == _snoozeNotificationId) continue;
      await _plugin.cancel(id: request.id);
    }
  }

  Future<void> cancelReminder(ReminderSchedule reminder) async {
    await init();
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _osIdFor(reminder.id, weekday));
    }
  }

  Future<void> scheduleReminder(ReminderSchedule reminder) async {
    await init();
    await cancelReminder(reminder);
    if (!reminder.enabled || reminder.weekdays.isEmpty) return;

    for (final weekday in reminder.weekdays) {
      final when = _nextInstance(reminder.hour, reminder.minute, weekday);
      await _plugin.zonedSchedule(
        id: _osIdFor(reminder.id, weekday),
        title: reminder.displayLabel,
        body: "It's time for your practice session.",
        scheduledDate: when,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: NotificationPayloads.reminder(reminder.id),
      );
    }
  }

  /// Reconciles only this package's own notification ID namespace (see
  /// [cancelAllOwnedNotifications]). It never calls cancelAll(), so future
  /// notification features owned by the host app are not accidentally
  /// deleted.
  ///
  /// A pending snooze is cancelled by default. Pass [keepSnooze] when this is
  /// just a routine re-sync (app launch with reminders enabled): otherwise
  /// opening the app within five minutes of tapping "Remind me in 5 min" would
  /// silently throw the snooze away.
  Future<void> rescheduleAll(
    List<ReminderSchedule> reminders, {
    bool keepSnooze = false,
  }) async {
    await init();
    await cancelAllOwnedNotifications(includeSnooze: !keepSnooze);
    for (final reminder in reminders) {
      await cancelReminder(reminder);
    }
    if (!keepSnooze) await cancelSnooze();
    for (final reminder in reminders) {
      if (reminder.enabled) await scheduleReminder(reminder);
    }
  }

  tz.TZDateTime _nextInstance(int hour, int minute, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static int? _reminderIdFromPayload(String? payload) {
    if (payload == null) return null;
    final prefix = NotificationPayloads.reminderPrefix;
    if (payload.startsWith(prefix)) {
      return int.tryParse(payload.substring(prefix.length));
    }
    final snoozePrefix = NotificationPayloads.snoozePrefix;
    if (payload.startsWith(snoozePrefix)) {
      return int.tryParse(payload.substring(snoozePrefix.length));
    }
    return int.tryParse(payload);
  }

  Future<String?> getLaunchPayload() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  /// Call this after the host app has a Navigator/Router ready. This avoids a
  /// race where a cold-start notification is detected before the first frame.
  Future<void> handleLaunchIfPresent() async {
    final payload = await getLaunchPayload();
    if (payload != null) onNotificationOpened?.call(payload);
  }
}

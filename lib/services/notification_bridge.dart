import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../notifications/notifications.dart';
import '../screens/daily_review_summary_screen.dart';
import '../widgets/themed/themed_motion.dart';

/// Key for the app's root Navigator. Installed on MaterialApp in main.dart so
/// code that has no BuildContext -- a notification tap -- can still navigate.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Where the app can send the user in response to a notification. Adding a
/// new notification type means adding a value here and a case in
/// [destinationForNotificationPayload]; nothing in `lib/notifications/`
/// needs to change.
enum NotificationDestination { dailyReview }

/// Interprets a notification payload. The notification package reports
/// payloads but deliberately never decides what they mean -- that is host
/// policy, and it lives here.
///
/// Payloads are versioned protocol data, so this routes on the versioned
/// prefixes the package publishes rather than on ad-hoc string matching, and
/// returns null (do not navigate) for anything it does not recognise, such
/// as a payload written by a future version.
@visibleForTesting
NotificationDestination? destinationForNotificationPayload(String? payload) {
  if (payload == null) return null;
  if (payload.startsWith(NotificationPayloads.reminderPrefix) ||
      payload.startsWith(NotificationPayloads.snoozePrefix)) {
    return NotificationDestination.dailyReview;
  }
  return null;
}

/// Glue between the notification subsystem and the rest of the app.
///
/// Everything here is non-fatal by design: a failure in notification setup,
/// timezone lookup, permission handling or scheduling is logged and
/// swallowed, and must never stop the app from launching.
class NotificationBridge {
  /// All parameters are optional seams for tests; the defaults are the real
  /// notification service and the app's root Navigator.
  NotificationBridge({
    bool Function(NotificationDestination destination)? navigate,
    Future<String?> Function()? readLaunchPayload,
    Future<void> Function(void Function(String? payload) onOpened)?
        initializeService,
    Future<void> Function(NotificationSettingsService settings)? loadSettings,
    Duration duplicateWindow = const Duration(seconds: 2),
  })  : _navigate = navigate ?? _navigateWithAppNavigator,
        _readLaunchPayload = readLaunchPayload ??
            (() => NotificationService.instance.getLaunchPayload()),
        _initializeService = initializeService ??
            ((onOpened) => NotificationService.instance
                .init(onNotificationOpened: onOpened)),
        _loadSettings = loadSettings ?? ((settings) => settings.load()),
        _duplicateWindow = duplicateWindow;

  static final NotificationBridge instance = NotificationBridge();

  /// Returns true if the navigation actually happened.
  final bool Function(NotificationDestination) _navigate;
  final Future<String?> Function() _readLaunchPayload;
  final Future<void> Function(void Function(String? payload) onOpened)
      _initializeService;
  final Future<void> Function(NotificationSettingsService settings)
      _loadSettings;
  final Duration _duplicateWindow;

  bool _uiReady = false;
  bool _startAttempted = false;
  bool _launchChecked = false;
  NotificationDestination? _pending;

  String? _lastPayload;
  DateTime? _lastPayloadAt;

  /// Initializes the notification subsystem and restores saved schedules.
  ///
  /// Order matters: [NotificationService] must be initialized before
  /// [NotificationSettingsService.load], because loading reschedules. Never
  /// throws. Call without awaiting from startup so the splash is not held up.
  Future<void> start(NotificationSettingsService settings) async {
    if (_startAttempted) return;
    _startAttempted = true;

    try {
      await _initializeService(onNotificationOpened);
    } catch (e) {
      debugPrint('NotificationBridge: notification init failed: $e');
    }

    try {
      // Loads saved settings first, then reschedules. If rescheduling fails
      // the saved settings are already in memory, so the UI still shows
      // the user's reminders.
      await _loadSettings(settings);
    } catch (e) {
      debugPrint('NotificationBridge: loading reminders failed: $e');
    }

    _maybeHandleLaunch();
  }

  /// Call once the app's Navigator is showing real content (Home), so a tap
  /// can push a screen. Payloads that arrived earlier are delivered now.
  void markUiReady() {
    _uiReady = true;
    final pending = _pending;
    if (pending != null && _navigate(pending)) _pending = null;
    _maybeHandleLaunch();
  }

  /// Receives every notification-body tap from the package, while the app is
  /// running in the foreground or background.
  void onNotificationOpened(String? payload) {
    final destination = destinationForNotificationPayload(payload);
    if (destination == null) return;
    if (_isDuplicate(payload)) return;
    _deliver(destination);
  }

  /// Cold start: the tap that launched a previously terminated app. Runs at
  /// most once per process, and only after both the notification service and
  /// the Navigator are ready.
  void _maybeHandleLaunch() {
    if (_launchChecked || !_startAttempted || !_uiReady) return;
    _launchChecked = true;
    _handleLaunch();
  }

  Future<void> _handleLaunch() async {
    try {
      final payload = await _readLaunchPayload();
      onNotificationOpened(payload);
    } catch (e) {
      debugPrint('NotificationBridge: launch check failed: $e');
    }
  }

  void _deliver(NotificationDestination destination) {
    if (_uiReady && _navigate(destination)) return;
    // Navigator not ready (still loading): keep the latest and retry in
    // markUiReady().
    _pending = destination;
  }

  /// The same tap can in principle be reported twice on a cold start (launch
  /// details and the response callback). Identical payloads inside a short
  /// window are treated as one tap.
  bool _isDuplicate(String? payload) {
    final now = DateTime.now();
    final last = _lastPayloadAt;
    final duplicate = payload == _lastPayload &&
        last != null &&
        now.difference(last) < _duplicateWindow;
    _lastPayload = payload;
    _lastPayloadAt = now;
    return duplicate;
  }

  static bool _navigateWithAppNavigator(NotificationDestination destination) {
    try {
      final navigator = appNavigatorKey.currentState;
      final context = appNavigatorKey.currentContext;
      if (navigator == null || context == null) return false;

      switch (destination) {
        case NotificationDestination.dailyReview:
          navigator.push(
            themedRoute(context, (_) => const DailyReviewSummaryScreen()),
          );
      }
      return true;
    } catch (e) {
      debugPrint('NotificationBridge: navigation failed: $e');
      return false;
    }
  }
}

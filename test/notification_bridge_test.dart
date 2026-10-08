import 'package:flutter_test/flutter_test.dart';

import 'package:nihongo_trainer/notifications/notifications.dart';
import 'package:nihongo_trainer/services/notification_bridge.dart';

/// Covers the app-side notification glue: how payloads are interpreted, when
/// navigation is allowed, cold-start handling, and -- most importantly -- that
/// a failure anywhere in notification startup can never escape into the app.
///
/// These tests use the bridge's injectable seams, so they need no platform
/// channels and no real notification plugin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('payload interpretation', () {
    test('reminder and snooze payloads open the daily review summary', () {
      expect(destinationForNotificationPayload(NotificationPayloads.reminder(7)),
          NotificationDestination.dailyReview);
      expect(destinationForNotificationPayload(NotificationPayloads.snooze(7)),
          NotificationDestination.dailyReview);
    });

    test('unknown, future-version, legacy and empty payloads do not navigate',
        () {
      expect(destinationForNotificationPayload(null), isNull);
      expect(destinationForNotificationPayload(''), isNull);
      expect(destinationForNotificationPayload('v2:reminder:1'), isNull);
      expect(destinationForNotificationPayload('v1:something_new:1'), isNull);
      expect(destinationForNotificationPayload('12'), isNull);
    });
  });

  group('tap delivery', () {
    late List<NotificationDestination> navigated;

    NotificationBridge bridge({
      Duration window = Duration.zero,
      Future<String?> Function()? launch,
    }) =>
        NotificationBridge(
          navigate: (d) {
            navigated.add(d);
            return true;
          },
          readLaunchPayload: launch ?? () async => null,
          initializeService: (_) async {},
          loadSettings: (_) async {},
          duplicateWindow: window,
        );

    setUp(() => navigated = []);

    test('a tap before the UI is ready is held, then delivered once', () {
      final b = bridge();
      b.onNotificationOpened(NotificationPayloads.reminder(1));
      expect(navigated, isEmpty);

      b.markUiReady();
      expect(navigated, [NotificationDestination.dailyReview]);

      b.markUiReady();
      expect(navigated, hasLength(1), reason: 'pending tap must not repeat');
    });

    test('a tap after the UI is ready navigates immediately', () {
      final b = bridge()..markUiReady();
      b.onNotificationOpened(NotificationPayloads.snooze(3));
      expect(navigated, [NotificationDestination.dailyReview]);
    });

    test('unrecognised payloads never navigate', () {
      final b = bridge()..markUiReady();
      b.onNotificationOpened('v9:mystery:1');
      b.onNotificationOpened(null);
      expect(navigated, isEmpty);
    });

    test('an identical tap reported twice in quick succession is one tap', () {
      final b = bridge(window: const Duration(seconds: 5))..markUiReady();
      b.onNotificationOpened(NotificationPayloads.reminder(1));
      b.onNotificationOpened(NotificationPayloads.reminder(1));
      expect(navigated, hasLength(1));
    });

    test('a failed navigation keeps the tap pending instead of dropping it',
        () {
      var navigatorAvailable = false;
      final b = NotificationBridge(
        navigate: (d) {
          if (!navigatorAvailable) return false;
          navigated.add(d);
          return true;
        },
        readLaunchPayload: () async => null,
        initializeService: (_) async {},
        loadSettings: (_) async {},
        duplicateWindow: Duration.zero,
      )..markUiReady();

      b.onNotificationOpened(NotificationPayloads.reminder(1));
      expect(navigated, isEmpty);

      navigatorAvailable = true;
      b.markUiReady();
      expect(navigated, hasLength(1));
    });
  });

  group('cold start', () {
    test('the launching tap is handled once, only after start and UI ready',
        () async {
      final navigated = <NotificationDestination>[];
      var launchReads = 0;
      final b = NotificationBridge(
        navigate: (d) {
          navigated.add(d);
          return true;
        },
        readLaunchPayload: () async {
          launchReads++;
          return NotificationPayloads.reminder(2);
        },
        initializeService: (_) async {},
        loadSettings: (_) async {},
      );

      b.markUiReady();
      await pumpEventQueue();
      expect(launchReads, 0, reason: 'service start has not been attempted');

      await b.start(NotificationSettingsService());
      await pumpEventQueue();
      expect(navigated, [NotificationDestination.dailyReview]);

      b.markUiReady();
      await pumpEventQueue();
      expect(launchReads, 1, reason: 'launch details are read once per process');
      expect(navigated, hasLength(1));
    });

    test('a normal launch (no notification) does not navigate', () async {
      final navigated = <NotificationDestination>[];
      final b = NotificationBridge(
        navigate: (d) {
          navigated.add(d);
          return true;
        },
        readLaunchPayload: () async => null,
        initializeService: (_) async {},
        loadSettings: (_) async {},
      );
      await b.start(NotificationSettingsService());
      b.markUiReady();
      await pumpEventQueue();
      expect(navigated, isEmpty);
    });
  });

  group('startup is non-fatal', () {
    test('service init is attempted before settings load', () async {
      final order = <String>[];
      final b = NotificationBridge(
        initializeService: (_) async => order.add('init'),
        loadSettings: (_) async => order.add('load'),
        readLaunchPayload: () async => null,
      );
      await b.start(NotificationSettingsService());
      expect(order, ['init', 'load']);
    });

    test('a failing init does not throw and settings still load', () async {
      var loaded = false;
      final b = NotificationBridge(
        initializeService: (_) async => throw StateError('plugin missing'),
        loadSettings: (_) async => loaded = true,
        readLaunchPayload: () async => null,
      );
      await expectLater(b.start(NotificationSettingsService()), completes);
      expect(loaded, isTrue);
    });

    test('a failing settings load does not throw', () async {
      final b = NotificationBridge(
        initializeService: (_) async {},
        loadSettings: (_) async => throw StateError('schedule failed'),
        readLaunchPayload: () async => null,
      );
      await expectLater(b.start(NotificationSettingsService()), completes);
    });

    test('a synchronous throw from init is also contained', () async {
      final b = NotificationBridge(
        initializeService: (_) => throw ArgumentError('sync failure'),
        loadSettings: (_) async {},
        readLaunchPayload: () async => null,
      );
      await expectLater(b.start(NotificationSettingsService()), completes);
    });

    test('a failing launch-details read does not throw or navigate', () async {
      final navigated = <NotificationDestination>[];
      final b = NotificationBridge(
        navigate: (d) {
          navigated.add(d);
          return true;
        },
        initializeService: (_) async {},
        loadSettings: (_) async {},
        readLaunchPayload: () async => throw StateError('no launch details'),
      );
      await b.start(NotificationSettingsService());
      b.markUiReady();
      await pumpEventQueue();
      expect(navigated, isEmpty);
    });

    test('start runs only once', () async {
      var inits = 0;
      final b = NotificationBridge(
        initializeService: (_) async => inits++,
        loadSettings: (_) async {},
        readLaunchPayload: () async => null,
      );
      final settings = NotificationSettingsService();
      await b.start(settings);
      await b.start(settings);
      expect(inits, 1);
    });
  });
}

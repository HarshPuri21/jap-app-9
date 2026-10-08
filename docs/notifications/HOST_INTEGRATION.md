# Study reminders — how they are wired into this app

`lib/notifications/` is the reusable subsystem (see `INTEGRATION.md` and
`README.md` in this folder). It has no dependency on Provider, navigation,
screens or themes, and this app keeps it that way. Everything app-specific
lives in the files below.

## Host-side files

| File | Responsibility |
| --- | --- |
| `lib/services/notification_bridge.dart` | `appNavigatorKey`; interprets notification payloads (`destinationForNotificationPayload`); non-fatal startup; cold-start handling; holds a tap until Home is on screen. |
| `lib/screens/reminder_settings_screen.dart` | The reminders screen in the app's own themed components. Drives the package's services; every call is guarded. |
| `lib/screens/settings_screen.dart` | One "Reminders" section linking to that screen. |
| `lib/main.dart` | `NotificationSettingsService` provider, `navigatorKey`, non-blocking `NotificationBridge.start`, and the "UI ready" signal. |
| `tool/android/apply_notification_android_config.py` | Applies the Android configuration to the generated `android/` project (idempotent). |
| `.github/workflows/build_apk.yml` | Runs that script after `flutter create`. |

## Startup order

1. `_AppLoader.initState` starts `NotificationBridge.start(...)` without awaiting it.
2. `start` runs `NotificationService.init(onNotificationOpened: ...)` **then**
   `NotificationSettingsService.load()` (loading reschedules, so order matters).
3. Each step is wrapped separately; a failure is logged and swallowed.
4. When the loader finishes and Home is built, `markUiReady()` runs. Any tap
   that arrived earlier is delivered, and the cold-start launch payload is
   read exactly once.

## Adding a new notification type later

1. Give the new notification its own payload prefix and its own OS ID range in
   `lib/notifications/` (never reuse or shrink the existing ranges, and never
   call `cancelAll()`).
2. Add a value to `NotificationDestination` and a case in
   `destinationForNotificationPayload`.
3. Handle the new destination in `NotificationBridge._navigateWithAppNavigator`.

`NotificationService` itself does not change.

## Changes made to the package, and why

The package was integrated unmodified except for these corrections:

* `init()` no longer overwrites the host's `onNotificationOpened` with `null`.
  Every internal method calls `init()` with no arguments, so the original code
  erased the tap handler right after startup.
* A failed `init()` is no longer cached forever; the next call retries.
* The foreground snooze path catches its own errors (it runs un-awaited).
* `cancelAllOwnedNotifications()` was added and is used when reminders are
  switched off or rescheduled. It enumerates the notifications the OS actually
  has pending and cancels only IDs inside this subsystem's namespace, so
  orphaned schedules are removed without ever touching other notification types.
* `rescheduleAll(..., keepSnooze:)`: the launch-time re-sync in `load()` keeps
  a pending snooze while reminders are enabled. Previously every app launch
  cancelled it, so opening the app within five minutes of tapping "Remind me in
  5 min" silently discarded the snooze. Turning reminders off (or loading with
  reminders disabled) still cancels it.
* Two trivial lints in `notification_settings_service.dart`.

## Beyond INTEGRATION.md

`tool/android/apply_notification_android_config.py` also installs
`res/raw/keep.xml`. Release builds shrink resources, and the notification icon
is referenced only by name from Dart, which the shrinker cannot see.

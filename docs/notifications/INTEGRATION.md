# Study Reminders Package v2.0.0

A reusable, Android-first local notification subsystem for Nihongo Trainer.

## Design goals

- No dependency on Provider, Riverpod, GoRouter, Navigator, ThemeController, or app-specific screens.
- Stable notification IDs and versioned payloads across app upgrades.
- Multiple reminders per day, arbitrary weekdays, local timezone and DST-aware scheduling.
- Notification actions: open app, snooze 5 minutes, ignore.
- No `cancelAll()` so unrelated future notification features are not destroyed.
- Safe persistence and serialized mutations.
- Android boot/app-update recovery.
- Package owns its own notification channel and ID namespace.

The package is intentionally a source module, not a separate Dart package. Copy `lib/notifications/` into the host app.

## Dependency policy

The source was written and checked against these stable major versions:

```yaml
flutter_local_notifications: ^22.3.1
timezone: ^0.11.1
flutter_timezone: ^5.1.0
```

Use these constraints rather than an unconstrained `flutter pub add`, because a future major release can intentionally contain breaking API changes. The caret ranges allow compatible patch/minor releases within the tested major version.

Current references:
- `flutter_local_notifications` 22.3.1 is the stable 22.x line.
- `flutter_timezone` 5.1.0 returns `TimezoneInfo`, whose IANA identifier is `identifier`.
- `timezone` 0.11.x is used by this source.

If the app intentionally upgrades to a new major of any of these packages, treat that as a dependency migration and rerun the notification integration tests before merging.

## 1. Copy the source

Copy:

```text
lib/notifications/
```

into the application's `lib/` directory.

Copy the notification icon from:

```text
android/ic_notification.xml
```

to:

```text
android/app/src/main/res/drawable/ic_notification.xml
```

The icon is deliberately a simple white vector suitable for Android notification surfaces. Do not use the full launcher icon as the notification icon.

## 2. Add dependencies

Add these to the host app's `pubspec.yaml`:

```yaml
dependencies:
  flutter_local_notifications: ^22.3.1
  timezone: ^0.11.1
  flutter_timezone: ^5.1.0
```

Then run:

```bash
flutter pub get
```

Do not replace these with an unconstrained latest-major dependency automatically.

## 3. Android build requirements

`flutter_local_notifications` 22.x requires Android core-library desugaring for scheduled notifications and the 22.x Android toolchain requirements must be satisfied. The official plugin documentation also requires Java 17 compatibility and an adequate compile SDK.

For a generated Flutter Android project, ensure `android/app/build.gradle` or `.kts` contains the equivalent of:

### Groovy

```gradle
android {
    compileSdk 36

    defaultConfig {
        multiDexEnabled true
    }

    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

### Kotlin DSL

```kotlin
android {
    compileSdk = 36

    defaultConfig {
        multiDexEnabled = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

If the host project's generated Flutter template already uses a newer compile SDK, AGP, Gradle, Java, or Kotlin version, keep the newer compatible value rather than downgrading it.

## 4. AndroidManifest.xml

Add these permissions directly under `<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Inside `<application>`, add:

```xml
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />

<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />

<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

Do **not** add `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`: this package intentionally uses `inexactAllowWhileIdle`.

These receiver declarations follow the plugin's current Android setup guidance. If the host deliberately upgrades to a new major plugin version, compare its AndroidManifest setup with the new release documentation before changing receiver names.

## 5. Service initialization

Initialize the notification bridge before loading notification settings:

```dart
await NotificationService.instance.init(
  onNotificationOpened: (payload) {
    // The host app owns navigation.
    // Example: navigatorKey.currentState?.pushNamed('/daily_review');
  },
);

await notificationSettingsService.load();
```

Do not put `NotificationSettingsService.load()` in the same unordered `Future.wait()` as `NotificationService.init()`; settings loading reschedules notifications and therefore depends on notification initialization.

### Cold-start notification taps

After the app's navigation/router is ready, call:

```dart
await NotificationService.instance.handleLaunchIfPresent();
```

This handles the case where Android launched a completely terminated app because the user tapped a notification. The normal response callback alone cannot handle that case.

If navigation is not ready during startup, call `handleLaunchIfPresent()` after the first frame or after the router is initialized.

## 6. State management

`NotificationSettingsService` extends `ChangeNotifier`, but the package does not depend on Provider.

For Provider:

```dart
ChangeNotifierProvider(
  create: (_) => NotificationSettingsService(),
),
```

For another state manager, expose the same service instance through that system.

The settings screen requires the service explicitly:

```dart
NotificationSettingsScreen(
  service: context.read<NotificationSettingsService>(),
)
```

This keeps the package independent from whatever state-management system a future app version uses.

## 7. Notification tap payloads

Current payloads are versioned:

```text
v1:reminder:<stable-id>
v1:snooze:<stable-id>
```

The host app should not depend on the raw string if it can avoid it. Treat it as an opaque payload and route based on the prefix/version.

Future package versions can introduce `v2:` without making old scheduled notifications impossible to interpret.

## 8. Reminder storage

Preferences use versioned keys:

```text
notif_enabled_v1
notif_next_id_v1
notif_reminders_v1
```

The JSON model also validates/clamps time values and filters invalid weekdays. Corrupt reminder storage is treated as an empty list instead of crashing startup.

Do not change these keys casually. If a future migration is required, read v1, migrate into a new version, then write the new keys.

## 9. Scheduling behavior

Each reminder gets deterministic OS IDs from its stable reminder ID and weekday. The package owns only its own ID namespace.

`rescheduleAll()` cancels only reminder IDs belonging to this package and the package's reserved snooze ID. It deliberately does **not** call `cancelAll()`.

The schedule is timezone-aware and uses `DateTimeComponents.dayOfWeekAndTime`, so weekly reminders remain tied to the user's local wall-clock time across normal DST changes.

## 10. Permissions

Android 13+ notification permission is requested only from a user interaction.

The settings screen does not switch reminders on when permission is denied.

If the user later disables notifications in Android system settings, the app should treat that as an OS-level permission state; do not silently force the app setting back on.

## 11. Snooze behavior

There is one package-owned snooze slot. Snoozing another reminder replaces the previous pending snooze.

Disabling all reminders cancels the snooze as well.

If the future product requirement becomes "each reminder can have its own simultaneous snooze", the ID scheme should be extended rather than reusing the current single-slot behavior.

## 12. Future-proofing rules

When the host app evolves:

1. Keep `NotificationService` independent of navigation and UI.
2. Keep `NotificationSettingsService` independent of Provider/Riverpod.
3. Keep reminder IDs stable; never derive IDs from list indexes.
4. Never reuse an existing notification action ID for a different meaning.
5. Treat payloads as versioned protocol data.
6. Add new notification types to a new ID namespace instead of calling `cancelAll()`.
7. When changing persistence, migrate old versioned keys rather than deleting them.
8. When upgrading `flutter_local_notifications`, `timezone`, or `flutter_timezone` across a major version, update this package as a dependency migration rather than expecting old source code to compile unchanged.
9. If iOS is added, add Darwin initialization/permissions and iOS action categories in a deliberate platform migration; the current UI/service API is structured so the host-facing API can remain unchanged.

## 13. Required test checklist

Before release, test on a real Android device:

- Fresh install → permission prompt.
- Deny permission → reminders do not appear enabled.
- Grant permission → reminder schedules.
- Add two reminders at different times.
- Same reminder on multiple weekdays.
- Edit a reminder → old schedule disappears.
- Delete a reminder → all of its weekday schedules disappear.
- Disable all reminders → no reminder or snooze remains pending.
- Re-enable reminders → schedules are restored.
- Reboot device → reminders still fire.
- Update/reinstall app over an existing install → schedules remain coherent.
- Tap notification body while app is foreground/background.
- Tap notification body while app is terminated.
- Tap Snooze from foreground.
- Tap Snooze while app is backgrounded/terminated.
- Tap Ignore.
- Change device timezone and verify future weekly reminders use the new local timezone after the app is next initialized.
- Verify a reminder around a DST transition in a timezone that observes DST.

## 14. Current plugin references

This package targets the stable `flutter_local_notifications` 22.x API. The plugin documentation explicitly documents named `initialize`, `zonedSchedule`, `cancel`, notification actions, Android receivers, desugaring, and cold-start handling through `getNotificationAppLaunchDetails()`.

If the dependency is deliberately moved to a future major, consult that release's Android setup and API documentation before changing the package.

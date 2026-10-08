# Nihongo Trainer Study Reminders — v2.0.0

Reusable local reminder subsystem for the Nihongo Trainer Flutter app.

Features:

- Multiple weekly study reminders.
- Per-reminder time, weekdays, label and enabled state.
- Timezone/DST-aware scheduling.
- Android 13+ notification permission handling.
- Tap to open app.
- Remind me in 5 minutes.
- Ignore action.
- Boot/update recovery.
- Stable IDs and versioned payloads.
- No Provider/Riverpod/navigation/theme dependency.
- Serialized mutations and defensive persistence.

Start with `INTEGRATION.md`.

Dependency baseline: `flutter_local_notifications ^22.3.1`, `timezone ^0.11.1`, `flutter_timezone ^5.1.0`.

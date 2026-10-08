# Nihongo Trainer — Home UI Refinement Record

**Date:** 2026-10-07  
**Base project:** `jap-app-1.8.0-main_training-quality-stable_2026-10-06.zip`  
**Scope:** Presentation/hierarchy only. No new learning features or navigation behavior.

## Why this pass exists

The training architecture was feature-frozen after the October 6 quality pass. The next goal was to make the existing home screen easier to understand at a glance without redesigning the three theme systems or changing any learning functionality.

The old screen presented all eight learning/practice destinations under one `Practice` heading. Every mode therefore had almost identical visual priority even though they represent two different user intentions: *learning new material* and *practising/testing material*.

## Changes made

### 1. Home screen hierarchy is now explicit

The screen is organized into three semantic sections:

- **Today** — Daily Progress + Daily Review
- **Learn** — Learn Sentences, Learn Kanji, Learn Kana, Radicals
- **Practice** — Flashcards, Take a Test, Kana Quiz, Radical Quiz

No destination was removed and no route was changed.

### 2. Mode order is more intentional

The learning section now reads from broad language material into component study:

1. Learn Sentences
2. Learn Kanji
3. Learn Kana
4. Radicals

The practice section is:

1. Flashcards
2. Take a Test
3. Kana Quiz
4. Radical Quiz

This is only presentation ordering; the underlying screens are unchanged.

### 3. Home copy was shortened for scanning

Long prose subtitles were replaced by concise dot-separated descriptions. Examples:

- `2022 examples · grammar forms · JLPT N5 → N1`
- `1394 kanji · meanings & readings · JLPT N5 → N1`
- `Vocabulary & kanji · quick recall practice`
- `Custom quiz · choose content and length`

Counts remain sourced from `DataService`, so they cannot silently drift from the bundled data.

### 4. Dashboard cards are more responsive

The two top dashboard cards remain side-by-side on normal phone widths.

They now stack vertically when:

- the available content width is below 300 logical pixels, or
- the system text scale is above 1.35×.

This avoids squeezing Daily Progress / Daily Review into narrow columns and is especially useful on 320 px devices or accessibility text settings.

### 5. Important text may wrap instead of truncating immediately

`ModeCard` titles may use up to 2 lines and subtitles up to 3 lines.

`DashboardCard` headline/sub-stat text may use up to 2 lines.

There are still ellipsis guards for pathological layouts, but normal accessibility scaling gets more room before information is discarded.

### 6. Regression guard added

`test/widget_test.dart` now verifies that the booted Home screen contains:

- `TODAY`
- `LEARN`
- `PRACTICE`

This protects the new semantic hierarchy from accidentally being flattened later.

### 7. Existing training validator updated

`tool/validate_training_quality.py` was updated only to match the refined home subtitle wording. All training-quality assertions still pass.

## Files changed

- `lib/screens/home_screen.dart`
- `lib/widgets/mode_card.dart`
- `lib/widgets/dashboard_card.dart`
- `test/widget_test.dart`
- `tool/validate_training_quality.py`

## File added

- `docs/HOME_UI_REFINEMENT_2026-10-07.md`

## Explicitly not changed

This pass did **not** modify:

- Daily Review logic
- SRS scheduling
- kanji/sentence data
- JLPT defaults
- quiz generation
- flashcard behavior
- reminder/notification behavior
- theme definitions
- settings
- audio
- page transitions
- Journey integration
- app startup behavior

## Validation completed in this environment

### Training-quality validator

```bash
python3 tool/validate_training_quality.py
```

Result at packaging time: **0 errors**.

### Notification Android patch tests

```bash
python3 tool/android/test_apply_notification_android_config.py
```

Result at packaging time: **10/10 passed**.

### Flutter tests

Flutter/Dart SDK is not installed in this execution environment, so the following must still be run in GitHub Actions or a Flutter development machine:

```bash
flutter analyze
flutter test
```

A new Home hierarchy assertion is included in `test/widget_test.dart` for that run.

## Manual UI smoke check for the next device build

1. Open Home at normal Android text size.
2. Confirm Daily Progress + Daily Review remain side-by-side on a typical phone.
3. Confirm the order is Today → Learn → Practice.
4. Confirm Learn order is Sentences → Kanji → Kana → Radicals.
5. Confirm Practice order is Flashcards → Test → Kana Quiz → Radical Quiz.
6. Increase Android font size/text scale significantly and reopen Home.
7. Confirm dashboard cards stack instead of clipping.
8. Check Glass, Zen Minimal, and Tokyo Neon themes.
9. Tap every home card once and confirm navigation targets are unchanged.

## Next UI work

The next visual pass can focus on screen-level polish and motion (button/card feedback, answer states, transitions, and finally the Journey swipe integration) without revisiting the Home information architecture.

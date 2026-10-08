# Nihongo Trainer Change Record — 2026-10-06

## Base version

This change set was made directly from the user's current master project:

`jap-app-1.8.0-main.zip`

The internal app version remains `1.8.0+6`; version numbering was intentionally not changed in this pass.

## Scope of this pass

Only these product/data issues were addressed:

1. Fix the Daily Review "20 new items per day" behavior and make the summary truthful.
2. Remove the 27 exact Japanese sentence forms duplicated across different JLPT levels without deleting the genuinely advanced forms in the higher-level families.
3. Make JLPT level the primary learner-facing level selector wherever trustworthy JLPT metadata exists, especially Learn Kanji and sentence/kanji Test mode.
4. Add regression tests and this permanent engineering record.

No main-screen redesign, animation pass, Journey merge, theme redesign, notification redesign, Android package/version work, or unrelated feature changes were made.

---

## 1. Daily Review: real 20-new-items-per-day cap

### Previous behavior

`buildDailyQueue()` always added up to 20 never-studied items every time a new review session was opened. The app did not remember how many new items had already been introduced earlier that same day.

Example of the old bug:

- Open Daily Review -> 20 new items.
- Review 7 and leave.
- Reopen Daily Review -> up to another 20 new items could be offered.
- Repeating this could introduce far more than the intended 20 new items in one day.

The summary could also look contradictory because "Due today" was derived from `completed + remaining`, and the type breakdown only counted scheduled reviews while the queue also contained new items.

### New behavior

`ItemProgress` now persists an optional `firstReviewed` timestamp.

Important migration rule:

- `firstReviewed` is set only when a brand-new SRS progress record is created.
- Existing users' older progress records do **not** have `firstReviewed`.
- Reviewing one of those legacy records later does not incorrectly reclassify it as a new item.

Migration note: on the first day an existing installation receives this update, an item that was first introduced earlier that same day by the old build cannot be distinguished from an older item merely reviewed that day. The code intentionally does not guess. This can only make that one migration day slightly more permissive; all items introduced after the update are tracked exactly.

`ProgressService` now calculates:

- `newItemsIntroducedTodayCount`
- `newItemAllowanceRemaining`
- `newItemsAvailableToday`

The Daily Review queue now adds only:

`min(unseen items remaining, today's unused new-item allowance, requested cap)`

So with the default limit of 20:

- 0 introduced -> up to 20 new items available.
- 7 introduced -> up to 13 more new items available.
- 20 introduced -> 0 additional new items available until the local calendar day changes.

Scheduled reviews are never capped.

Because Flashcards writes to the same SRS state, a never-studied vocab/kanji item first rated from Flashcards also counts as an item introduced today. This is intentional: once an item enters SRS, it contributes future review workload regardless of which screen introduced it.

### Additional review-count hardening

`dueCount` and `dueCountByPrefix` now count only IDs that still exist in the current bundled vocab/kanji dataset. A stale progress key from an older content version can no longer create a phantom "review due" badge that the queue cannot resolve.

### Summary/UI wording changes

Daily Review summary now shows:

- Remaining
- Reviewed
- New today

The breakdown now distinguishes:

- Vocabulary scheduled reviews
- Kanji scheduled reviews
- New-item allowance/usage

When the learner has used the full 20-new-item allowance and has no scheduled reviews due, the caught-up state explicitly says the daily new-item batch has been completed rather than implying there is no unseen content left.

The Home Daily Review card now reports the actual number **remaining**, rather than `completed + remaining` as if all of it were still due.

---

## 2. Cross-JLPT duplicate sentence cleanup

### Decision

For an **identical Japanese sentence form** that existed at more than one JLPT level, the exact duplicate is kept at its lowest/easiest legitimate JLPT level.

Only the duplicate basic form is removed from the harder family. Any genuinely more advanced grammatical forms in the harder family remain.

This prevents a learner selecting N2/N3/N4 from being shown an exact basic sentence already classified at an easier level merely because the harder family reused that base conjugation.

### Removed duplicates

There were exactly 27 duplicated sentence entries:

- 9 entries from `n4_509` duplicated `n5_022` — `学生は図書館へ行く` family.
- 9 entries from `n3_016` duplicated `n5_035` — `彼は忙しい` family.
- 9 entries from `n2_003` duplicated `n5_010` — `医者は薬を使う` family.

These 27 rows were the basic present/past/negative/te-form variants.

### Advanced forms explicitly retained

`n4_509` still contains:

- potential
- volitional

`n3_016` still contains:

- conditional_tara

`n2_003` still contains:

- potential
- volitional
- conditional_tara
- causative

So the cleanup removes duplicated labeling, not advanced curriculum.

### Dataset counts after cleanup

Sentences:

- Before: 2,049
- After: 2,022

Current distribution:

- N5: 900
- N4: 574
- N3: 241
- N2: 109
- N1: 198

The authoritative generation sources were updated too:

- `tool/sources/sentence_batches_combined.json`: 2,049 -> 2,022 rows
- `tool/sources/sentence_translations.json`: 1,142 -> 1,127 keys

The 15 removed translation keys correspond exactly to the five duplicated grammatical forms in each of the three harder-level families.

`tool/generate_sentence_questions.py` documentation/count comments were updated to match the new authoritative source.

---

## 3. JLPT-first level/filter policy

### Product rule established in this pass

Where content has reliable JLPT metadata, learner-facing filtering should prioritize:

`All -> N5 -> N4 -> N3 -> N2 -> N1`

Easy / Normal / Hard remains secondary metadata and remains the fallback selector for content that does not have a real JLPT level.

We do **not** invent JLPT levels for content that lacks them.

### Learn Sentences

Already used JLPT-first filtering before this pass. No behavioral redesign was needed.

### Learn Kanji

Changed from:

`All / Easy / Normal / Hard`

to:

`All / N5 / N4 / N3 / N2 / N1`

Kanji question cards now display the JLPT level as the primary badge when available. The existing difficulty value still supplies the theme color and remains a fallback for the 68 kanji entries that currently have no JLPT tag.

Kanji dataset coverage remains:

- N5: 81
- N4: 166
- N3: 370
- N2: 159
- N1: 550
- Unclassified: 68
- Total: 1,394

Selecting `All` still includes those 68 unclassified items, so no kanji became inaccessible.

### Test mode

For **Sentence** and **Kanji** tests, the setup screen now asks for JLPT level first instead of Easy/Normal/Hard.

For **Radical** and **Mixed** tests, Difficulty remains the selector because radicals have no JLPT metadata and Mixed needs one common filter across unlike content types.

Test question badges show JLPT level for sentence/kanji items and fall back to difficulty for radicals/unclassified content.

### Intentionally unchanged

Radical Quiz remains `All / Easy / Normal / Hard` because the radical dataset has no JLPT level field.

Kana remains organized by its kana learning groups/stages, not JLPT.

Flashcards remain Mixed/Vocab/Kanji because they are a general review surface rather than a difficulty-filtered lesson screen.

---

## 4. Regression tests added

### `test/progress_daily_limit_test.dart`

Covers:

- Initial Daily Review offers at most 20 new items.
- Reviewing 7 new items leaves only 13 new slots for another session that day.
- Reaching 20 prevents another new batch.
- The cap survives a `ProgressService` reload/app restart through persisted `firstReviewed` timestamps.
- Legacy progress entries without `firstReviewed` do not consume today's new-item allowance and are not reclassified as new on their next review.

### `test/content_leveling_test.dart`

Covers:

- No exact Japanese prompt is duplicated across different JLPT levels in the final sentence asset.
- Advanced forms remain present in `n4_509`, `n3_016`, and `n2_003` after deduplication.

---

## 5. Files changed in this pass

Code/UI:

- `lib/models/item_progress.dart`
- `lib/services/progress_service.dart`
- `lib/services/data_service.dart`
- `lib/screens/daily_review_screen.dart`
- `lib/screens/daily_review_summary_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/kanji_mode_screen.dart`
- `lib/screens/test_setup_screen.dart`
- `lib/screens/test_run_screen.dart`
- `lib/widgets/jlpt_level_badge.dart` (new)

Content pipeline/data:

- `assets/data/sentences.json`
- `tool/sources/sentence_batches_combined.json`
- `tool/sources/sentence_translations.json`
- `tool/generate_sentence_questions.py`

Tests:

- `test/progress_daily_limit_test.dart` (new)
- `test/content_leveling_test.dart` (new)

Record:

- `docs/CHANGE_RECORD_2026-10-06.md` (this file)

---

## 6. Validation performed on 2026-10-06

Available non-Flutter validation was run in the working environment.

### Sentence source/output consistency

PASS:

- source rows: 2,022
- app sentence rows: 2,022
- every output row matches the authoritative source for family ID, Japanese, reading, form, tone, JLPT level, explanation and tags
- every answer exists in its four unique options
- every English answer matches the authoritative translation
- exact Japanese prompts duplicated across JLPT levels: 0
- invalid family tone sets: 0
- advanced forms in the three cleaned families remain present

### Sentence generator validation

`python3 tool/generate_sentence_questions.py --sample`

PASS.

Reported:

- 2,022 source entries
- 195 families
- 1,127 unique family/form questions
- no distractor fallback required
- freshly regenerated output matched `assets/data/sentences.json` exactly for all 2,022 entries

### Notification Android patcher regression suite

`python3 tool/android/test_apply_notification_android_config.py`

PASS: 10/10 tests.

This was rerun because the reminder system is part of the current `1.8.0` master, even though this pass did not modify it.

### Flutter/Dart tests

Not executable in the current review environment because Flutter/Dart SDK is not installed here.

The new Flutter tests are included so GitHub/your normal Flutter environment can run them with:

```bash
flutter analyze
flutter test
```

These two commands should be mandatory during the October 10 recheck before this build is treated as release-safe.

---

## 7. October 10 recheck checklist

When revisiting this project, verify the following before moving on from this change set:

1. Run `flutter analyze` and require zero errors.
2. Run `flutter test` and confirm the new Daily Review and content-level tests pass.
3. On a fresh install/profile, open Daily Review, complete fewer than 20 new items, leave, reopen, and confirm only the unused allowance is offered.
4. Reach 20 new items in one day and confirm reopening Daily Review offers no additional unseen items unless scheduled reviews are actually due.
5. Restart the app after reaching the cap and confirm it remains capped for the same local calendar day.
6. Confirm Learn Kanji shows `All, N5, N4, N3, N2, N1` and each chip produces the expected level.
7. Confirm Sentence and Kanji Test setup uses JLPT levels; Radical and Mixed tests still use Difficulty.
8. Confirm the three cleaned higher-level sentence families still expose their advanced forms.
9. Confirm no exact Japanese sentence appears twice under different JLPT labels.
10. Only after the above passes, proceed with the planned main-screen UI/animation work.

---

## Intentionally deferred

The following previously identified work was **not** included in this pass:

- Main home-screen UI redesign/hierarchy.
- 60/90/120 Hz animation/motion polish.
- Journey swipe/merge work.
- Large-text/small-screen accessibility regression suite.
- Making `flutter analyze` / `flutter test` blocking in GitHub Actions.
- Freezing/generated Android project and final application ID/signing.
- Any unlocking/progression changes in the Journey app.

Keeping those separate makes this change set easier to audit on October 10.

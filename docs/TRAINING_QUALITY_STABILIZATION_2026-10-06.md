# Nihongo Trainer — Training Quality Stabilization Record

**Date:** 2026-10-06  
**Base project:** `jap-app-1.8.0-main_review-jlpt-fixes_2026-10-06.zip`  
**Purpose:** Final internal training-quality pass before main-screen UI/animation work.  
**Scope:** Existing Kanji/Sentence/SRS behavior only. No new product features or redesigns.

This record is intentionally detailed so the project can be re-audited on **2026-10-10** without relying on chat history.

---

## 1. Beginner-safe JLPT defaults

### Changed
- **Learn Kanji** now opens on **N5**, not `All`.
- **Learn Sentences** now opens on **N5**, not `All`.
- **Take a Test → Kanji** defaults to **N5**.
- **Take a Test → Sentences** defaults to **N5**.
- Switching test type back to Kanji/Sentences resets the level to N5.
- `All` remains available for experienced learners.

### Rationale
The app already has JLPT metadata. Opening on `All` exposed beginners to advanced N1/N2 content immediately. N5 is now the recommended default while preserving full user freedom.

### Deliberately unchanged
- **Radicals** retain Easy / Normal / Hard because the radical dataset does not have genuine JLPT metadata.
- **Mixed tests** retain Easy / Normal / Hard because they combine content types without one reliable shared JLPT scale.
- No fake JLPT labels were invented for data that does not have them.

---

## 2. Daily Review introduces new material in a learner-safe order

### Changed
Daily Review still allows at most **20 genuinely new SRS items per local calendar day**, but new-content selection is now ordered deliberately instead of being random across the whole database.

#### Vocabulary
The vocabulary dataset has no JLPT field, so its existing curated source order is preserved.

#### Kanji
Fresh Kanji are selected in this order:

`N5 → N4 → N3 → N2 → N1 → unlevelled`

Characters are shuffled **within the selected JLPT level**, not across all levels.

#### Balancing
Fresh vocabulary and fresh kanji are interleaved before taking the daily batch. On a completely fresh dataset with both streams available, a 20-new-item queue therefore contains roughly:

- 10 vocabulary items
- 10 N5 kanji

The completed due+new queue is shuffled only **after** content selection, so presentation can feel varied without allowing an advanced kanji to jump ahead of the learning order.

### Result
A brand-new learner should no longer receive random N1 kanji in their first Daily Review batch.

---

## 3. Flashcards no longer bypass the 20-new-items/day intake

### Previous behavior
Swiping an unseen Flashcard immediately created an SRS progress record. A user could therefore introduce more than 20 brand-new SRS items in one day through Flashcards, bypassing Daily Review's daily limit.

### New behavior
- **Unseen Flashcards are unrestricted practice only.**
- Swiping an unseen Flashcard does **not** create a new SRS record and does not consume the 20-new-items/day allowance.
- **Daily Review is the controlled entry path for brand-new SRS material.**
- If a card is already in SRS, Flashcards preserve the existing behavior and may rate that existing item.

### UI wording
The Daily Review caught-up message now describes Flashcards as **extra practice**, rather than suggesting that Flashcards are a way to introduce more scheduled items.

---

## 4. SRS intervals are now calendar-day based

### Previous behavior
A 1-day interval preserved the exact review clock time. For example:

- Reviewed Monday at 22:45
- Due Tuesday at 22:45

A learner who studies every morning could effectively lose a day.

### New behavior
Day-based intervals now become due at local midnight on the target calendar day:

- Reviewed Monday at 22:45
- 1-day interval
- Due Tuesday at 00:00 local time

The same rule applies to longer intervals.

### Migration
Legacy saved due timestamps are normalized to midnight **without changing their due calendar date** when loaded.

---

## 5. Runtime answer-position shuffling

### Changed
Answer options are now copied and shuffled when a new question is prepared in:

- Learn Kanji
- Learn Sentences
- Sentence tests
- Kanji tests
- Radical tests
- Mixed tests

### Important behavior
- The source JSON is never mutated.
- Options do not reshuffle during a rebuild after the user taps an answer.
- The Sentence casual/formal toggle does not reshuffle choices.
- A new question gets a fresh runtime order.

### Rationale
This prevents users from learning that a particular question's answer is always, for example, the third button.

---

## 6. Kanji distractors are now JLPT-calibrated

`tool/regenerate_kanji_questions.py` was upgraded and all **1,394 Kanji questions** were regenerated.

### Selection rule
For a kanji with known JLPT level, distractors are selected from the **same JLPT level first**. A neighboring-level fallback exists only for future datasets where a level might not have enough valid candidates.

### Current shipped result
- Kanji questions: **1,394**
- Wrong-answer distractors: **4,182**
- Same-JLPT distractors: **4,182 / 4,182**
- Semantic answer/distractor gloss overlaps: **0**
- Every question has exactly 4 unique options and contains its answer.

This is substantially better than selecting arbitrary meanings from the entire N5–N1 pool.

---

## 7. Ambiguous 七 question fixed by generator rule

The previous 七 question could use a wrong option whose meaning itself included the word **“seven”**, making the question logically ambiguous.

The generator now compares comma/semicolon-delimited meaning terms and rejects a distractor if it shares a gloss term with the correct answer.

This means the 七 fix is not a one-off hard-coded patch; the same ambiguity class is prevented for every generated Kanji question.

---

## 8. Reviewed Kanji meaning/reading cleanup

A targeted learner-facing correction overlay was added:

`tool/kanji_content_corrections.json`

and a helper:

`tool/apply_kanji_content_corrections.py`

The corrections are also integrated into `tool/merge_kanji_dataset.py`, so re-running the Kanji merge cannot silently reintroduce the reviewed OCR/multilingual reading/gloss problems.

### Scope
This was intentionally conservative. Only demonstrably bad learner-facing **meaning / on'yomi / kun'yomi** data was changed. Legitimate uncommon readings were not deleted just because they looked unusual.

### Counts compared with the previous master
- Kanji entries in dataset: **1,394 → 1,394** (unchanged)
- Kanji identities removed: **0**
- Kanji entries with learner-facing corrections: **54**
- Actual changed fields: **75**
  - kun'yomi fields changed: **38**
  - meaning fields changed: **25**
  - on'yomi fields changed: **12**

Examples of corrected problems include OCR fragments and French/Spanish gloss leakage in entries such as 登, 偵, 松, 網, 彰 and others.

### Deliberately out of scope
The `common_words` example lists were **not** exhaustively re-audited in this pass. This task was limited to the approved meaning/readings cleanup.

---

## 9. Misleading Home copy corrected

### Learn Kanji
Old:

> `1,394 kanji, JLPT N5 → N1, with readings & breakdowns`

New:

> `1,394 kanji, JLPT N5 → N1, with meanings & readings`

Reason: only a subset of the Kanji entries has a breakdown, so the old subtitle overstated dataset coverage.

### Take a Test
Old:

> `Timed quiz with a final score`

New:

> `Custom quiz with a final score`

Reason: Test mode currently has no timer. No unnecessary timer feature was added just to make the old copy true.

---

# Data integrity after this pass

## Sentences
- Total: **2,022**
- N5: **900**
- N4: **574**
- N3: **241**
- N2: **109**
- N1: **198**
- Exact Japanese prompts duplicated across multiple JLPT levels: **0**
- Sentence dataset itself is unchanged from the preceding JLPT/deduplication pass.

## Kanji
- Total: **1,394**
- N5: **81**
- N4: **166**
- N3: **370**
- N2: **159**
- N1: **550**
- Unlevelled: **68**
- Kanji identity count unchanged.

## Kanji questions
- Total: **1,394**
- Four unique options per question: validated
- Correct answer included: validated
- Same-JLPT wrong answers in current data: **4,182 / 4,182**
- Semantic correct/wrong gloss collisions: **0**

---

# Regression protection added

## Flutter tests added/expanded

### `test/progress_daily_limit_test.dart`
Covers:
- persistent 20-new-items/day limit
- restart persistence
- legacy progress compatibility
- N5-before-N1 Daily Review selection
- fresh 20-item balancing between vocab and kanji
- unseen Flashcards not entering SRS
- existing SRS cards still being rateable from Flashcards

### `test/item_progress_calendar_test.dart`
Covers:
- 1-day interval due next calendar day at midnight
- multi-day interval normalization
- legacy timestamp migration

### `test/quiz_options_test.dart`
Covers:
- runtime shuffled copy does not mutate source options
- shuffled copy preserves the option set

### `test/content_leveling_test.dart`
Covers:
- no cross-JLPT exact sentence duplicates
- advanced grammar forms retained in higher sentence families
- same-JLPT Kanji distractors
- four unique choices / answer included
- no answer/distractor gloss overlap
- 七 ambiguity regression

---

# Offline validation tool added

`tool/validate_training_quality.py`

This can be run even without Flutter installed and checks the major content/data invariants from this pass.

Expected current result:

```text
Sentences: 2022 {'N5': 900, 'N4': 574, 'N3': 241, 'N2': 109, 'N1': 198}
Kanji: 1394 {'N5': 81, 'N3': 370, 'N4': 166, None: 68, 'N1': 550, 'N2': 159}
Kanji questions: 1394
Reviewed kanji correction overlay: 54 entries
Cross-JLPT exact sentence duplicates: 0
Errors: 0
```

It verifies:
- Sentence option integrity
- Cross-JLPT exact sentence deduplication
- Kanji identity/count integrity
- Kanji-question/source synchronization
- Four unique Kanji options and answer inclusion
- Same-JLPT distractors
- Semantic answer/distractor overlap prevention
- Correction overlay application
- Known multilingual/OCR gloss fragments removed
- 七 ambiguity prevention
- Source-level guards for N5 defaults, runtime shuffle, Flashcard SRS behavior, calendar scheduling and corrected Home copy

---

# Validation performed on 2026-10-06

The following checks passed in the available environment:

1. All bundled JSON parses successfully.
2. `python3 tool/validate_training_quality.py` → **0 errors**.
3. `python3 tool/android/test_apply_notification_android_config.py` → **10/10 tests passed**.
4. `python3 tool/regenerate_kanji_questions.py` → deterministic output; all entries retain exactly four options.
5. `python3 tool/generate_sentence_questions.py` → deterministic output; **2,022 entries**, **195 families**, no weak distractor fallback required.
6. `python3 tool/merge_kanji_dataset.py` → correction overlay is integrated and the current Kanji asset is **idempotent** under a re-run.
7. No Kanji or Sentence identity/count regression was found.

## Environment limitation

The Flutter and Dart SDK executables are **not installed in the current execution environment**. Therefore the following could not be truthfully executed here:

```bash
flutter analyze
flutter test
```

The Dart/Flutter regression tests listed above are included in the project for CI/local verification.

---

# Recheck checklist for 2026-10-10

Run from the project root:

```bash
python3 tool/validate_training_quality.py
python3 tool/android/test_apply_notification_android_config.py
python3 tool/regenerate_kanji_questions.py
python3 tool/generate_sentence_questions.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

After regenerating data, there should be no unexpected content diff if the source data has not changed.

## Manual smoke checks

### Learn Sentences
- Opens on **N5**.
- `All` still works.
- N4/N3/N2/N1 filters work.
- Answer positions vary between freshly loaded questions.
- Answer positions do not jump after selecting an answer.
- Casual/formal toggle does not reshuffle the current options.

### Learn Kanji
- Opens on **N5**.
- `All` still works.
- N4/N3/N2/N1 filters work.
- Questions show JLPT-calibrated choices.
- 七 has no wrong choice that also means “seven”.
- Spot-check corrected entries such as 登, 偵, 松, 網, 彰 and 法.

### Test mode
- Sentence test defaults to N5.
- Kanji test defaults to N5.
- Radicals/Mixed still use difficulty instead of invented JLPT levels.
- Option positions are shuffled once per test item.

### Daily Review
On a clean profile with both content streams available:
- First fresh batch contains no N1 kanji.
- Kanji begin at N5.
- A 20-new-item batch is balanced approximately 10 vocab / 10 kanji.
- Leaving after introducing some items and reopening gives only the remaining daily allowance.
- Reopening/restarting the app does not reset the new-item allowance.

### Flashcards
- An unseen Flashcard can be practiced without creating an SRS record.
- It does not consume the Daily Review 20-new-item allowance.
- A card already in SRS can still be rated from Flashcards.

### SRS calendar behavior
- A one-day review completed late at night is due the next calendar day, not the same clock time 24 hours later.

---

# Files intentionally not redesigned in this pass

This pass deliberately did **not** include:
- Main-screen UI redesign
- New animations / 120 Hz motion work
- Journey merge
- New learning modes
- Listening/audio-content expansion
- New account/cloud features
- CI hardening/release signing
- Exhaustive `common_words` cleanup

Those should remain separate tasks so this stabilization pass stays auditable and low risk.

---

# Final product decision after this pass

The underlying Kanji/Sentence training architecture should now be considered **feature-frozen** unless a genuine correctness bug is found during Flutter/device testing.

The next planned development phase is the **main-screen UI and animation polish**, not another learning-system redesign.

---

# Exact file inventory versus the base project

ADDED (7)
- `docs/TRAINING_QUALITY_STABILIZATION_2026-10-06.md`
- `lib/utils/quiz_options.dart`
- `test/item_progress_calendar_test.dart`
- `test/quiz_options_test.dart`
- `tool/apply_kanji_content_corrections.py`
- `tool/kanji_content_corrections.json`
- `tool/validate_training_quality.py`

CHANGED (16)
- `assets/data/kanji.json`
- `assets/data/kanji_questions.json`
- `lib/models/item_progress.dart`
- `lib/screens/daily_review_screen.dart`
- `lib/screens/daily_review_summary_screen.dart`
- `lib/screens/flashcard_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/kanji_mode_screen.dart`
- `lib/screens/sentence_mode_screen.dart`
- `lib/screens/test_run_screen.dart`
- `lib/screens/test_setup_screen.dart`
- `lib/services/progress_service.dart`
- `test/content_leveling_test.dart`
- `test/progress_daily_limit_test.dart`
- `tool/merge_kanji_dataset.py`
- `tool/regenerate_kanji_questions.py`

REMOVED (0)

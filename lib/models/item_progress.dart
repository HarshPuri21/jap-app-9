import 'dart:math' as math;

/// A review rating, in the classic Again / Hard / Good / Easy scale.
enum Rating { again, hard, good, easy }

const double kMinEase = 1.3;
const double kInitialEase = 2.5;
const int kMaxIntervalDays = 730; // 2-year safety cap

/// Per-item spaced-repetition state. One of these exists per vocab word or
/// kanji the user has reviewed at least once; items never reviewed simply
/// have no entry (see ProgressService.buildDailyQueue).
///
/// This is a small, self-contained SM-2-style algorithm (the same family
/// Anki is built on), simplified to day-level granularity -- there's no
/// "review again in 10 minutes" learning phase, which keeps the model easy
/// to reason about for an app that's opened a few times a day rather than
/// kept running.
class ItemProgress {
  int repetitions;
  double ease;
  int intervalDays;
  int lapses;
  DateTime dueDate;
  /// When this item first entered SRS. Null on legacy progress records that
  /// predate this field; ProgressService intentionally does not backfill it.
  DateTime? firstReviewed;
  DateTime? lastReviewed;

  ItemProgress({
    this.repetitions = 0,
    this.ease = kInitialEase,
    this.intervalDays = 0,
    this.lapses = 0,
    DateTime? dueDate,
    this.firstReviewed,
    this.lastReviewed,
  }) : dueDate = dueDate ?? DateTime.now();

  /// Applies a rating and advances the item's schedule in place. Verified
  /// against a battery of sequences (always-good, always-hard, always-easy,
  /// a lapse-and-recover sequence, and 50x single-button spam for each
  /// rating) in the Python prototype this was ported from, specifically to
  /// catch small-integer rounding traps (e.g. a naive `interval * 1.2` on
  /// interval=1 rounds right back down to 1 forever -- fixed below with an
  /// explicit `+1` floor on "hard").
  void apply(Rating rating, {DateTime? now}) {
    final at = now ?? DateTime.now();
    switch (rating) {
      case Rating.again:
        repetitions = 0;
        intervalDays = 1;
        ease = math.max(kMinEase, ease - 0.20);
        lapses += 1;
        break;
      case Rating.hard:
        // +1 floor prevents small intervals from getting stuck -- a naive
        // `interval * 1.2` on interval=1 rounds right back down to 1
        // forever otherwise (verified in the Python prototype).
        intervalDays = math.max(intervalDays + 1, (intervalDays * 1.2).round());
        ease = math.max(kMinEase, ease - 0.15);
        repetitions += 1;
        break;
      case Rating.good:
        repetitions += 1;
        if (repetitions == 1) {
          intervalDays = 1;
        } else if (repetitions == 2) {
          intervalDays = 6;
        } else {
          intervalDays = (intervalDays * ease).round();
        }
        break;
      case Rating.easy:
        repetitions += 1;
        if (repetitions == 1) {
          intervalDays = 4;
        } else {
          intervalDays = (intervalDays * ease * 1.3).round();
        }
        ease = ease + 0.15;
        break;
    }
    intervalDays = math.max(1, math.min(intervalDays, kMaxIntervalDays));
    lastReviewed = at;
    // This SRS is intentionally day-granular. Schedule to local midnight
    // on the target calendar day instead of preserving the review clock
    // time (e.g. a Monday 22:45 review with a 1-day interval is due on
    // Tuesday, not Tuesday at 22:45). Using the DateTime constructor also
    // follows local calendar-day rollover across DST changes.
    dueDate = DateTime(at.year, at.month, at.day + intervalDays);
  }

  bool get isDue => !dueDate.isAfter(DateTime.now());

  /// A non-mutating preview of what rating [rating] would set intervalDays
  /// to, without touching this item's real state. Used to show a small
  /// "Good → 6d" style hint on each rating button before the user taps it.
  int previewIntervalDays(Rating rating) {
    final clone = ItemProgress(
      repetitions: repetitions,
      ease: ease,
      intervalDays: intervalDays,
      lapses: lapses,
      dueDate: dueDate,
      firstReviewed: firstReviewed,
      lastReviewed: lastReviewed,
    );
    clone.apply(rating);
    return clone.intervalDays;
  }

  /// "new" (never reviewed -- caller distinguishes this by absence, not via
  /// this field), "learning" (a handful of reviews in, still short
  /// intervals), or "review" (graduated to longer intervals).
  String get stage {
    if (repetitions == 0) return 'learning';
    if (intervalDays < 21) return 'learning';
    return 'review';
  }

  Map<String, dynamic> toJson() => {
        'reps': repetitions,
        'ease': ease,
        'interval': intervalDays,
        'lapses': lapses,
        'due': dueDate.toIso8601String(),
        'first': firstReviewed?.toIso8601String(),
        'last': lastReviewed?.toIso8601String(),
      };

  factory ItemProgress.fromJson(Map<String, dynamic> json) {
    final parsedDue = json['due'] != null
        ? DateTime.tryParse(json['due'] as String)
        : null;
    // Migrate older clock-time schedules to the same local calendar-day
    // semantics used for newly rated items. The due *date* is preserved;
    // only an obsolete hour/minute component is removed.
    final dueDay = parsedDue == null
        ? DateTime.now()
        : DateTime(parsedDue.year, parsedDue.month, parsedDue.day);
    return ItemProgress(
      repetitions: json['reps'] as int? ?? 0,
      ease: (json['ease'] as num?)?.toDouble() ?? kInitialEase,
      intervalDays: json['interval'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
      dueDate: dueDay,
      firstReviewed: json['first'] != null
          ? DateTime.tryParse(json['first'] as String)
          : null,
      lastReviewed: json['last'] != null
          ? DateTime.tryParse(json['last'] as String)
          : null,
    );
  }
}

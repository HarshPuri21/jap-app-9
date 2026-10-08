import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_trainer/models/item_progress.dart';

void main() {
  test('day-level SRS is due at midnight on the target local calendar day', () {
    final item = ItemProgress();
    final reviewedAt = DateTime(2026, 10, 6, 22, 45);

    item.apply(Rating.good, now: reviewedAt);

    expect(item.intervalDays, 1);
    expect(item.dueDate, DateTime(2026, 10, 7));
    expect(item.lastReviewed, reviewedAt);
  });

  test('multi-day intervals also normalize to calendar midnight', () {
    final item = ItemProgress();
    final reviewedAt = DateTime(2026, 10, 6, 23, 59);

    item.apply(Rating.easy, now: reviewedAt);

    expect(item.intervalDays, 4);
    expect(item.dueDate, DateTime(2026, 10, 10));
  });

  test('legacy due timestamps migrate to midnight without changing date', () {
    final item = ItemProgress.fromJson({
      'reps': 2,
      'ease': 2.5,
      'interval': 6,
      'lapses': 0,
      'due': '2026-10-12T22:45:00.000',
    });

    expect(item.dueDate, DateTime(2026, 10, 12));
  });
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item_progress.dart';
import 'data_service.dart';

/// How many never-studied items to introduce per day, on top of whatever
/// is genuinely due for review. Reviews are never capped -- only new-item
/// introduction is -- otherwise day one would dump the entire vocab+kanji
/// collection into a single overwhelming queue.
const int kNewItemsPerDay = 20;

/// A stable identity for a vocab word or kanji, used as the progress-map
/// key. Vocab and kanji sometimes share characters (a kanji and a vocab
/// word can both be "食"), so both are prefixed to stay unambiguous.
String vocabItemId(String jp) => 'vocab:$jp';
String kanjiItemId(String kanji) => 'kanji:$kanji';

class ProgressService extends ChangeNotifier {
  static const _kProgressMap = 'srs_progress_v1';

  final Map<String, ItemProgress> _progress = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProgressMap);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _progress[entry.key] =
              ItemProgress.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } catch (e) {
      // A corrupted or unreadable prefs blob shouldn't take the app down --
      // worst case, progress resets, which is far better than a crash loop.
      debugPrint('ProgressService.load failed, starting fresh: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _progress.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_kProgressMap, encoded);
    } catch (e) {
      debugPrint('ProgressService.save failed (progress kept in memory): $e');
    }
  }

  ItemProgress? progressFor(String itemId) => _progress[itemId];

  bool hasBeenStudied(String itemId) => _progress.containsKey(itemId);

  /// Records a rating for an item, creating its progress record on first
  /// review. Persists immediately -- review volume is human-paced (button
  /// taps), so there's no performance reason to batch writes, and immediate
  /// persistence is what makes "is progress saved reliably" actually true.
  Future<void> rate(String itemId, Rating rating) async {
    final now = DateTime.now();
    final isNew = !_progress.containsKey(itemId);
    final item = _progress[itemId] ?? ItemProgress();

    // `firstReviewed` is set only when an SRS record is genuinely created.
    // Older installs already have progress records without this field; if we
    // set it on their next review they would be miscounted as brand-new items
    // and incorrectly consume today's 20-item introduction allowance.
    if (isNew) item.firstReviewed = now;
    item.apply(rating, now: now);
    _progress[itemId] = item;
    notifyListeners();
    await _save();
  }

  /// Rates an item only if it has already entered SRS. Returns false for an
  /// unseen item without creating progress. Flashcards use this to remain
  /// unrestricted practice while Daily Review stays the single controlled
  /// path for the 20-new-items/day intake.
  Future<bool> rateIfStudied(String itemId, Rating rating) async {
    if (!_progress.containsKey(itemId)) return false;
    await rate(itemId, rating);
    return true;
  }

  /// All vocab + kanji item IDs currently known to the app (used to find
  /// which ones are "new", i.e. absent from the progress map).
  List<String> _allItemIds() {
    final ds = DataService.instance;
    return [
      ...ds.vocab.map((v) => vocabItemId(v.jp)),
      ...ds.kanjiEntries.map((k) => kanjiItemId(k.kanji)),
    ];
  }

  int get dueCount {
    final now = DateTime.now();
    // Count only content that still exists in the current bundled dataset.
    // A stale progress key from an older dataset must never create a phantom
    // review badge that buildDailyQueue() cannot actually resolve.
    return _allItemIds().where((id) {
      final p = _progress[id];
      return p != null && !p.dueDate.isAfter(now);
    }).length;
  }

  int get newAvailableCount {
    final known = _progress.keys.toSet();
    return _allItemIds().where((id) => !known.contains(id)).length;
  }

  bool _isToday(DateTime? value, DateTime now) =>
      value != null &&
      value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;

  /// How many previously unseen items were introduced into SRS today.
  ///
  /// This is deliberately based on the persisted first-review timestamp,
  /// rather than "reviews completed today". Re-reviewing an old item must
  /// not consume the daily new-item allowance. Unseen Flashcards are
  /// intentionally practice-only; Daily Review is the one controlled path
  /// that introduces brand-new items into SRS.
  int get newItemsIntroducedTodayCount {
    final now = DateTime.now();
    return _progress.values.where((p) => _isToday(p.firstReviewed, now)).length;
  }

  /// Remaining capacity in today's 20-new-items allowance, before checking
  /// whether enough unseen content actually exists.
  int get newItemAllowanceRemaining {
    final remaining = kNewItemsPerDay - newItemsIntroducedTodayCount;
    return remaining > 0 ? remaining : 0;
  }

  /// Number of new items that can actually be added to the next Daily Review
  /// queue right now. This is the smaller of the daily allowance and the
  /// number of unseen vocab/kanji items left in the dataset.
  int get newItemsAvailableToday {
    final available = newAvailableCount;
    final allowance = newItemAllowanceRemaining;
    return available < allowance ? available : allowance;
  }

  /// How many items today's queue will contain, without actually building
  /// (and shuffling) it -- cheap enough to call from the home screen badge.
  int get todayQueueSize {
    final due = dueCount;
    return due + newItemsAvailableToday;
  }

  /// Never-studied content in a learner-safe introduction order.
  ///
  /// Vocabulary has no JLPT metadata in the current dataset, so its curated
  /// source order is preserved. Kanji *does* have JLPT metadata and is
  /// introduced N5 -> N4 -> N3 -> N2 -> N1 -> unlevelled. Characters are
  /// shuffled within a level so two learners do not get an identical kanji
  /// sequence while still being protected from N1 material on day one.
  /// The two streams are then interleaved so Daily Review remains a balanced
  /// vocab+kanji trainer instead of serving all 533 vocab items first.
  List<String> _freshIdsInLearningOrder() {
    final ds = DataService.instance;
    final known = _progress.keys.toSet();

    final freshVocab = ds.vocab
        .map((v) => vocabItemId(v.jp))
        .where((id) => !known.contains(id))
        .toList();

    final kanjiByRank = <int, List<String>>{};
    for (final k in ds.kanjiEntries) {
      final id = kanjiItemId(k.kanji);
      if (known.contains(id)) continue;
      final rank = k.jlptLevel?.index ?? 99;
      (kanjiByRank[rank] ??= <String>[]).add(id);
    }
    final ranks = kanjiByRank.keys.toList()..sort();
    final freshKanji = <String>[];
    for (final rank in ranks) {
      final levelItems = kanjiByRank[rank]!..shuffle();
      freshKanji.addAll(levelItems);
    }

    final interleaved = <String>[];
    var vocabIndex = 0;
    var kanjiIndex = 0;
    while (vocabIndex < freshVocab.length || kanjiIndex < freshKanji.length) {
      if (vocabIndex < freshVocab.length) {
        interleaved.add(freshVocab[vocabIndex++]);
      }
      if (kanjiIndex < freshKanji.length) {
        interleaved.add(freshKanji[kanjiIndex++]);
      }
    }
    return interleaved;
  }

  /// Today's review queue: every item genuinely due, plus up to
  /// [kNewItemsPerDay] never-studied items in the learning order above.
  /// The final queue is shuffled only for presentation; content selection
  /// happens first, so shuffling can never pull an advanced kanji forward.
  List<String> buildDailyQueue({int newItemCap = kNewItemsPerDay}) {
    final now = DateTime.now();
    final due = <String>[];

    for (final id in _allItemIds()) {
      final p = _progress[id];
      if (p != null && !p.dueDate.isAfter(now)) {
        due.add(id);
      }
    }

    final allowance = newItemsAvailableToday;
    final effectiveCap = newItemCap < allowance ? newItemCap : allowance;
    final newBatch = _freshIdsInLearningOrder().take(effectiveCap).toList();
    final queue = [...due, ...newBatch];
    queue.shuffle();
    return queue;
  }

  /// Resolves an item ID back to its displayable vocab/kanji entry. Returns
  /// null if the ID doesn't match anything currently loaded (defensive --
  /// e.g. app data changed between sessions).
  dynamic resolveItem(String itemId) {
    final ds = DataService.instance;
    if (itemId.startsWith('vocab:')) {
      final jp = itemId.substring('vocab:'.length);
      for (final v in ds.vocab) {
        if (v.jp == jp) return v;
      }
    } else if (itemId.startsWith('kanji:')) {
      final k = itemId.substring('kanji:'.length);
      for (final entry in ds.kanjiEntries) {
        if (entry.kanji == k) return entry;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Dashboard/reporting helpers. All read-only and derived from the same
  // `_progress` map the SRS engine already maintains -- nothing new is
  // tracked here, so these are as accurate as the review history itself.
  // ---------------------------------------------------------------------

  /// How many items with the given id prefix ('vocab:' or 'kanji:') have
  /// ever been reviewed at least once -- i.e. "coverage" of that category,
  /// out of however many exist in total (caller supplies the denominator
  /// from DataService, since this service doesn't own the content lists).
  int countByPrefix(String prefix) =>
      _progress.keys.where((k) => k.startsWith(prefix)).length;

  /// How many items with the given id prefix are currently due, without
  /// pulling in "new" (never-studied) items the way [buildDailyQueue] does
  /// -- used for the due-count breakdown on the review summary screen.
  int dueCountByPrefix(String prefix) {
    final now = DateTime.now();
    return _allItemIds().where((id) {
      if (!id.startsWith(prefix)) return false;
      final p = _progress[id];
      return p != null && !p.dueDate.isAfter(now);
    }).length;
  }

  /// Reviews completed *today*, read straight from each item's real
  /// [ItemProgress.lastReviewed] timestamp -- this was already being
  /// persisted for the SRS algorithm's own use, so it's exact and, unlike a
  /// freshly-added counter, correct even for review sessions that happened
  /// before this stat existed.
  int get reviewedTodayCount {
    final now = DateTime.now();
    return _progress.values.where((p) {
      final last = p.lastReviewed;
      return _isToday(last, now);
    }).length;
  }

  /// The [count] items with the most lapses (times rated "Again"), as
  /// `(itemId, lapses)` pairs, highest first. Only items with at least one
  /// lapse are included, so a clean history returns an empty list rather
  /// than padding with items that aren't actually weak.
  List<MapEntry<String, int>> weakestItemIds({int count = 5}) {
    final withLapses = _progress.entries
        .where((e) => e.value.lapses > 0)
        .map((e) => MapEntry(e.key, e.value.lapses))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return withLapses.take(count).toList();
  }

  /// The [count] most recently reviewed items, most recent first -- for a
  /// "recent activity" list. Items with no review yet (no `lastReviewed`)
  /// can't have one, so they're excluded rather than sorted arbitrarily.
  List<MapEntry<String, ItemProgress>> recentlyReviewed({int count = 5}) {
    final reviewed = _progress.entries
        .where((e) => e.value.lastReviewed != null)
        .toList()
      ..sort((a, b) => b.value.lastReviewed!.compareTo(a.value.lastReviewed!));
    return reviewed.take(count).toList();
  }
}

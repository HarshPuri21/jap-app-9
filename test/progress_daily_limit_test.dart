import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nihongo_trainer/models/item_progress.dart';
import 'package:nihongo_trainer/models/kanji_entry.dart';
import 'package:nihongo_trainer/models/jlpt_level.dart';
import 'package:nihongo_trainer/models/vocab_entry.dart';
import 'package:nihongo_trainer/services/data_service.dart';
import 'package:nihongo_trainer/services/progress_service.dart';

VocabEntry _vocab(int i) => VocabEntry(
      jp: '語$i',
      kana: 'ご$i',
      romaji: 'go$i',
      meaning: 'word $i',
      category: 'test',
      pos: 'noun',
    );

KanjiEntry _kanji(String char, JlptLevel level) => KanjiEntry(
      kanji: char,
      onyomi: const [],
      kunyomi: const [],
      meaning: 'meaning $char',
      breakdown: null,
      isRadical: false,
      commonWords: const [],
      jlptLevel: level,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DataService.instance.vocab = List.generate(30, _vocab);
    DataService.instance.kanjiEntries = [];
  });

  test('Daily Review introduces at most 20 new SRS items per local day', () async {
    final progress = ProgressService();
    await progress.load();

    expect(progress.todayQueueSize, kNewItemsPerDay);
    expect(progress.newItemsIntroducedTodayCount, 0);
    expect(progress.newItemsAvailableToday, kNewItemsPerDay);

    final firstQueue = progress.buildDailyQueue();
    expect(firstQueue, hasLength(kNewItemsPerDay));

    // Introduce seven new items, then leave the session. Re-entering Daily
    // Review must offer only the remaining thirteen new slots, not another
    // fresh batch of twenty.
    for (final id in firstQueue.take(7)) {
      await progress.rate(id, Rating.good);
    }
    expect(progress.newItemsIntroducedTodayCount, 7);
    expect(progress.newItemAllowanceRemaining, 13);
    expect(progress.newItemsAvailableToday, 13);
    expect(progress.buildDailyQueue(), hasLength(13));

    final secondQueue = progress.buildDailyQueue();
    for (final id in secondQueue) {
      await progress.rate(id, Rating.good);
    }
    expect(progress.newItemsIntroducedTodayCount, kNewItemsPerDay);
    expect(progress.newItemAllowanceRemaining, 0);
    expect(progress.newItemsAvailableToday, 0);
    expect(progress.todayQueueSize, 0);
    expect(progress.buildDailyQueue(), isEmpty);

    // The cap survives an app/service restart because firstReviewed is
    // persisted with each newly introduced item.
    final reloaded = ProgressService();
    await reloaded.load();
    expect(reloaded.newItemsIntroducedTodayCount, kNewItemsPerDay);
    expect(reloaded.newItemsAvailableToday, 0);
    expect(reloaded.todayQueueSize, 0);
  });

  test('new Daily Review kanji are introduced N5 before advanced levels', () async {
    DataService.instance.vocab = List.generate(20, _vocab);
    // Deliberately put N1 first to prove queue selection uses JLPT rank, not
    // whatever order the data happened to be assigned in this test.
    DataService.instance.kanjiEntries = [
      for (var i = 0; i < 12; i++) _kanji('高$i', JlptLevel.n1),
      for (var i = 0; i < 12; i++) _kanji('基$i', JlptLevel.n5),
    ];

    final progress = ProgressService();
    await progress.load();
    final queue = progress.buildDailyQueue();

    expect(queue, hasLength(kNewItemsPerDay));
    final kanjiIds = queue.where((id) => id.startsWith('kanji:')).toList();
    final vocabIds = queue.where((id) => id.startsWith('vocab:')).toList();
    expect(kanjiIds, hasLength(10));
    expect(vocabIds, hasLength(10));
    expect(kanjiIds.every((id) => id.startsWith('kanji:基')), isTrue);
    expect(vocabIds.toSet(), {for (var i = 0; i < 10; i++) 'vocab:語$i'});
  });

  test('practice-only rating does not introduce an unseen Flashcard into SRS', () async {
    final progress = ProgressService();
    await progress.load();
    const id = 'vocab:語0';

    expect(await progress.rateIfStudied(id, Rating.good), isFalse);
    expect(progress.hasBeenStudied(id), isFalse);
    expect(progress.newItemsIntroducedTodayCount, 0);

    await progress.rate(id, Rating.good);
    final before = progress.progressFor(id)!.repetitions;
    expect(await progress.rateIfStudied(id, Rating.good), isTrue);
    expect(progress.progressFor(id)!.repetitions, greaterThan(before));
  });

  test('legacy progress without firstReviewed does not consume new allowance',
      () async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      'srs_progress_v1': jsonEncode({
        'vocab:語0': {
          'reps': 3,
          'ease': 2.5,
          'interval': 6,
          'lapses': 0,
          'due': tomorrow.toIso8601String(),
          'last': now.toIso8601String(),
          // Deliberately no "first" key: this is an old-install record.
        },
      }),
    });

    final progress = ProgressService();
    await progress.load();

    expect(progress.hasBeenStudied('vocab:語0'), isTrue);
    expect(progress.newItemsIntroducedTodayCount, 0);
    expect(progress.newItemAllowanceRemaining, kNewItemsPerDay);
    expect(progress.newItemsAvailableToday, kNewItemsPerDay);

    // Reviewing that existing legacy item today still must not reclassify it
    // as newly introduced.
    await progress.rate('vocab:語0', Rating.good);
    expect(progress.newItemsIntroducedTodayCount, 0);
  });
}

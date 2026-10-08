import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import '../models/sentence.dart';
import '../models/kanji_question.dart';
import '../models/vocab_entry.dart';
import '../models/kanji_entry.dart';
import '../models/jlpt_level.dart';
import '../models/radical_entry.dart';
import '../models/radical_question.dart';
import '../models/kana_entry.dart';

/// Loads the precomputed data files (bundled as Flutter assets, built from
/// the exact same tested Python pipeline as the desktop app) once at app
/// startup, and hands out shuffled/filtered views of them.
class DataService {
  static final DataService instance = DataService._internal();
  DataService._internal();

  List<Sentence> sentences = [];

  /// Sentences grouped by [Sentence.familyId], built once at load time.
  /// Only sentences that belong to a family appear here -- the original
  /// (pre-family) sentences have a null familyId and are simply absent from
  /// this map, not present under a null/empty key.
  Map<String, List<Sentence>> sentenceFamilies = {};

  List<KanjiQuestion> kanjiQuestions = [];
  List<VocabEntry> vocab = [];
  List<KanjiEntry> kanjiEntries = [];
  List<RadicalEntry> radicals = [];
  List<RadicalQuestion> radicalQuestions = [];
  List<KanaEntry> kana = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    final sentencesRaw =
        await rootBundle.loadString('assets/data/sentences.json');
    sentences = (jsonDecode(sentencesRaw) as List<dynamic>)
        .map((e) => Sentence.fromJson(e as Map<String, dynamic>))
        .toList();
    sentenceFamilies = {};
    for (final s in sentences) {
      final fid = s.familyId;
      if (fid == null) continue;
      (sentenceFamilies[fid] ??= <Sentence>[]).add(s);
    }

    final kanjiQRaw =
        await rootBundle.loadString('assets/data/kanji_questions.json');
    kanjiQuestions = (jsonDecode(kanjiQRaw) as List<dynamic>)
        .map((e) => KanjiQuestion.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort(_compareKanjiQuestionsByLevel);

    final vocabRaw = await rootBundle.loadString('assets/data/vocab.json');
    vocab = (jsonDecode(vocabRaw) as List<dynamic>)
        .map((e) => VocabEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final kanjiRaw = await rootBundle.loadString('assets/data/kanji.json');
    kanjiEntries = (jsonDecode(kanjiRaw) as List<dynamic>)
        .map((e) => KanjiEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort(_compareKanjiEntriesByLevel);

    final radicalsRaw =
        await rootBundle.loadString('assets/data/radicals.json');
    radicals = (jsonDecode(radicalsRaw) as List<dynamic>)
        .map((e) => RadicalEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final radicalQRaw =
        await rootBundle.loadString('assets/data/radical_questions.json');
    radicalQuestions = (jsonDecode(radicalQRaw) as List<dynamic>)
        .map((e) => RadicalQuestion.fromJson(e as Map<String, dynamic>))
        .toList();

    final kanaRaw = await rootBundle.loadString('assets/data/kana.json');
    kana = (jsonDecode(kanaRaw) as List<dynamic>)
        .map((e) => KanaEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    _loaded = true;
  }

  List<Sentence> sentencesByDifficulty(String difficulty) {
    if (difficulty == 'all') return sentences;
    return sentences.where((s) => s.difficulty == difficulty).toList();
  }

  /// Same idea as [sentencesByDifficulty], filtering by JLPT level instead
  /// -- added alongside it for "Learn Sentences"'s N5-N1 chip row.
  /// `level == null` returns every sentence regardless of level (including
  /// ones with no level at all), matching how `'all'` works above.
  List<Sentence> sentencesByJlpt(JlptLevel? level) {
    if (level == null) return sentences;
    return sentences.where((s) => s.jlptLevel == level).toList();
  }

  List<KanjiQuestion> kanjiByDifficulty(String difficulty) {
    if (difficulty == 'all') return kanjiQuestions;
    return kanjiQuestions.where((k) => k.difficulty == difficulty).toList();
  }

  /// Primary kanji learning filter: JLPT N5 -> N1. `null` means all levels
  /// and also keeps the small set of kanji that currently have no JLPT tag.
  List<KanjiQuestion> kanjiByJlpt(JlptLevel? level) {
    if (level == null) return kanjiQuestions;
    return kanjiQuestions.where((k) => k.jlptLevel == level).toList();
  }

  List<RadicalQuestion> radicalsByDifficulty(String difficulty) {
    if (difficulty == 'all') return radicalQuestions;
    return radicalQuestions.where((r) => r.difficulty == difficulty).toList();
  }

  /// Returns `count` shuffled sentences at the given difficulty (or all
  /// difficulties mixed if `difficulty == 'all'`). `count <= 0` returns the
  /// whole (shuffled) pool.
  List<Sentence> drawSentences(String difficulty, int count) {
    final pool = List<Sentence>.from(sentencesByDifficulty(difficulty));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  /// Same idea as [drawSentences], filtering by JLPT level instead of the
  /// difficulty string. Used anywhere sentence content has a learner-facing
  /// level selector (Learn Sentences and sentence-only tests).
  List<Sentence> drawSentencesByJlpt(JlptLevel? level, int count) {
    final pool = List<Sentence>.from(sentencesByJlpt(level));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  List<KanjiQuestion> drawKanji(String difficulty, int count) {
    final pool = List<KanjiQuestion>.from(kanjiByDifficulty(difficulty));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  /// JLPT-first version used by Learn Kanji and kanji-only tests. Difficulty
  /// remains stored/displayed as secondary metadata, but JLPT is the primary
  /// learner-facing level wherever that metadata exists.
  List<KanjiQuestion> drawKanjiByJlpt(JlptLevel? level, int count) {
    final pool = List<KanjiQuestion>.from(kanjiByJlpt(level));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  List<RadicalQuestion> drawRadicals(String difficulty, int count) {
    final pool = List<RadicalQuestion>.from(radicalsByDifficulty(difficulty));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  /// A mixed test pulls from sentences, kanji, and radical questions,
  /// tagging each item by its runtime type so the UI can render any of them.
  List<dynamic> drawMixed(String difficulty, int count) {
    final pool = <dynamic>[
      ...sentencesByDifficulty(difficulty),
      ...kanjiByDifficulty(difficulty),
      ...radicalsByDifficulty(difficulty),
    ];
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  /// The recommended browsing/learning order for kana groups (see
  /// instructions.txt's "RECOMMENDED LEARNING ORDER"). 'special' (ゔ/ヴ) is
  /// folded in with 'small' in the UI, since the source material presents
  /// them under one combined heading.
  static const List<KanaGroup> kanaGroupOrder = [
    KanaGroup.basic,
    KanaGroup.dakuten,
    KanaGroup.handakuten,
    KanaGroup.yoon,
    KanaGroup.small,
    KanaGroup.special,
    KanaGroup.extendedKatakana,
  ];

  List<KanaEntry> kanaByType(KanaType type) =>
      kana.where((k) => k.type == type).toList();

  List<KanaEntry> kanaByGroup(KanaType type, KanaGroup group) =>
      kana.where((k) => k.type == type && k.group == group).toList();
}

// ---------------------------------------------------------------------
// Kanji ordering: N5 (easiest) through N1 (hardest), entries the JLPT
// dataset doesn't cover sorted last. Applied once at load time so every
// screen that reads kanjiEntries/kanjiQuestions sees a graded order by
// default, rather than the merge script's old-entries-then-new-entries
// append order. The kanji character itself breaks any remaining tie, for a
// fully deterministic order independent of the underlying JSON's order.
// ---------------------------------------------------------------------

int _jlptRank(JlptLevel? level) => level?.index ?? JlptLevel.values.length;

int _difficultyRank(String difficulty) => switch (difficulty) {
      'easy' => 0,
      'normal' => 1,
      'hard' => 2,
      _ => 3,
    };

int _compareKanjiEntriesByLevel(KanjiEntry a, KanjiEntry b) {
  final levelCompare = _jlptRank(a.jlptLevel).compareTo(_jlptRank(b.jlptLevel));
  if (levelCompare != 0) return levelCompare;
  return a.kanji.compareTo(b.kanji);
}

/// Same as [_compareKanjiEntriesByLevel], with an extra easy/normal/hard
/// tier within each JLPT level -- meaningful mainly for the entries with no
/// JLPT level, where difficulty isn't otherwise implied by anything else;
/// for leveled entries difficulty is derived from the level itself (see
/// tool/regenerate_kanji_questions.py), so this rarely changes their order
/// beyond what sorting by level alone would already do.
int _compareKanjiQuestionsByLevel(KanjiQuestion a, KanjiQuestion b) {
  final levelCompare = _jlptRank(a.jlptLevel).compareTo(_jlptRank(b.jlptLevel));
  if (levelCompare != 0) return levelCompare;
  final difficultyCompare =
      _difficultyRank(a.difficulty).compareTo(_difficultyRank(b.difficulty));
  if (difficultyCompare != 0) return difficultyCompare;
  return a.kanji.compareTo(b.kanji);
}

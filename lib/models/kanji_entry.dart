import 'jlpt_level.dart';
import 'kanji_question.dart';

class KanjiEntry {
  final String kanji;
  final List<String> onyomi;
  final List<String> kunyomi;
  final String meaning;
  final String? breakdown;
  final bool isRadical;
  final List<CommonWord> commonWords;

  /// JLPT level (N5 easiest .. N1 hardest), when known. Additive/optional --
  /// entries from before this field existed, or kanji the JLPT dataset
  /// simply doesn't cover, have this as null rather than a required guess.
  final JlptLevel? jlptLevel;

  KanjiEntry({
    required this.kanji,
    required this.onyomi,
    required this.kunyomi,
    required this.meaning,
    required this.breakdown,
    required this.isRadical,
    required this.commonWords,
    this.jlptLevel,
  });

  factory KanjiEntry.fromJson(Map<String, dynamic> json) {
    return KanjiEntry(
      kanji: json['kanji'] as String,
      onyomi:
          (json['onyomi'] as List<dynamic>).map((e) => e as String).toList(),
      kunyomi:
          (json['kunyomi'] as List<dynamic>).map((e) => e as String).toList(),
      meaning: json['meaning'] as String,
      breakdown: json['breakdown'] as String?,
      isRadical: json['is_radical'] as bool,
      commonWords: (json['common_words'] as List<dynamic>)
          .map((e) => CommonWord.fromJson(e as Map<String, dynamic>))
          .toList(),
      jlptLevel: JlptLevel.fromJson(json['jlpt_level'] as String?),
    );
  }
}

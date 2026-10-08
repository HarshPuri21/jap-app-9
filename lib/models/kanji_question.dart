import 'jlpt_level.dart';

class CommonWord {
  final String word;
  final String meaning;
  final String reading;

  CommonWord({required this.word, required this.meaning, required this.reading});

  factory CommonWord.fromJson(Map<String, dynamic> json) {
    return CommonWord(
      word: json['word'] as String,
      meaning: json['meaning'] as String,
      reading: json['reading'] as String,
    );
  }
}

class KanjiQuestion {
  final String kanji;
  final String meaning;
  final List<String> onyomi;
  final List<String> kunyomi;
  final String? breakdown;
  final List<CommonWord> commonWords;
  final bool isRadical;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final List<String> options;
  final String answer;

  /// JLPT level (N5 easiest .. N1 hardest), when known. Additive/optional,
  /// same as on [KanjiEntry] -- see that field's doc comment. `difficulty`
  /// is derived from this at generation time (tool/regenerate_kanji_questions.py)
  /// but kept as its own stored field since it's what the existing 3-tier
  /// quiz UI already reads.
  final JlptLevel? jlptLevel;

  KanjiQuestion({
    required this.kanji,
    required this.meaning,
    required this.onyomi,
    required this.kunyomi,
    required this.breakdown,
    required this.commonWords,
    required this.isRadical,
    required this.difficulty,
    required this.options,
    required this.answer,
    this.jlptLevel,
  });

  factory KanjiQuestion.fromJson(Map<String, dynamic> json) {
    return KanjiQuestion(
      kanji: json['kanji'] as String,
      meaning: json['meaning'] as String,
      onyomi:
          (json['onyomi'] as List<dynamic>).map((e) => e as String).toList(),
      kunyomi:
          (json['kunyomi'] as List<dynamic>).map((e) => e as String).toList(),
      breakdown: json['breakdown'] as String?,
      commonWords: (json['common_words'] as List<dynamic>)
          .map((e) => CommonWord.fromJson(e as Map<String, dynamic>))
          .toList(),
      isRadical: json['is_radical'] as bool,
      difficulty: json['difficulty'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      answer: json['answer'] as String,
      jlptLevel: JlptLevel.fromJson(json['jlpt_level'] as String?),
    );
  }
}

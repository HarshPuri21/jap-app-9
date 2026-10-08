/// JLPT (Japanese Language Proficiency Test) level, N5 (easiest) through
/// N1 (hardest). A closed set, so it's an enum rather than a raw String --
/// see CLAUDE.md's architecture rules.
///
/// Lives in its own file rather than alongside [KanjiEntry] or
/// [KanjiQuestion]: both models use it, neither is a natural "owner" of it,
/// and `kanji_entry.dart` already imports `kanji_question.dart` (for
/// `CommonWord`), so putting it in either would risk a circular import.
enum JlptLevel {
  n5,
  n4,
  n3,
  n2,
  n1;

  /// Parses the dataset's "N5".."N1" strings. Returns null for null or any
  /// unrecognized value -- this field is optional everywhere it's used, so
  /// a bad/missing value degrades to "unknown level" rather than a crash.
  static JlptLevel? fromJson(String? raw) => switch (raw) {
        'N5' => JlptLevel.n5,
        'N4' => JlptLevel.n4,
        'N3' => JlptLevel.n3,
        'N2' => JlptLevel.n2,
        'N1' => JlptLevel.n1,
        _ => null,
      };

  /// Round-trips back to the dataset's own "N5".."N1" spelling.
  String toJson() => label;

  /// Display label, also used as the JSON spelling -- kept as one value
  /// since "N5" already reads fine as a UI label, unlike e.g. KanaGroup's
  /// snake_case JSON keys.
  String get label => 'N${5 - index}';
}

/// Hiragana or katakana -- the two kana writing systems. Every [KanaEntry]
/// belongs to exactly one.
enum KanaType {
  hiragana,
  katakana;

  /// Parses the exact strings used in assets/data/kana.json ('hiragana' /
  /// 'katakana', which happen to equal the enum members' own [name]s).
  static KanaType fromJson(String value) => switch (value) {
        'hiragana' => KanaType.hiragana,
        'katakana' => KanaType.katakana,
        _ => throw ArgumentError('Unknown KanaType in kana.json: "$value"'),
      };

  String get label => this == KanaType.hiragana ? 'Hiragana' : 'Katakana';
}

/// Which stage/category a kana belongs to, matching instructions.txt's
/// "RECOMMENDED LEARNING ORDER" (basic -> dakuten/handakuten -> yoon ->
/// small/special -> extended katakana).
enum KanaGroup {
  basic,
  dakuten,
  handakuten,
  yoon,
  small,
  special,
  extendedKatakana;

  /// Parses the exact strings used in assets/data/kana.json. Written out
  /// explicitly (rather than `KanaGroup.values.byName(value)`) because
  /// 'extended_katakana' in the JSON is snake_case while the Dart member is
  /// camelCase -- `byName` wouldn't match it.
  static KanaGroup fromJson(String value) => switch (value) {
        'basic' => KanaGroup.basic,
        'dakuten' => KanaGroup.dakuten,
        'handakuten' => KanaGroup.handakuten,
        'yoon' => KanaGroup.yoon,
        'small' => KanaGroup.small,
        'special' => KanaGroup.special,
        'extended_katakana' => KanaGroup.extendedKatakana,
        _ => throw ArgumentError('Unknown KanaGroup in kana.json: "$value"'),
      };
}

/// One kana character -- hiragana or katakana, at any stage from the basic
/// 46 through extended katakana combinations for loanwords.
///
/// Mirrors [KanjiEntry]/[RadicalEntry] in shape (a plain data class with a
/// `fromJson` factory) so it slots into the same load/browse/quiz patterns
/// the rest of the app already uses.
class KanaEntry {
  final String character;

  /// Hepburn romaji. Empty for the sokuon (っ/ッ), which has no vowel sound
  /// of its own -- see [sound] for what it actually does.
  final String romaji;

  /// Short pronunciation/description. Usually equal to [romaji]; differs for
  /// entries where the romaji alone doesn't explain the sound (the sokuon,
  /// the moraic nasal).
  final String sound;

  final KanaType type;
  final KanaGroup group;

  final bool isSmall;

  /// The corresponding character in the other kana system (あ <-> ア), when
  /// one exists. Extended katakana combinations have no hiragana pair.
  final String? pairedKana;

  /// Usage note -- a particle-reading quirk, a duplicate-sound explanation,
  /// etc. Most entries have none.
  final String? notes;

  KanaEntry({
    required this.character,
    required this.romaji,
    required this.sound,
    required this.type,
    required this.group,
    required this.isSmall,
    required this.pairedKana,
    required this.notes,
  });

  factory KanaEntry.fromJson(Map<String, dynamic> json) {
    return KanaEntry(
      character: json['character'] as String,
      romaji: json['romaji'] as String,
      sound: json['sound'] as String,
      type: KanaType.fromJson(json['type'] as String),
      group: KanaGroup.fromJson(json['group'] as String),
      isSmall: json['isSmall'] as bool? ?? false,
      pairedKana: json['pairedKana'] as String?,
      notes: json['notes'] as String?,
    );
  }

  bool get isHiragana => type == KanaType.hiragana;
  bool get isKatakana => type == KanaType.katakana;
}

/// Display names for each kana group, in learning order. [KanaGroup.special]
/// (ゔ/ヴ) intentionally shares a label with [KanaGroup.small] -- the source
/// material presents them under one combined "small kana / special
/// pronunciation" heading, and splitting them into their own section would
/// be one more header for a single character.
const Map<KanaGroup, String> kKanaGroupLabels = {
  KanaGroup.basic: 'Basic',
  KanaGroup.dakuten: 'Dakuten',
  KanaGroup.handakuten: 'Handakuten',
  KanaGroup.yoon: 'Yōon',
  KanaGroup.small: 'Small Kana & Pronunciation',
  KanaGroup.special: 'Small Kana & Pronunciation',
  KanaGroup.extendedKatakana: 'Extended Katakana',
};

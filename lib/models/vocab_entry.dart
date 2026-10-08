class VocabEntry {
  final String jp;
  final String kana;
  final String romaji;
  final String meaning;
  final String category;
  final String pos;

  VocabEntry({
    required this.jp,
    required this.kana,
    required this.romaji,
    required this.meaning,
    required this.category,
    required this.pos,
  });

  factory VocabEntry.fromJson(Map<String, dynamic> json) {
    return VocabEntry(
      jp: json['jp'] as String,
      kana: json['kana'] as String,
      romaji: json['romaji'] as String,
      meaning: json['meaning'] as String,
      category: json['category'] as String,
      pos: json['pos'] as String,
    );
  }
}

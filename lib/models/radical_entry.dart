class RadicalExample {
  final String kanji;
  final String reading;
  final String meaning;

  RadicalExample({
    required this.kanji,
    required this.reading,
    required this.meaning,
  });

  factory RadicalExample.fromJson(Map<String, dynamic> json) {
    return RadicalExample(
      kanji: json['kanji'] as String,
      reading: json['reading'] as String,
      meaning: json['meaning'] as String,
    );
  }
}

class RadicalEntry {
  final String id;
  final String char;
  final String meaning;
  final String name;
  final String usage;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final List<RadicalExample> examples;

  RadicalEntry({
    required this.id,
    required this.char,
    required this.meaning,
    required this.name,
    required this.usage,
    required this.difficulty,
    required this.examples,
  });

  factory RadicalEntry.fromJson(Map<String, dynamic> json) {
    return RadicalEntry(
      id: json['id'] as String,
      char: json['char'] as String,
      meaning: json['meaning'] as String,
      name: json['name'] as String,
      usage: json['usage'] as String,
      difficulty: json['difficulty'] as String,
      examples: (json['examples'] as List<dynamic>)
          .map((e) => RadicalExample.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

import 'radical_entry.dart';

class RadicalQuestion {
  final String char;
  final String meaning;
  final String name;
  final String usage;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final List<RadicalExample> examples;
  final List<String> options;
  final String answer;

  RadicalQuestion({
    required this.char,
    required this.meaning,
    required this.name,
    required this.usage,
    required this.difficulty,
    required this.examples,
    required this.options,
    required this.answer,
  });

  factory RadicalQuestion.fromJson(Map<String, dynamic> json) {
    return RadicalQuestion(
      char: json['char'] as String,
      meaning: json['meaning'] as String,
      name: json['name'] as String,
      usage: json['usage'] as String,
      difficulty: json['difficulty'] as String,
      examples: (json['examples'] as List<dynamic>)
          .map((e) => RadicalExample.fromJson(e as Map<String, dynamic>))
          .toList(),
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      answer: json['answer'] as String,
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  _validateKanjiQuestionQuality();
  test(
      'sentence dataset has no exact Japanese prompt duplicated across JLPT levels',
      () {
    final raw = jsonDecode(
      File('assets/data/sentences.json').readAsStringSync(),
    ) as List<dynamic>;

    final levelsByJapanese = <String, Set<String>>{};
    for (final value in raw) {
      final row = value as Map<String, dynamic>;
      (levelsByJapanese[row['jp'] as String] ??= <String>{})
          .add(row['jlpt_level'] as String);
    }

    final crossLevelDuplicates = levelsByJapanese.entries
        .where((e) => e.value.length > 1)
        .map((e) => '${e.key}: ${e.value.toList()..sort()}')
        .toList();

    expect(
      crossLevelDuplicates,
      isEmpty,
      reason: 'Exact sentence forms should live at their lowest legitimate '
          'JLPT level rather than being relabelled at harder levels.',
    );
  });

  test('deduplication keeps the genuinely advanced forms in higher families', () {
    final raw = jsonDecode(
      File('assets/data/sentences.json').readAsStringSync(),
    ) as List<dynamic>;
    final rows = raw.cast<Map<String, dynamic>>();

    Set<String> forms(String familyId) => rows
        .where((r) => r['family_id'] == familyId)
        .map((r) => r['form'] as String)
        .toSet();

    expect(
      forms('n4_509'),
      containsAll(<String>{'potential', 'volitional'}),
    );
    expect(
      forms('n3_016'),
      contains('conditional_tara'),
    );
    expect(
      forms('n2_003'),
      containsAll(<String>{
        'potential',
        'volitional',
        'conditional_tara',
        'causative',
      }),
    );
  });
}

// The generator should keep kanji questions level-calibrated and never put a
// semantically overlapping gloss in the wrong-answer set.
void _validateKanjiQuestionQuality() {
  test('kanji distractors are same-JLPT and do not overlap answer glosses', () {
    final kanjiRaw = jsonDecode(
      File('assets/data/kanji.json').readAsStringSync(),
    ) as List<dynamic>;
    final questionRaw = jsonDecode(
      File('assets/data/kanji_questions.json').readAsStringSync(),
    ) as List<dynamic>;

    final meaningLevels = <String, Set<String?>>{};
    for (final value in kanjiRaw) {
      final row = value as Map<String, dynamic>;
      (meaningLevels[row['meaning'] as String] ??= <String?>{})
          .add(row['jlpt_level'] as String?);
    }

    Set<String> terms(String text) => text
        .replaceAll(';', ',')
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    for (final value in questionRaw) {
      final q = value as Map<String, dynamic>;
      final answer = q['answer'] as String;
      final level = q['jlpt_level'] as String?;
      final options = (q['options'] as List<dynamic>).cast<String>();
      expect(
        options,
        hasLength(4),
        reason: '${q['kanji']} must have 4 options',
      );
      expect(
        options.toSet(),
        hasLength(4),
        reason: '${q['kanji']} options must be unique',
      );
      expect(options, contains(answer));

      for (final option in options.where((o) => o != answer)) {
        expect(
          meaningLevels[option],
          contains(level),
          reason: '${q['kanji']} should use same-JLPT distractors',
        );
        expect(
          terms(option).intersection(terms(answer)),
          isEmpty,
          reason: '${q['kanji']} has an ambiguous distractor: $option',
        );
      }
    }
  });

  test('seven question has no wrong option that also says seven', () {
    final raw = jsonDecode(
      File('assets/data/kanji_questions.json').readAsStringSync(),
    ) as List<dynamic>;
    final q = raw
        .cast<Map<String, dynamic>>()
        .singleWhere((e) => e['kanji'] == '七');
    final wrong = (q['options'] as List<dynamic>)
        .cast<String>()
        .where((o) => o != q['answer']);
    expect(wrong.where((o) => o.toLowerCase().contains('seven')), isEmpty);
  });
}

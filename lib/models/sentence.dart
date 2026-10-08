import 'jlpt_level.dart';

class BreakdownChunk {
  final String chunk;
  final String? reading;
  final String? meaning;
  final String? note;

  BreakdownChunk({
    required this.chunk,
    this.reading,
    this.meaning,
    this.note,
  });

  factory BreakdownChunk.fromJson(Map<String, dynamic> json) {
    return BreakdownChunk(
      chunk: json['chunk'] as String,
      reading: json['reading'] as String?,
      meaning: json['meaning'] as String?,
      note: json['note'] as String?,
    );
  }
}

/// Which grammatical form a family member demonstrates. A closed set, so an
/// enum (see CLAUDE.md). Declaration order is the order forms are listed in
/// the "All forms in this family" view: simplest tenses first, then the
/// derived forms.
enum SentenceForm {
  presentAffirmative,
  presentNegative,
  pastAffirmative,
  pastNegative,
  teForm,
  potential,
  volitional,
  passive,
  causative,
  causativePassive,
  conditionalTara;

  /// Parses the snake_case spellings used in sentences.json. Unknown or
  /// missing values return null, matching the other optional Sentence fields.
  static SentenceForm? fromJson(String? raw) => switch (raw) {
        'present_affirmative' => SentenceForm.presentAffirmative,
        'present_negative' => SentenceForm.presentNegative,
        'past_affirmative' => SentenceForm.pastAffirmative,
        'past_negative' => SentenceForm.pastNegative,
        'te_form' => SentenceForm.teForm,
        'potential' => SentenceForm.potential,
        'volitional' => SentenceForm.volitional,
        'passive' => SentenceForm.passive,
        'causative' => SentenceForm.causative,
        'causative_passive' => SentenceForm.causativePassive,
        'conditional_tara' => SentenceForm.conditionalTara,
        _ => null,
      };

  String get label => switch (this) {
        SentenceForm.presentAffirmative => 'Present, affirmative',
        SentenceForm.presentNegative => 'Present, negative',
        SentenceForm.pastAffirmative => 'Past, affirmative',
        SentenceForm.pastNegative => 'Past, negative',
        SentenceForm.teForm => 'Te-form',
        SentenceForm.potential => 'Potential',
        SentenceForm.volitional => 'Volitional',
        SentenceForm.passive => 'Passive',
        SentenceForm.causative => 'Causative',
        SentenceForm.causativePassive => 'Causative-passive',
        SentenceForm.conditionalTara => 'Conditional (-tara)',
      };
}

/// A sentence's tone -- whether it's the casual or formal register of its
/// [Sentence.form], or has no such pairing at all. A closed set, so an enum
/// rather than a raw String (see CLAUDE.md's architecture rules).
///
/// Only `teForm` and `conditionalTara` are ever [neutral] in the current
/// dataset -- every other grammatical form comes as a casual/formal pair.
enum SentenceTone {
  casual,
  formal,
  neutral;

  static SentenceTone? fromJson(String? raw) => switch (raw) {
        'casual' => SentenceTone.casual,
        'formal' => SentenceTone.formal,
        'neutral' => SentenceTone.neutral,
        _ => null,
      };

  String get label => switch (this) {
        SentenceTone.casual => 'Casual',
        SentenceTone.formal => 'Formal',
        SentenceTone.neutral => 'Neutral',
      };
}

class Sentence {
  final String jp;

  /// Full-sentence hiragana reading of [jp]. Null for the original (pre-
  /// family) sentences, which carry per-word readings in [breakdown]
  /// instead.
  final String? reading;

  final String en;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final List<String> tags;
  final List<BreakdownChunk> breakdown;
  final List<String> options;
  final String answer;

  /// JLPT level, when known. Additive/optional -- see [KanjiEntry.jlptLevel]
  /// for the same pattern; null for the original 320 sentences unless/until
  /// they're re-graded.
  final JlptLevel? jlptLevel;

  /// Groups grammatical variants of the same underlying sentence together
  /// (e.g. every tense/register of "the teacher teaches Japanese"). Null
  /// for sentences that don't belong to a family -- the original 320 have
  /// no family grouping and this is always null for them.
  final String? familyId;

  /// Which grammatical form this is within its family. Null outside a
  /// family.
  final SentenceForm? form;

  /// Casual/formal/neutral register of [form]. Null outside a family --
  /// see [SentenceTone]'s doc comment for which forms actually pair up.
  final SentenceTone? tone;

  /// Grammar explanation for this specific form (e.g. what
  /// present_affirmative means and when it's used). Null outside a family.
  final String? explanation;

  Sentence({
    required this.jp,
    this.reading,
    required this.en,
    required this.difficulty,
    required this.tags,
    required this.breakdown,
    required this.options,
    required this.answer,
    this.jlptLevel,
    this.familyId,
    this.form,
    this.tone,
    this.explanation,
  });

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      jp: json['jp'] as String,
      reading: json['reading'] as String?,
      en: json['en'] as String,
      difficulty: json['difficulty'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      // Defaults to [] rather than being required: existing generation
      // pipelines for other content types (e.g. net-new kanji entries)
      // already leave optional detail fields empty rather than omitting
      // the record, and a sentence with no breakdown data should still
      // load and quiz correctly -- it just shows no breakdown panel.
      breakdown: json['breakdown'] == null
          ? const []
          : (json['breakdown'] as List<dynamic>)
              .map((e) => BreakdownChunk.fromJson(e as Map<String, dynamic>))
              .toList(),
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      answer: json['answer'] as String,
      jlptLevel: JlptLevel.fromJson(json['jlpt_level'] as String?),
      familyId: json['family_id'] as String?,
      form: SentenceForm.fromJson(json['form'] as String?),
      tone: SentenceTone.fromJson(json['tone'] as String?),
      explanation: json['explanation'] as String?,
    );
  }
}

/// Every tone of one grammatical form within a family -- a casual+formal
/// pair, or a lone neutral entry (te-form and conditional-tara have no pair).
/// [variants] is ordered casual, formal (or just the one neutral entry).
class SentenceFormVariants {
  final SentenceForm form;
  final List<Sentence> variants;

  SentenceFormVariants({required this.form, required this.variants});

  /// Identical across tones of the same form in the current data.
  String get explanation => variants.first.explanation ?? '';

  bool get hasTonePair => variants.length > 1;
}

#!/usr/bin/env python3
"""Offline regression audit for Nihongo Trainer's core training content/logic.

This deliberately avoids Flutter so it can be run anywhere Python is available.
It complements (not replaces) `flutter analyze` and `flutter test`.
"""
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def meaning_terms(text: str) -> set[str]:
    return {
        part.strip().casefold()
        for part in text.replace(";", ",").split(",")
        if part.strip()
    }


def main() -> int:
    errors: list[str] = []

    sentences = load(ROOT / "assets/data/sentences.json")
    kanji = load(ROOT / "assets/data/kanji.json")
    questions = load(ROOT / "assets/data/kanji_questions.json")
    corrections = load(ROOT / "tool/kanji_content_corrections.json")

    # Sentence integrity and cross-JLPT deduplication.
    levels_by_jp: dict[str, set[str]] = defaultdict(set)
    for row in sentences:
        levels_by_jp[row["jp"]].add(row["jlpt_level"])
        options = row["options"]
        if len(options) != 4 or len(set(options)) != 4 or row["answer"] not in options:
            errors.append(f"Bad sentence options: {row.get('id', row['jp'])}")
    cross_level = {jp: levels for jp, levels in levels_by_jp.items() if len(levels) > 1}
    if cross_level:
        errors.append(f"{len(cross_level)} exact Japanese prompts occur at multiple JLPT levels")

    # Kanji identity/content integrity.
    if len(kanji) != 1394:
        errors.append(f"Expected 1394 kanji entries, found {len(kanji)}")
    if len(questions) != len(kanji):
        errors.append(f"Kanji/question count mismatch: {len(kanji)} vs {len(questions)}")
    if len({row["kanji"] for row in kanji}) != len(kanji):
        errors.append("Duplicate kanji identity in kanji.json")

    by_char = {row["kanji"]: row for row in kanji}
    meaning_levels: dict[str, set[str | None]] = defaultdict(set)
    for row in kanji:
        meaning_levels[row["meaning"]].add(row.get("jlpt_level"))

    for q in questions:
        char = q["kanji"]
        source = by_char.get(char)
        if source is None:
            errors.append(f"Question references missing kanji: {char}")
            continue
        for field in ("meaning", "onyomi", "kunyomi", "jlpt_level"):
            if q[field] != source[field]:
                errors.append(f"Question/source mismatch: {char}.{field}")
        options = q["options"]
        answer = q["answer"]
        level = q.get("jlpt_level")
        if len(options) != 4 or len(set(options)) != 4 or answer not in options:
            errors.append(f"Invalid 4-choice set: {char}")
            continue
        for option in options:
            if option == answer:
                continue
            if level not in meaning_levels[option]:
                errors.append(f"Cross-JLPT distractor: {char} -> {option!r}")
            overlap = meaning_terms(option) & meaning_terms(answer)
            if overlap:
                errors.append(f"Ambiguous distractor: {char} shares {sorted(overlap)} with {option!r}")

    # The reviewed correction overlay must be exactly reflected in the asset.
    for char, patch in corrections.items():
        row = by_char.get(char)
        if row is None:
            errors.append(f"Correction target missing from kanji.json: {char}")
            continue
        for field, expected in patch.items():
            if row.get(field) != expected:
                errors.append(f"Correction not applied: {char}.{field}")

    # Known multilingual/OCR glossary fragments that triggered this cleanup.
    banned_gloss_chunks = {
        "monter", "billete", "nom de famille", "apellido",
        "bureau du gouvernement", "oficina del gobierno",
        "aire de 2 tatamis standards", "respect des anciens", "voile",
        "vela de barco", "almohada", "prefacio a una frase o charla",
        "alero de tejado", "ceja", "forma de la cabeza", "globe oculaire",
        "ojo", "plant de riz", "planta de arroz", "compteur de choses",
        "contador y enumerador para cosas", "signature (d'un artisan)",
        "pastel de pasta de arroz", "espion", "espiar", "inquirir", "clair",
        "paresse", "applaudir", "canon", "filet", "membre", "soie", "seda",
        "soi",
    }
    for row in kanji:
        chunks = meaning_terms(row["meaning"])
        bad = chunks & banned_gloss_chunks
        if bad:
            errors.append(f"Known non-English gloss remains for {row['kanji']}: {sorted(bad)}")

    seven = by_char.get("七")
    seven_q = next((q for q in questions if q["kanji"] == "七"), None)
    if seven is None or seven_q is None:
        errors.append("七 missing from kanji/question data")
    elif any(
        "seven" in meaning_terms(option)
        for option in seven_q["options"]
        if option != seven_q["answer"]
    ):
        errors.append("七 still has a wrong option containing the answer term 'seven'")

    # Source-level guards for the behavior changes that Python cannot execute.
    source_guards = {
        "lib/screens/kanji_mode_screen.dart": [
            "JlptLevel? _level = JlptLevel.n5",
            "..._options.map(",
        ],
        "lib/screens/sentence_mode_screen.dart": [
            "JlptLevel? _level = JlptLevel.n5",
            "..._options.map(",
        ],
        "lib/screens/test_setup_screen.dart": [
            "JlptLevel? _level = JlptLevel.n5",
        ],
        "lib/screens/test_run_screen.dart": [
            "shuffledCopy<String>(s.options)",
            "shuffledCopy<String>(k.options)",
        ],
        "lib/screens/flashcard_screen.dart": ["rateIfStudied"],
        "lib/models/item_progress.dart": [
            "DateTime(at.year, at.month, at.day + intervalDays)",
        ],
        "lib/services/progress_service.dart": [
            "_freshIdsInLearningOrder",
            "k.jlptLevel?.index ?? 99",
        ],
        "lib/screens/home_screen.dart": [
            "meanings & readings · JLPT N5 → N1",
            "Custom quiz · choose content and length",
        ],
    }
    for relative, needles in source_guards.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            if needle not in text:
                errors.append(f"Missing source guard in {relative}: {needle}")

    print(f"Sentences: {len(sentences)} {dict(Counter(r['jlpt_level'] for r in sentences))}")
    print(f"Kanji: {len(kanji)} {dict(Counter(r.get('jlpt_level') for r in kanji))}")
    print(f"Kanji questions: {len(questions)}")
    print(f"Reviewed kanji correction overlay: {len(corrections)} entries")
    print(f"Cross-JLPT exact sentence duplicates: {len(cross_level)}")
    print(f"Errors: {len(errors)}")
    for error in errors:
        print(f"ERROR: {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

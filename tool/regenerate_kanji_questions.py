#!/usr/bin/env python3
"""Regenerate assets/data/kanji_questions.json from assets/data/kanji.json.

This is the repeatable half of the kanji dataset pipeline (see
merge_kanji_dataset.py for the one-time old+new merge). Re-run this any time
kanji.json changes, so kanji_questions.json stays in sync with it.

difficulty is derived from jlpt_level (N5/N4 -> easy, N3 -> normal,
N2/N1 -> hard). For entries with no jlpt_level, this falls back to whatever
the *previous* kanji_questions.json had for that same kanji (so re-running
this script doesn't silently reshuffle difficulty for kanji the JLPT dataset
has no opinion on); a brand-new kanji with neither a level nor a prior
entry defaults to 'normal'.

options/answer: answer = meaning; distractors are chosen from other kanji
at the SAME JLPT level whenever possible, then fall back to neighbouring
levels only if a level is too small. This keeps N5 questions N5-calibrated
instead of asking beginners to distinguish an N5 answer from random N1
glosses. Distractors whose comma-separated meaning terms overlap the correct
answer are rejected (e.g. a wrong option containing the word "seven" for 七).
Options are still shuffled deterministically in the asset; learner-facing
screens additionally shuffle at runtime so button position cannot be memorized.

Usage:
    python3 tool/regenerate_kanji_questions.py
"""

from __future__ import annotations

import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KANJI_JSON = ROOT / "assets" / "data" / "kanji.json"
KANJI_QUESTIONS_JSON = ROOT / "assets" / "data" / "kanji_questions.json"

# Fixed seed: deterministic output across re-runs (only actually changes
# when the underlying kanji.json changes), so diffs stay reviewable instead
# of churning every distractor on every regeneration.
RANDOM_SEED = 20260926

LEVEL_TO_DIFFICULTY = {
    "N5": "easy",
    "N4": "easy",
    "N3": "normal",
    "N2": "hard",
    "N1": "hard",
}
LEVEL_ORDER = ["N5", "N4", "N3", "N2", "N1"]


def meaning_terms(text: str) -> set[str]:
    """Comparable gloss chunks used to reject semantically ambiguous options."""
    return {part.strip().casefold() for part in text.replace(";", ",").split(",") if part.strip()}


def level_fallback_order(level: str | None) -> list[str | None]:
    if level not in LEVEL_ORDER:
        return [None, *LEVEL_ORDER]
    index = LEVEL_ORDER.index(level)
    others = sorted(
        (candidate for candidate in LEVEL_ORDER if candidate != level),
        key=lambda candidate: (abs(LEVEL_ORDER.index(candidate) - index), LEVEL_ORDER.index(candidate)),
    )
    return [level, *others, None]


def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def main() -> None:
    kanji_entries = load_json(KANJI_JSON)

    # Old kanji_questions.json is only consulted for its difficulty field,
    # as a fallback for jlpt_level=null entries -- read it BEFORE
    # overwriting the file below.
    old_difficulty_by_char: dict[str, str] = {}
    if KANJI_QUESTIONS_JSON.exists():
        for e in load_json(KANJI_QUESTIONS_JSON):
            old_difficulty_by_char[e["kanji"]] = e["difficulty"]

    rng = random.Random(RANDOM_SEED)

    # Pools by JLPT level. Keeping them separate is what prevents a new N5
    # learner from getting three arbitrary N1 meanings as distractors.
    meaning_pool_by_level: dict[str | None, list[tuple[str, str]]] = {}
    for entry in kanji_entries:
        if not entry["meaning"]:
            continue
        meaning_pool_by_level.setdefault(entry.get("jlpt_level"), []).append(
            (entry["kanji"], entry["meaning"])
        )

    questions = []
    difficulty_counts: dict[str, int] = {"easy": 0, "normal": 0, "hard": 0}

    for e in kanji_entries:
        char = e["kanji"]
        level = e.get("jlpt_level")
        if level in LEVEL_TO_DIFFICULTY:
            difficulty = LEVEL_TO_DIFFICULTY[level]
        elif char in old_difficulty_by_char:
            difficulty = old_difficulty_by_char[char]
        else:
            difficulty = "normal"
        difficulty_counts[difficulty] += 1

        answer = e["meaning"]
        answer_terms = meaning_terms(answer)
        distractors: list[str] = []
        seen = {answer}

        # Exhaust the same-level pool first. In practice every shipped JLPT
        # tier has far more than three distinct meanings, but the fallback
        # order keeps this script robust if the dataset changes later.
        for candidate_level in level_fallback_order(level):
            candidates = list(meaning_pool_by_level.get(candidate_level, []))
            rng.shuffle(candidates)
            for candidate_char, meaning in candidates:
                if candidate_char == char or meaning in seen:
                    continue
                if answer_terms & meaning_terms(meaning):
                    continue
                seen.add(meaning)
                distractors.append(meaning)
                if len(distractors) == 3:
                    break
            if len(distractors) == 3:
                break
        options = [answer, *distractors]
        rng.shuffle(options)

        questions.append({
            "kanji": char,
            "meaning": e["meaning"],
            "onyomi": e["onyomi"],
            "kunyomi": e["kunyomi"],
            "breakdown": e["breakdown"],
            "common_words": e["common_words"],
            "is_radical": e["is_radical"],
            "difficulty": difficulty,
            "options": options,
            "answer": answer,
            "jlpt_level": level,
        })

    with KANJI_QUESTIONS_JSON.open("w", encoding="utf-8") as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Regenerated {len(questions)} kanji_questions.json entries")
    print(f"Difficulty distribution: {difficulty_counts}")
    short_option_entries = [q["kanji"] for q in questions if len(q["options"]) < 4]
    if short_option_entries:
        print(f"WARNING: {len(short_option_entries)} entries have <4 options "
              f"(meaning pool too small / too many duplicate meanings): "
              f"{short_option_entries[:20]}")
    else:
        print("Every entry has exactly 4 options.")


if __name__ == "__main__":
    main()

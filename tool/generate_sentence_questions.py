#!/usr/bin/env python3
"""Generate assets/data/sentences.json from the JLPT sentence source.

Inputs (both live in tool/sources/):
  sentence_batches_combined.json   2,022 entries: family_id, jp, reading, form,
                                   tone, jlpt_level, explanation, tags
  sentence_translations.json       {"family_id|form": "English text"}

Output:
  assets/data/sentences.json       one entry per source entry, in source order,
                                   carrying everything the Sentence model
                                   reads plus the quiz fields (en / options /
                                   answer / difficulty).

Design decisions -- each of these is deliberate:

* Translations are looked up by (family_id, form) and tone is ignored: a
  casual sentence and its formal twin mean the same thing, so they share
  one English string. Any (family_id, form) with no translation aborts the
  run with a non-zero exit and a full list of what's missing -- there is no
  fallback text and no partial output.

* Options are generated ONCE per (family_id, form) and reused for both the
  casual and formal entry. The Learn Sentences card toggles between the two
  in place, so the English, the options and the score state must not change
  when it does. The RNG is seeded from (seed, family_id, form) rather than
  drawn from one shared stream, so an entry's options don't depend on
  iteration order or on how many other entries exist.

* Distractors come from OTHER families only. Sibling forms within a family
  translate too similarly ("teaches" / "taught" / "can teach") to make good
  wrong answers. Candidates are deduplicated by English text (1,127
  translations, all currently unique), and any English string used anywhere
  in the answer's own family is excluded too, so a distractor can never
  coincide with the answer or with one of its sibling forms.

* Distractors are drawn from the SAME grammatical form as the answer first
  (e.g. a passive answer gets passive distractors). With fully random
  distractors, many questions are solvable from the English pattern alone
  ("is loved by", "made to", "There is no", "If ...") without reading the
  Japanese. Forms with fewer than 3 candidate distractors in other families
  fill the remainder from any form; see the fallback count printed on every
  run.

* difficulty is derived from jlpt_level with the same mapping the kanji
  pipeline uses (N5/N4 -> easy, N3 -> normal, N2/N1 -> hard). That keeps
  Test mode's easy/normal/hard picker working with no changes.

Usage:
    python3 tool/generate_sentence_questions.py --sample     # preview, writes nothing
    python3 tool/generate_sentence_questions.py              # writes assets/data/sentences.json
"""

from __future__ import annotations

import argparse
import json
import random
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "tool" / "sources"
SENTENCES_SRC = SOURCES / "sentence_batches_combined.json"
TRANSLATIONS_SRC = SOURCES / "sentence_translations.json"
DEFAULT_OUT = ROOT / "assets" / "data" / "sentences.json"

RANDOM_SEED = 20260928
DISTRACTOR_COUNT = 3

LEVEL_TO_DIFFICULTY = {
    "N5": "easy",
    "N4": "easy",
    "N3": "normal",
    "N2": "hard",
    "N1": "hard",
}

# Mirrors the SentenceForm enum in lib/models/sentence.dart. A form missing
# from this set would parse to null in the app, so fail here instead.
KNOWN_FORMS = {
    "present_affirmative", "present_negative", "past_affirmative",
    "past_negative", "te_form", "potential", "volitional", "passive",
    "causative", "causative_passive", "conditional_tara",
}

REQUIRED_SOURCE_KEYS = (
    "family_id", "jp", "reading", "form", "tone",
    "jlpt_level", "explanation", "tags",
)

# Shown by --sample: a spread across levels and grammatical forms. The first
# key deliberately has both a casual and a formal entry.
DEFAULT_SAMPLE_KEYS = [
    "n5_001|present_affirmative",
    "n5_001|te_form",
    "n5_028|past_negative",
    "n4_031|present_negative",
    "n3_001|passive",
    "n2_001|causative_passive",
    "n1_015|conditional_tara",
]

Key = tuple[str, str]  # (family_id, form)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------

def validate_source(source: list[dict]) -> None:
    """Structural checks on the source file. Aborts with every problem found."""
    problems: list[str] = []
    seen_triples: set[tuple[str, str, str]] = set()
    levels_by_family: dict[str, set[str]] = defaultdict(set)
    tones_by_key: dict[Key, set[str]] = defaultdict(set)

    for i, e in enumerate(source):
        missing = [k for k in REQUIRED_SOURCE_KEYS if k not in e]
        if missing:
            problems.append(f"entry {i}: missing keys {missing}")
            continue
        if e["jlpt_level"] not in LEVEL_TO_DIFFICULTY:
            problems.append(f"entry {i}: unknown jlpt_level {e['jlpt_level']!r}")
        if e["form"] not in KNOWN_FORMS:
            problems.append(f"entry {i}: unknown form {e['form']!r}")
        triple = (e["family_id"], e["form"], e["tone"])
        if triple in seen_triples:
            problems.append(f"duplicate (family_id, form, tone): {triple}")
        seen_triples.add(triple)
        levels_by_family[e["family_id"]].add(e["jlpt_level"])
        tones_by_key[(e["family_id"], e["form"])].add(e["tone"])

    for fid, levels in levels_by_family.items():
        if len(levels) > 1:
            problems.append(f"family {fid} spans more than one JLPT level: {sorted(levels)}")

    # The UI hides the casual/formal toggle exactly when a form has no pair,
    # so every (family, form) must be either a casual+formal pair or a lone
    # neutral entry -- never anything in between.
    for key, tones in tones_by_key.items():
        if tones not in ({"casual", "formal"}, {"neutral"}):
            problems.append(f"{key[0]}|{key[1]}: unexpected tone set {sorted(tones)}")

    if problems:
        fail("source validation failed:\n  " + "\n  ".join(problems[:50])
             + (f"\n  ... and {len(problems) - 50} more" if len(problems) > 50 else ""))


def load_translations(source: list[dict], raw: dict[str, str]) -> dict[Key, str]:
    """Return {(family_id, form): english}. Aborts if any key is missing."""
    needed = sorted({(e["family_id"], e["form"]) for e in source})
    missing = [f"{fid}|{form}" for fid, form in needed if f"{fid}|{form}" not in raw]
    blank = sorted(k for k, v in raw.items() if not isinstance(v, str) or not v.strip())

    if missing or blank:
        lines = []
        if missing:
            lines.append(f"{len(missing)} (family_id|form) key(s) have no translation:")
            lines += [f"    {k}" for k in missing[:40]]
            if len(missing) > 40:
                lines.append(f"    ... and {len(missing) - 40} more")
        if blank:
            lines.append(f"{len(blank)} translation(s) are blank: {blank[:20]}")
        fail("\n  ".join(["translations are incomplete --"] + lines))

    used = {f"{fid}|{form}" for fid, form in needed}
    unused = sorted(set(raw) - used)
    if unused:
        print(f"warning: {len(unused)} translation key(s) match no source entry "
              f"(ignored): {unused[:10]}", file=sys.stderr)

    return {(fid, form): raw[f"{fid}|{form}"] for fid, form in needed}


# --------------------------------------------------------------------------
# Option generation
# --------------------------------------------------------------------------

def distractor_pool(
    key: Key,
    english_by_key: dict[Key, str],
    english_by_family: dict[str, set[str]],
) -> tuple[list[str], list[str]]:
    """Candidate distractors as (same_form, other_forms), each sorted, unique.

    Other families only; and any English string that appears anywhere in the
    answer's own family is excluded. Sorted so that rng.sample() is
    reproducible regardless of dict ordering.
    """
    family_id, form = key
    own = english_by_family[family_id]
    everything = {
        en for (fid, _), en in english_by_key.items() if fid != family_id
    } - own
    same_form = {
        en for (fid, f), en in english_by_key.items()
        if fid != family_id and f == form
    } - own
    return sorted(same_form), sorted(everything - same_form)


def make_options(
    key: Key,
    english_by_key: dict[Key, str],
    english_by_family: dict[str, set[str]],
) -> list[str]:
    answer = english_by_key[key]
    preferred, rest = distractor_pool(key, english_by_key, english_by_family)
    if len(preferred) + len(rest) < DISTRACTOR_COUNT:
        fail(f"{key[0]}|{key[1]}: only {len(preferred) + len(rest)} distractor "
             f"candidates available, need {DISTRACTOR_COUNT}")

    rng = random.Random(f"{RANDOM_SEED}|{key[0]}|{key[1]}")
    picks = rng.sample(preferred, min(DISTRACTOR_COUNT, len(preferred)))
    if len(picks) < DISTRACTOR_COUNT:
        picks += rng.sample(rest, DISTRACTOR_COUNT - len(picks))

    options = [answer, *picks]
    rng.shuffle(options)
    return options


# --------------------------------------------------------------------------
# Entry building + output checks
# --------------------------------------------------------------------------

def build_entry(src: dict, english: str, options: list[str]) -> dict:
    return {
        "jp": src["jp"],
        "reading": src["reading"],
        "en": english,
        "difficulty": LEVEL_TO_DIFFICULTY[src["jlpt_level"]],
        "jlpt_level": src["jlpt_level"],
        "family_id": src["family_id"],
        "form": src["form"],
        "tone": src["tone"],
        "explanation": src["explanation"],
        "tags": src["tags"],
        "options": options,
        "answer": english,
    }


def check_entry(entry: dict, english_by_family: dict[str, set[str]]) -> list[str]:
    """Problems with one generated entry, mirroring what Sentence.fromJson needs."""
    problems = []
    opts = entry["options"]
    if len(opts) != 1 + DISTRACTOR_COUNT or len(set(opts)) != len(opts):
        problems.append("options are not 4 unique strings")
    if entry["answer"] not in opts:
        problems.append("answer not in options")
    if entry["en"] != entry["answer"]:
        problems.append("en != answer")
    leaked = [o for o in opts if o != entry["answer"] and o in english_by_family[entry["family_id"]]]
    if leaked:
        problems.append(f"distractor(s) from the answer's own family: {leaked}")
    for field in ("jp", "reading", "en", "explanation"):
        if not entry[field].strip():
            problems.append(f"blank {field}")
    return problems


# --------------------------------------------------------------------------
# Sample preview
# --------------------------------------------------------------------------

def fallback_keys(english_by_key, english_by_family) -> list[Key]:
    """Questions whose form has < 3 same-form candidates in other families."""
    out = []
    for key in english_by_key:
        preferred, _ = distractor_pool(key, english_by_key, english_by_family)
        if len(preferred) < DISTRACTOR_COUNT:
            out.append(key)
    return out


def print_source_summary(source, english_by_key, english_by_family):
    by_level = Counter(e["jlpt_level"] for e in source)
    by_diff = Counter(LEVEL_TO_DIFFICULTY[e["jlpt_level"]] for e in source)
    print(f"source entries: {len(source)}  |  families: {len(english_by_family)}  "
          f"|  unique (family, form) questions: {len(english_by_key)}")
    print(f"by level: {dict(sorted(by_level.items()))}")
    print(f"by difficulty: {dict(by_diff)}")
    sizes = []
    for key in english_by_key:
        preferred, rest = distractor_pool(key, english_by_key, english_by_family)
        sizes.append(len(preferred) + len(rest))
    print(f"distractor candidates per question: min {min(sizes)}, "
          f"median {int(statistics.median(sizes))}, max {max(sizes)}")
    fb = fallback_keys(english_by_key, english_by_family)
    fb_forms = Counter(form for _, form in fb)
    print(f"questions that must fall back to other-form distractors: {len(fb)} "
          f"{dict(fb_forms) if fb else ''}")


def print_sample(key: Key, source, english_by_key, english_by_family):
    fid, form = key
    entries = [e for e in source if e["family_id"] == fid and e["form"] == form]
    if not entries:
        fail(f"sample key {fid}|{form} matches no source entry")
    options = make_options(key, english_by_key, english_by_family)
    english = english_by_key[key]
    first = build_entry(entries[0], english, options)

    problems = check_entry(first, english_by_family)
    print(f"\n{fid} | {form}   [{first['jlpt_level']} -> {first['difficulty']}]"
          + ("   !! " + "; ".join(problems) if problems else ""))
    for e in entries:
        print(f"  {e['tone']:<7} {e['jp']}   ({e['reading']})")
    print(f"  EN      {english}")
    print(f"  explain {first['explanation']}")
    print("  options (identical for every tone of this form):")
    for o in options:
        print(f"    {'->' if o == english else '  '} {o}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--sample", nargs="*", metavar="FAMILY|FORM",
                        help="print sample entries (default set if none given) "
                             "and write nothing")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    source = load_json(SENTENCES_SRC)
    validate_source(source)
    english_by_key = load_translations(source, load_json(TRANSLATIONS_SRC))

    english_by_family: dict[str, set[str]] = defaultdict(set)
    for (fid, _), en in english_by_key.items():
        english_by_family[fid].add(en)

    if args.sample is not None:
        print_source_summary(source, english_by_key, english_by_family)
        keys = args.sample or DEFAULT_SAMPLE_KEYS
        for k in keys:
            fid, _, form = k.partition("|")
            print_sample((fid, form), source, english_by_key, english_by_family)
        print("\n(sample mode: nothing was written)")
        return

    # Full run: options once per (family, form), shared by both tones.
    options_by_key: dict[Key, list[str]] = {}
    entries = []
    for src in source:
        key = (src["family_id"], src["form"])
        if key not in options_by_key:
            options_by_key[key] = make_options(key, english_by_key, english_by_family)
        entries.append(build_entry(src, english_by_key[key], options_by_key[key]))

    problems = []
    for e in entries:
        for p in check_entry(e, english_by_family):
            problems.append(f"{e['family_id']}|{e['form']}|{e['tone']}: {p}")
    if problems:
        fail("generated output failed validation:\n  " + "\n  ".join(problems[:50]))

    with args.out.open("w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print_source_summary(source, english_by_key, english_by_family)
    print(f"wrote {len(entries)} entries to {args.out}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""One-time merge: fold the JLPT-graded kanji_dataset_final.json (N5-N1)
into the app's existing assets/data/kanji.json.

Implements the three-way merge described in kanji_integration_prompt.md:
  - kanji only in the OLD file            -> kept byte-for-byte, jlpt_level
                                              added if a match exists anywhere
                                              in the new dataset.
  - kanji only in the NEW dataset         -> fresh entry built from the
                                              field-mapping rules below.
  - kanji in BOTH                         -> onyomi/kunyomi/jlpt_level are
                                              upgraded from the new dataset;
                                              meaning, common_words, breakdown
                                              and is_radical are left exactly
                                              as they already were.

Character identity (the `kanji` string) is never changed, removed, or
reordered for any pre-existing entry -- that string is ProgressService's SRS
key (`'kanji:$kanji'`), so preserving it exactly is what keeps every user's
review history valid. Existing entries keep their original list position;
new entries are appended after them.

Usage:
    python3 tool/merge_kanji_dataset.py

Reads:
    assets/data/kanji.json                      (existing/previous merged asset)
    <new dataset path below>                    (source of truth for JLPT)
    assets/data/radicals.json                   (read-only, for is_radical)
    tool/kanji_content_corrections.json         (reviewed learner-facing fixes)
Writes:
    assets/data/kanji.json                       (overwritten, merged)
    tool/merge_kanji_dataset.log.json            (per-kanji change log)
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KANJI_JSON = ROOT / "assets" / "data" / "kanji.json"
RADICALS_JSON = ROOT / "assets" / "data" / "radicals.json"
# The new dataset, checked into the repo alongside this script so the merge
# is fully reproducible later (e.g. once the N2/N1 "topped up later" pass
# mentioned in the integration notes lands, re-running this script just
# means dropping the updated file in here and running it again).
NEW_DATASET = ROOT / "tool" / "sources" / "kanji_dataset_final.json"
LOG_PATH = ROOT / "tool" / "merge_kanji_dataset.log.json"
CORRECTIONS_JSON = ROOT / "tool" / "kanji_content_corrections.json"

JLPT_LEVELS = ["N5", "N4", "N3", "N2", "N1"]


# --------------------------------------------------------------------------
# Field-mapping helpers (kanji_integration_prompt.md, step 1)
# --------------------------------------------------------------------------

def convert_reading(kana: str, is_kunyomi: bool) -> str:
    """KANJIDIC2 '.' okurigana marker -> the app's '(...)' convention;
    strip KANJIDIC2's leading/trailing '-' bound-form marker."""
    if is_kunyomi and "." in kana:
        base, okuri = kana.split(".", 1)
        kana = f"{base}({okuri})"
    return kana.strip("-")


def convert_kana_list(entries: list[dict], is_kunyomi: bool) -> list[str]:
    """[{'kana': ..., 'romaji': ...}, ...] -> deduped list[str], converted.

    Stripping the hyphen and then deduping by the stripped value is
    equivalent to "drop the hyphenated variant if a clean version is also
    present, otherwise just strip the hyphen" -- if both 'x' and 'x-' occur,
    stripping both yields two copies of 'x', which the seen-set collapses to
    one; if only 'x-' occurs, stripping it just yields the clean 'x'.
    """
    seen: set[str] = set()
    out: list[str] = []
    for e in entries:
        conv = convert_reading(e["kana"], is_kunyomi)
        if conv and conv not in seen:
            seen.add(conv)
            out.append(conv)
    return out


# meaning_en is KANJIDIC2-sourced but -- contrary to what its name and the
# integration prompt's schema example suggest -- is NOT English-only. It
# interleaves English glosses with French/Spanish/Portuguese ones with no
# per-item language tag (verified empirically against the actual delivered
# file: e.g. 上 -> ['above', 'up', 'au-dessus', 'haut', 'monter', ...]).
# A blind `meaning_en[:3]` (the literal instruction in the prompt) would
# regularly leak non-English words into the meaning field for net-new kanji.
# This filters obvious non-English glosses (accented Latin characters, or a
# gloss made entirely of common French/Spanish/Portuguese function words)
# across the WHOLE list before taking the first 3, rather than filtering
# only the naive first three -- see merge_kanji_dataset.md notes in the
# final report for exactly how much this caught vs. missed.
_ACCENT_RE = re.compile(r"[àâäéèêëîïôöùûüçñãõáíóúÁÉÍÓÚÑÃÕ]")
_NON_ENGLISH_STOPWORDS = {
    "de", "le", "la", "les", "un", "une", "et", "en", "du", "des", "au",
    "aux", "ou", "el", "los", "las", "y", "o", "por", "para", "com", "sem",
    "que", "se", "je", "te", "no", "na", "do", "da", "ao", "muy", "tres",
    "il", "lo", "del", "al",
}


def _looks_non_english(gloss: str) -> bool:
    g = gloss.strip().lower()
    if _ACCENT_RE.search(g):
        return True
    words = re.findall(r"[a-zà-ÿ']+", g)
    return bool(words) and all(w in _NON_ENGLISH_STOPWORDS for w in words)


def convert_meaning(meaning_en: list[str]) -> str:
    if not meaning_en:
        return ""
    candidates = [g for g in meaning_en if not _looks_non_english(g)]
    if not candidates:
        candidates = meaning_en  # never end up empty if the source had content
    return ", ".join(candidates[:3])


def convert_common_words(examples: list[dict], kanji_char: str) -> list[dict]:
    out: list[dict] = []
    for ex in examples:
        word = (ex.get("word") or "").strip()
        english = (ex.get("english") or "").strip()
        if not word or not english or word == kanji_char:
            continue
        reading_derived = (ex.get("reading_derived") or "").strip()
        romaji = (ex.get("romaji") or "").strip()
        if reading_derived and romaji:
            reading = f"{reading_derived} ({romaji})"
        else:
            reading = reading_derived or romaji
        out.append({"word": word, "meaning": english, "reading": reading})
        if len(out) >= 5:
            break
    return out


# --------------------------------------------------------------------------
# Load inputs
# --------------------------------------------------------------------------

def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def main() -> None:
    old_entries = load_json(KANJI_JSON)
    radicals = load_json(RADICALS_JSON)
    new_grouped = load_json(NEW_DATASET)

    radical_chars = {r["char"] for r in radicals}

    # Flatten the new dataset into char -> (level, raw_entry). Verified
    # separately that there are zero duplicate kanji within or across the
    # five level buckets, so a plain dict build is safe (would silently
    # drop a dup by last-write-wins otherwise -- there are none).
    new_by_char: dict[str, tuple[str, dict]] = {}
    for level in JLPT_LEVELS:
        for e in new_grouped.get(level, []):
            new_by_char[e["kanji"]] = (level, e)

    old_by_char: dict[str, dict] = {e["kanji"]: e for e in old_entries}
    old_chars_in_order = [e["kanji"] for e in old_entries]

    assert len(old_by_char) == len(old_entries), (
        "old kanji.json has duplicate kanji values -- aborting, this "
        "should never happen and would corrupt identity."
    )

    merged: list[dict] = []
    change_log: dict[str, dict] = {}

    # --- Pass 1: every existing entry, in its original order -------------
    for char in old_chars_in_order:
        old_entry = old_by_char[char]
        level, new_entry = new_by_char.get(char, (None, None))

        if new_entry is None:
            # Old-only: untouched, byte-for-byte, just add jlpt_level (null
            # if this kanji genuinely isn't in the new dataset under any
            # level).
            out = dict(old_entry)
            out["jlpt_level"] = None
            merged.append(out)
            continue

        # Merge case: upgrade onyomi/kunyomi + add jlpt_level; everything
        # else (meaning, common_words, breakdown, is_radical) stays exactly
        # as it was.
        new_onyomi = convert_kana_list(new_entry.get("onyomi", []), False)
        new_kunyomi = convert_kana_list(new_entry.get("kunyomi", []), True)

        out = dict(old_entry)
        out["onyomi"] = new_onyomi
        out["kunyomi"] = new_kunyomi
        out["jlpt_level"] = level
        merged.append(out)

        if new_onyomi != old_entry.get("onyomi") or new_kunyomi != old_entry.get("kunyomi"):
            change_log[char] = {
                "jlpt_level": level,
                "old_onyomi": old_entry.get("onyomi"),
                "new_onyomi": new_onyomi,
                "old_kunyomi": old_entry.get("kunyomi"),
                "new_kunyomi": new_kunyomi,
            }

    # --- Pass 2: net-new kanji, appended after all existing entries ------
    # Iterate in level order (N5 -> N1) then source-file order within a
    # level, for a stable, human-browsable append order. This is purely
    # additive -- it never touches an existing entry's position.
    new_only_count = 0
    for level in JLPT_LEVELS:
        for e in new_grouped.get(level, []):
            char = e["kanji"]
            if char in old_by_char:
                continue  # handled in pass 1
            onyomi = convert_kana_list(e.get("onyomi", []), False)
            kunyomi = convert_kana_list(e.get("kunyomi", []), True)
            meaning = convert_meaning(e.get("meaning_en") or [])
            common_words = convert_common_words(e.get("examples") or [], char)
            out = {
                "kanji": char,
                "onyomi": onyomi,
                "kunyomi": kunyomi,
                "meaning": meaning,
                "breakdown": None,
                "is_radical": char in radical_chars,
                "common_words": common_words,
                "jlpt_level": level,
            }
            merged.append(out)
            new_only_count += 1

    # --- Reviewed learner-facing correction overlay ----------------------
    # The source dataset intentionally remains untouched as provenance. A
    # small checked-in overlay removes only manually verified OCR fragments
    # / multilingual gloss leakage so re-running this merge cannot bring
    # those bad readings back into the app.
    if CORRECTIONS_JSON.exists():
        corrections = load_json(CORRECTIONS_JSON)
        merged_by_char = {e["kanji"]: e for e in merged}
        missing = sorted(set(corrections) - set(merged_by_char))
        assert not missing, f"Correction characters missing after merge: {missing}"
        for char, patch in corrections.items():
            merged_by_char[char].update(patch)

    # --- Write outputs -----------------------------------------------------
    with KANJI_JSON.open("w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
        f.write("\n")

    with LOG_PATH.open("w", encoding="utf-8") as f:
        json.dump(change_log, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Old entries preserved: {len(old_entries)}")
    print(f"  of which onyomi/kunyomi upgraded (matched in new dataset): {len(change_log)}")
    print(f"  of which no match in new dataset (jlpt_level=null): "
          f"{sum(1 for c in old_chars_in_order if c not in new_by_char)}")
    print(f"Net-new entries added: {new_only_count}")
    print(f"Total merged entries: {len(merged)}")
    print(f"Change log written to: {LOG_PATH}")


if __name__ == "__main__":
    main()

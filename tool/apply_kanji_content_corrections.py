#!/usr/bin/env python3
"""Apply the reviewed kanji reading/meaning correction overlay.

The merged dataset keeps its original OCR/KANJIDIC provenance untouched under
`tool/sources/`. This small overlay records only corrections that were manually
verified as corrupt or multilingual contamination, so future data regeneration
can reproduce the learner-facing asset without hand-editing JSON.
"""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "assets" / "data" / "kanji.json"
CORRECTIONS = ROOT / "tool" / "kanji_content_corrections.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def apply(entries: list[dict], corrections: dict[str, dict]) -> int:
    by_char = {e["kanji"]: e for e in entries}
    missing = sorted(set(corrections) - set(by_char))
    if missing:
        raise SystemExit(f"Correction characters missing from kanji.json: {missing}")
    changed = 0
    for char, patch in corrections.items():
        entry = by_char[char]
        for key, value in patch.items():
            if entry.get(key) != value:
                entry[key] = value
                changed += 1
    return changed


def main() -> None:
    entries = load(ASSET)
    corrections = load(CORRECTIONS)
    changed = apply(entries, corrections)
    ASSET.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Applied {changed} field correction(s) across {len(corrections)} kanji entries.")


if __name__ == "__main__":
    main()

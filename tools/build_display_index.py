#!/usr/bin/env python3
"""Generate app/assets/quran/quran_display.json.

The reader needs verse text plus each verse's place in the Mushaf. Both facts
already exist — in quran.json and quran_index.json — but reading them at run
time means parsing 3.6 MB of JSON in which every verse repeats its surah names
and its field names, which is most of the bytes and all of the delay.

This packs the same information into one file of positional rows with the surah
names stored once. Nothing is invented: every value is copied from the two
source files, and the row count is checked against both.

Run after tools/build_quran_index.py, and re-run whenever either source
changes.

Usage:
    python tools/build_display_index.py
"""

from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSETS = REPO_ROOT / "app" / "assets" / "quran"
CORPUS = ASSETS / "quran.json"
INDEX = ASSETS / "quran_index.json"
OUTPUT = ASSETS / "quran_display.json"

EXPECTED_AYAH_COUNT = 6236
EXPECTED_SURAH_COUNT = 114

# A byte-order mark rode into the first verse of quran.json when that file was
# written. It is a formatting code point, not part of the text, it is absent
# from the Mushaf typeface, and the recogniser's normalizer already drops it —
# so the reader should not be the one place that carries it.
ZERO_WIDTH_NO_BREAK_SPACE = "﻿"


def clean(text: str) -> str:
    """Copies the verse text through, minus the stray mark described above."""
    return text.replace(ZERO_WIDTH_NO_BREAK_SPACE, "")


def main() -> None:
    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    index = json.loads(INDEX.read_text(encoding="utf-8"))

    if len(corpus) != EXPECTED_AYAH_COUNT:
        raise SystemExit(f"Expected {EXPECTED_AYAH_COUNT} verses, found {len(corpus)}")

    positions = {
        (row["surah"], row["ayah"]): row for row in index["ayahs"]
    }
    if len(positions) != EXPECTED_AYAH_COUNT:
        raise SystemExit(f"Position index has {len(positions)} rows")

    surahs: dict[int, dict] = {}
    verses: list[list] = []

    for verse in corpus:
        surah = int(verse["surah"])
        ayah = int(verse["ayah"])

        position = positions.get((surah, ayah))
        if position is None:
            raise SystemExit(f"No position for {surah}:{ayah}")

        entry = surahs.setdefault(
            surah,
            {
                "n": surah,
                "ar": verse["surah_name"],
                "en": verse["surah_name_en"],
                "c": 0,
                "p": position["page"],
            },
        )
        entry["c"] += 1
        if ayah == 1:
            entry["p"] = position["page"]

        # Positional rows: surah, ayah, page, juz, hizb, uthmani, clean.
        verses.append(
            [
                surah,
                ayah,
                position["page"],
                position["juz"],
                position["hizbQuarter"],
                clean(verse["text_uthmani"]),
                clean(verse.get("text_clean", "")),
            ]
        )

    if len(surahs) != EXPECTED_SURAH_COUNT:
        raise SystemExit(f"Expected {EXPECTED_SURAH_COUNT} surahs, found {len(surahs)}")

    document = {
        "schema": "tilawa/quran-display@1",
        "generatedFrom": [CORPUS.name, INDEX.name],
        "ayahCount": len(verses),
        "surahs": [surahs[n] for n in sorted(surahs)],
        "verses": verses,
    }

    OUTPUT.write_text(
        json.dumps(document, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    before = CORPUS.stat().st_size + INDEX.stat().st_size
    after = OUTPUT.stat().st_size
    print(
        f"Wrote {OUTPUT} ({len(verses)} verses, {after / 1024:.0f} KB; "
        f"replaces {before / 1024:.0f} KB of reader input)"
    )


if __name__ == "__main__":
    main()

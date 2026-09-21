#!/usr/bin/env python3
"""Generate the per-surah memorisation difficulty table.

There is no authoritative dataset of how hard a surah is to memorise. What
there is, is the text itself — and the things huffaz name as the causes are all
measurable in it:

* **Bulk.** A long surah takes longer to lay down and has more to slip.
* **Verse length.** Long verses are harder to hold as single units than short
  ones, which is why Juz Amma is easy out of proportion to its verse count.
* **Mutashabihat.** Near-identical passages recurring with small differences in
  wording or order are the classic cause of a hafiz losing their place. This is
  measurable as the share of a surah's word-5-grams that occur more than once,
  within the surah or elsewhere in the Quran.

Those three are combined into a percentile score and cut into five tiers. On
top of that sit two override layers applied at run time, not here: a small
curated list of surahs whose standing is a matter of practice rather than text
(Al-Fatiha is known by everyone who prays), and the reciter's own stated
habits. See `SurahDifficulty` in the app and the API.

Nothing here is invented: every number is derived from the checked-in corpus,
and the output records how it was derived so it can be audited and reproduced.

Outputs, both checked in, both generated from this one script so the app and
the API cannot drift:

    app/lib/domain/entities/surah_difficulty_table.dart
    backend/Tilawa.Api/Services/SurahDifficultyTable.cs

Usage:
    python tools/build_surah_difficulty.py
"""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CORPUS = REPO_ROOT / "app" / "assets" / "quran" / "quran_display.json"
DART_OUT = REPO_ROOT / "app" / "lib" / "domain" / "entities" / "surah_difficulty_table.dart"
CSHARP_OUT = REPO_ROOT / "backend" / "Tilawa.Api" / "Services" / "SurahDifficultyTable.cs"

EXPECTED_SURAH_COUNT = 114

# Tier coefficients, lowest (holds longest) to highest (fades fastest). These
# divide the half-life, so 1.5 means a surah halves in two thirds of the usual
# time. Mirrored as constants in both generated files.
TIERS = [0.5, 0.75, 1.0, 1.25, 1.5]

# Percentile cuts between the five tiers. Deliberately not even fifths: most of
# the Quran is unremarkable, so the middle tier is the widest and the extreme
# tiers are reserved for surahs that really are outliers.
CUTS = [0.12, 0.35, 0.72, 0.90]

# How much each measured driver contributes to the score.
WEIGHT_BULK = 0.45
WEIGHT_VERSE_LENGTH = 0.25
WEIGHT_MUTASHABIHAT = 0.30

# Length of the repeated word run that counts as a near-identical passage.
NGRAM = 5

# Diacritics, Quranic annotation marks and tatweel. Stripped before comparing
# so that two passages differing only in vowelling count as the repetition a
# reciter actually confuses.
DIACRITICS = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
LETTER_FOLDING = {
    "أ": "ا",  # أ -> ا
    "إ": "ا",  # إ -> ا
    "آ": "ا",  # آ -> ا
    "ٱ": "ا",  # ٱ -> ا
    "ة": "ه",  # ة -> ه
    "ى": "ي",  # ى -> ي
}


def normalise(text: str) -> str:
    """The same folding the recogniser uses, so 'repeated' means what it hears."""
    stripped = DIACRITICS.sub("", text.replace("﻿", ""))
    folded = "".join(LETTER_FOLDING.get(ch, ch) for ch in stripped)
    return " ".join(folded.split())


def ngrams(words: list[str], size: int) -> list[tuple[str, ...]]:
    return [tuple(words[i : i + size]) for i in range(len(words) - size + 1)]


def percentile_ranks(values: dict[int, float]) -> dict[int, float]:
    """Rank each surah in [0, 1] by where it falls among the others.

    Ranked rather than scaled, because the raw measures are wildly skewed —
    Al-Baqarah is 30 times the length of the median surah, and on a linear
    scale it would flatten everything else into a single bucket.
    """
    order = sorted(values, key=lambda key: values[key])
    last = max(len(order) - 1, 1)
    return {key: index / last for index, key in enumerate(order)}


def main() -> None:
    document = json.loads(CORPUS.read_text(encoding="utf-8"))
    verses = document["verses"]

    # Positional rows: surah, ayah, page, juz, hizb, uthmani, clean.
    words_by_surah: dict[int, list[list[str]]] = {}
    for row in verses:
        surah = int(row[0])
        words_by_surah.setdefault(surah, []).append(normalise(row[5]).split())

    if len(words_by_surah) != EXPECTED_SURAH_COUNT:
        raise SystemExit(f"Expected {EXPECTED_SURAH_COUNT} surahs, found {len(words_by_surah)}")

    # A repeated passage is only confusing if it occurs more than once in the
    # whole Quran, so the census is global rather than per surah.
    census: Counter[tuple[str, ...]] = Counter()
    for ayahs in words_by_surah.values():
        for words in ayahs:
            census.update(ngrams(words, NGRAM))

    bulk: dict[int, float] = {}
    verse_length: dict[int, float] = {}
    mutashabihat: dict[int, float] = {}

    for surah, ayahs in words_by_surah.items():
        total_words = sum(len(words) for words in ayahs)
        bulk[surah] = float(total_words)
        verse_length[surah] = total_words / len(ayahs)

        grams = [gram for words in ayahs for gram in ngrams(words, NGRAM)]
        repeated = sum(1 for gram in grams if census[gram] > 1)
        mutashabihat[surah] = repeated / len(grams) if grams else 0.0

    bulk_rank = percentile_ranks(bulk)
    verse_rank = percentile_ranks(verse_length)
    repeat_rank = percentile_ranks(mutashabihat)

    score = {
        surah: WEIGHT_BULK * bulk_rank[surah]
        + WEIGHT_VERSE_LENGTH * verse_rank[surah]
        + WEIGHT_MUTASHABIHAT * repeat_rank[surah]
        for surah in words_by_surah
    }
    final_rank = percentile_ranks(score)

    def tier_of(surah: int) -> int:
        rank = final_rank[surah]
        for index, cut in enumerate(CUTS):
            if rank < cut:
                return index
        return len(CUTS)

    tiers = {surah: tier_of(surah) for surah in sorted(words_by_surah)}

    counts = Counter(tiers.values())
    summary = ", ".join(f"tier {t} ({TIERS[t]}): {counts[t]}" for t in range(len(TIERS)))

    _write_dart(tiers, bulk, verse_length, mutashabihat)
    _write_csharp(tiers)

    print(f"Wrote {DART_OUT.relative_to(REPO_ROOT)}")
    print(f"Wrote {CSHARP_OUT.relative_to(REPO_ROOT)}")
    print(summary)
    hardest = sorted(tiers, key=lambda s: -final_rank[s])[:5]
    easiest = sorted(tiers, key=lambda s: final_rank[s])[:5]
    print(f"fades fastest: {hardest}")
    print(f"holds longest: {easiest}")


HEADER = """// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Produced by tools/build_surah_difficulty.py from the checked-in corpus.
// Change the generator and re-run it; edits here are lost on the next run."""


def _write_dart(
    tiers: dict[int, int],
    bulk: dict[int, float],
    verse_length: dict[int, float],
    mutashabihat: dict[int, float],
) -> None:
    rows = "\n".join(
        f"    {surah}: {tiers[surah]}, // {bulk[surah]:.0f} words, "
        f"{verse_length[surah]:.1f} per ayah, {mutashabihat[surah] * 100:.0f}% repeated"
        for surah in sorted(tiers)
    )
    DART_OUT.write_text(
        f"""{HEADER}

/// Which difficulty tier each surah falls in, measured from the text.
///
/// Tier 0 holds longest and tier 4 fades fastest; [SurahDifficulty.tierCoefficients]
/// maps a tier to the multiplier that divides the half-life. The comment on
/// each row is the evidence: total words, mean words per ayah, and the share of
/// five-word runs that occur more than once in the Quran.
class SurahDifficultyTable {{
  const SurahDifficultyTable._();

  static const Map<int, int> tierBySurah = {{
{rows}
  }};
}}
""",
        encoding="utf-8",
    )


def _write_csharp(tiers: dict[int, int]) -> None:
    rows = "\n".join(
        f"        [{surah}] = {tiers[surah]}," for surah in sorted(tiers)
    )
    CSHARP_OUT.write_text(
        f"""{HEADER}

namespace Tilawa.Api.Services;

/// <summary>
/// Which difficulty tier each surah falls in, measured from the text. Tier 0
/// holds longest, tier 4 fades fastest. Mirrors
/// <c>surah_difficulty_table.dart</c> in the app.
/// </summary>
public static class SurahDifficultyTable
{{
    public static readonly IReadOnlyDictionary<int, int> TierBySurah = new Dictionary<int, int>
    {{
{rows}
    }};
}}
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

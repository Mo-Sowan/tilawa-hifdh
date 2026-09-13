# AI Handoff Instructions

## Hard Rule

Never generate Quran text.

Do not invent, complete, or "correct" ayah text, ayah positions, or mushaf
coordinates. Every character of Quran in this app comes from a checked-in,
checksummed dataset produced by a generator in `tools/`.

## Where Quran Data Comes From

- `app/assets/quran/quran.json` - all 6,236 verses, Uthmani plus normalized
  text, shipped with the recognition model.
- `app/assets/quran/quran_ctc_tokens.json` - precomputed CTC token ids per
  verse, used for acoustic re-ranking.
- `app/assets/quran/quran_index.json` - surah/ayah to page, juz and hizb,
  imported by `tools/build_quran_index.py`, which records the source and a
  checksum in the file and cross-checks all 6,236 verses against the corpus.
- `backend/Tilawa.Api/Data/SurahCatalog.cs` - generated from the same corpus by
  `tools/build_surah_catalog.py`, so the API and the app cannot disagree.

To change any of it, change the generator and re-run it. Do not hand-edit the
outputs.

## Product Direction

Tilawa uses Duolingo-style motivation - path, streak, XP, progress, plans,
reminders - around two revision modes:

1. **Recite from memory.** The on-device recogniser follows along and reports
   which ayah the reciter reached, with the text hidden by default. The reciter
   then records their own recall estimate.
2. **Read from the Mushaf.** Scanned pages with an annotation overlay.

The recogniser reports position and recognition confidence. It never judges
whether a recitation was "correct", and the recall estimate stays the user's own.

## Still Out Of Scope

- Quran quiz engines, missing-word prompts, MCQs, word-sorting exercises.
- Any UI implying the app validates Quran correctness.
- Any Quran text produced by a model rather than read from the corpus.

## Before Coding

Read this folder, and `MERGE_NOTES.md` for how the codebase came together.

# Data Model

## Quran Data Policy

Quran text is rendered only from the checked-in corpus under
`app/assets/quran/`, which ships with the recognition model and carries
provenance and checksums. It is source-controlled canonical data, never
generated and never edited by hand - see `ai_handoff.md`.

The app stores revision metadata and user progress separately from it.

## Surah Revision Entity

Suggested fields:

- `number`
- `englishName`
- `arabicName`
- `juzLabel`
- `ayahCount`
- `mastery`
- `mistakeRate`
- `revisionCount`
- `lastReviewed`
- `revisionIntensity`

## Revision Plan

Suggested fields:

- selected Surah numbers,
- reminder time,
- due state.

## Self Assessment

User records confidence after revising:

- weak,
- shaky,
- good,
- excellent.

This is not Quran answer validation. It is user-owned progress tracking.

## Changing The Quran Dataset

Replacing or extending the corpus means:

- update the generator in `tools/`, not the output file,
- keep provenance and checksum metadata in the generated file,
- re-run `tools/build_surah_catalog.py` so the API catalogue follows,
- never generate text through a model.

## Ayah Annotation

Suggested persisted fields:

- `id`
- `surahNumber`
- `ayahNumber`
- `pageNumber`
- `type` (`highlight`, `bookmark`, `revisionMarker`)
- `colorValue`
- `note`
- `createdAt`
- `updatedAt`

Annotation records must remain separate from scanned page images and separate from Quran text assets.

## Recitation Session

Recorded after each on-device follow-along session:

- `surahNumber`
- `startedAt`
- `durationSeconds`
- `versesMatched` / `versesAttempted`
- `averageConfidence` (recognition confidence, not recall)
- `coveredRefs` (`"surah:ayah"` strings)

Stored locally first and mirrored to the API when reachable. No audio is stored
or transmitted.

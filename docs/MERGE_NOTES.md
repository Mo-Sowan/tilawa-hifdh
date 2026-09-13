# Merge notes

How Tilawa was assembled from **Revise / HifdhTracker** (the product) and
**Tilawa / offline-tarteel** (the recogniser), and why each decision went the
way it did.

## What each project brought

| | Revise | Tilawa (research repo) |
| --- | --- | --- |
| Kept | Clean `core / data / domain / presentation` layering with Riverpod; the whole UI — 13-palette theme, EN/AR with RTL, Mushaf image reader with an annotation overlay, progress path, streaks, XP, plans, activity calendar, celebration overlays; the mastery/mistake-rate decay rules; the offline-first remote→local repository fallback; the Mushaf page proxy with its disk cache | The FastConformer int4/int8 CTC ONNX export and its runtime contract; `RecitationTracker`'s discovery/tracking state machine; `QuranDB` candidate retrieval and joint rescue paths; CTC forward re-ranking; the 6,236-verse corpus and its precomputed CTC token table |
| Dropped | Two dead generations of code (`lib/screens`, `lib/widgets`, `lib/providers`, most of `lib/models`, a second `app_theme.dart`, `dashboard_view`, `routine_view`); the mock email/password login; the duplicated io/web API clients; the network-only `alquran.cloud` text service | Everything that is research rather than product: 24 `experiments/`, ~30 training and export scripts, the Modal pipeline, benchmark corpora, `web/server.py`, the browser worker and `AudioWorklet`, and the dead pre-text-CTC phoneme path (`mel.ts`, `phoneme-trie.ts`, `beam-decode.ts`) |

## Decisions

**Flutter as the client.** Revise already had the entire product surface, and
the recogniser's text-CTC path is pure logic with no browser dependency, so it
ported to Dart cleanly. The alternative — rebuilding the tracker UI around the
TypeScript engine — would have thrown away far more working code.

**`flutter_onnxruntime`, not `onnxruntime`.** The model quantizes its MatMul
weights to int4 (`MatMulNBits`), which needs a recent ONNX Runtime.
`flutter_onnxruntime` 1.8.4 bundles ORT 1.23; the FFI-based `onnxruntime` 1.4.1
is two years old and predates that kernel.

**Inference in a worker isolate.** A pass takes hundreds of milliseconds. On the
UI isolate it would visibly stutter the follow-along highlight. The isolate
calls platform channels through `BackgroundIsolateBinaryMessenger`.

**Two separate Quran indexes, deliberately.** `QuranCorpus` (matcher: verse
text, CTC token ids, span tables) lives only inside the worker isolate;
`QuranTextIndex` (display: text plus Mushaf position) lives on the UI isolate.
Loading the full corpus twice on one isolate would have doubled a large
allocation for no benefit.

**Model downloaded, not bundled.** 88 MB is past a reasonable app-bundle budget.
It is fetched once, SHA-256 verified against the export manifest, and cached.
Dropping the file into `assets/model/` bundles it instead, for anyone who wants
a fully self-contained build.

**Federated sign-in only.** Revise's `AuthNotifier.login()` accepted any email
and password after a `Future.delayed`, returning a hard-coded `mock-user-id`.
Google and Apple replace it: the app forwards an identity token, the API
verifies it against the provider's published keys and issues its own session.
Refresh tokens are stored hashed and rotate on every use.

## Corrections made along the way

These were defects in the originals, not merge artifacts:

* **The API was single-user.** No entity had a `UserId`; every installation
  shared one dataset. Now `Users`, `RefreshTokens`, and per-user
  `UserSurahProgress` / `RevisionPlans` / `ActivityDays` / `RecitationSessions`,
  with a shared `Surahs` catalogue. Every repository method resolves the caller
  from `IUserContext`, so a request cannot reach another account's rows — a
  property the integration tests assert directly.
* **The surah catalogue was incomplete and inconsistent.** The API seeded 48
  surahs (67–114) while the app seeded all 114, and plan validation rejected
  anything below 67 even though plans were built from the app's full list. Both
  sides are now generated from the same corpus by
  `tools/build_surah_catalog.py`, and plans accept 1–114.
* **Notifications fired on every lifecycle transition** — including `resumed`
  and `detached` — so one app switch produced three notifications. Now only
  `paused`.
* **`DateTimeOffset` could not be queried on SQLite.** Ordering and comparing
  refresh tokens and sessions failed to translate. A context-wide converter
  stores them as UTC ticks.
* **The Mushaf proxy was never called.** The backend had a caching page-image
  endpoint and the reader computed `baseUrl` for it, but then loaded the images
  straight from archive.org and discarded the variable. The reader now goes
  through the proxy and falls back to the archive.
* **Mushaf start pages were a hard-coded table** duplicated in the app. It is
  now read from the generated position index.

## Deviations from the reference tracker

The port follows `tracker.ts` and `quran-db.ts` decision for decision, with two
deliberate differences:

* **Environment-variable tuning knobs are gone.** `STREAMING_HYPOTHESIS_*` and
  `DECODE_STABILITY_GATE_OFF` existed for benchmarking a Node process. On a
  phone they cannot be set; the defaults they fell back to are now the
  constants, and the stability gate is a `StreamingConfig` field.
* **The whole-corpus span rescue table is stored by index.** The reference
  caches a materialized string and two n-gram `Set`s for each of ~37,000 spans,
  which would cost hundreds of megabytes on a phone. Instead the query's n-grams
  are indexed once per call and each verse is reduced to a bitmask over them, so
  a span's coverage is the OR of its members' masks; text is materialized only
  for the few hundred rows that survive. The only scoring difference is that
  n-grams straddling a verse join are not counted — immaterial for a rough
  shortlist that is then re-scored by edit distance.

## Platform splits

The recogniser and storage reach for `dart:io`, `dart:isolate`, SQLite and the
filesystem, none of which exist in a browser, so four seams are resolved by
conditional import:

| Seam | Native | Web |
| --- | --- | --- |
| `LocalStore` | SQLite via `sqflite` | `localStorage`, loaded once into memory |
| `RecitationEngine` | worker isolate | same pipeline on the main isolate |
| `ModelManager` | download, checksum, cache on disk | bundled asset only |
| `exportFileAndDownload` | writes to the documents directory | browser download |

`RecitationPipeline` holds the corpus, the ONNX session and the tracker with no
isolate or platform-channel dependency of its own, so both engines share it
rather than duplicating the transcribe-and-track loop. `Platform.isIOS` in the
auth provider became `defaultTargetPlatform`, which needs no `dart:io` at all.

Two things surfaced while getting the web build running, and both were real bugs
on every platform:

* `rootBundle` reports a missing asset with a `FlutterError`, which is an
  `Error`, not an `Exception` — so every `on Exception` guard around an optional
  asset was dead code. A missing model showed up as a raw
  `Unable to load asset:` string instead of the intended message.
* A localisation string still claimed the app shows no Quran text until a
  reviewed Qaloon source is connected, which the merged app contradicts on
  every screen.

## Where the recogniser can run

The model's quantized convolutions use the `ConvInteger` operator. Native ONNX
Runtime implements it; **ONNX Runtime Web does not**. Loading the model in a
browser fails session creation with:

    Could not find an implementation for ConvInteger(10) node with name
    '/encoder/pre_encode/conv/conv.0/Conv_quant'

Verified against `onnxruntime-web` 1.21 (`ort.min.js`) and the full 1.23 bundle
(`ort.all.min.js`), with the model bundled as an asset so no download or path
issue was involved. So:

| Platform | Recognition |
| --- | --- |
| Android, iOS, Windows, macOS, Linux | supported |
| Web | not supported — the UI says so and disables the microphone |

Two setup details found along the way, both now handled:

* `flutter_onnxruntime`'s web path needs `onnxruntime-web` loaded in
  `web/index.html` before Flutter boots, or session creation dies on a null
  check because the global `ort` object is missing.
* On web that plugin hands the asset key straight to ONNX Runtime as a URL, but
  Flutter serves bundled assets under an extra `assets/` segment — so the key
  has to be turned into a real URL, or the fetch 404s and surfaces as a
  misleading "failed to load external data file".

Re-exporting the encoder without int8 convolutions would make a browser build
possible; `UnsupportedModelManager` is the only place that would need changing.

## Mastery

The original rule accumulated small increments: mastery started at 0.05 and a
review nudged it by roughly `+0.06 + confidence * 0.003`. A first perfect recall
therefore read as about 14%, which is not what the reciter just told the app,
and nothing ever decreased unless they rated themselves badly — memorisation
that had not been touched in months still read as strong.

`MasteryModel` replaces it with two rules, implemented identically in
`app/lib/domain/entities/mastery.dart` and
`backend/Tilawa.Api/Services/MasteryModel.cs`:

* **A review moves mastery toward the reported confidence.** The first review
  lands on it outright — 10/10 is 100% — while later reviews blend, weighted by
  the confidence itself, so one shaky pass does not erase a long history and one
  good pass after a lapse does not instantly claim full mastery back.
* **Mastery decays between reviews**, exponentially, with a half-life that grows
  each time the surah is recalled well: 7 days after one good recall, ~13 after
  two, ~23 after three, capped at 180. That is the spacing effect.

So the stored value is mastery *at the last review*, and the displayed value is
that faded by elapsed time. The wire carries the stored value plus the recall
streak; both sides apply the same decay, so a figure is never stale in transit.
Priority ranking, XP and the mastery buckets all read the decayed value, which
is what makes a neglected surah climb the revision list on its own.

Both implementations are covered by mirrored suites — `mastery_test.dart` and
`MasteryModelTests.cs` — that assert the same numbers.

## Fonts

The inherited code styled Quranic text with `fontFamily: 'Scheherazade'` in six
places and surah names with `'Uthmani'` — **neither font was ever bundled**, and
neither project had a `fonts:` section. Flutter falls back silently, so every
verse rendered in the default system Arabic face, which does not place Quranic
marks correctly.

Three faces are now bundled, all SIL OFL with their licences beside them in
`app/assets/fonts`:

| Family | Face | Used for |
| --- | --- | --- |
| `QuranText` | Amiri Quran | verse text — drawn for the Mushaf, carries the full mark set |
| `ScheherazadeNew` | Scheherazade New | surah titles and Arabic display text |
| `Outfit` | Outfit (variable) | the interface |

The family names live on `AppTheme` rather than as string literals at each call
site, so a missing font is a compile error rather than a silent fallback.

Verse text was briefly set in the King Fahd Complex's own Uthmanic Script HAFS,
the typeface the printed Madinah Mushaf uses. It is the more faithful face on
paper, but it did not read well in the app and was reverted on the reciter's
say-so. Amiri Quran stands. Anyone revisiting this should know that the KFGQPC
face needs two accommodations Amiri Quran does not: it reserves 2400 units above
the baseline and 1200 below out of 2048 per em, so it needs a taller line box
than 2.0; and it draws Arabic-Indic digits inside the ayah medallion by itself,
so prefixing U+06DD — which is exactly what Amiri Quran requires — prints a
second, empty medallion beside the first.

Outfit was previously pulled at run time by `google_fonts`, which downloads on
first launch and fails outright with no network — wrong for an app built to work
offline. The package is gone and the font is bundled.

## The reveal: covered text, not a Mushaf page

The recitation screen went through two wrong shapes before this one. It first
offered a choice between the scanned Qaloon page and plain text, then a single
text view laid out one Mushaf page at a time inside a decorative parchment
frame. Both were readers. This screen is not for reading — it is for finding
out what you can recall — and a reader is exactly the wrong tool for that.

What it does now is what Tarteel does. The whole surah scrolls continuously,
and every word sits under its own cover. A word uncovers when the recogniser
hears the reciter say it, so the page fills in behind them and shows at a
glance how far they got and where they stalled. Tapping a word peeks at that
one word; tapping an ayah number opens that ayah; the eye in the title bar
uncovers everything.

Two details make it work rather than merely look right:

* The cover is drawn at the exact size of the word beneath it — the word is
  always laid out, and hiding it only makes its glyphs transparent. Uncovering
  therefore never reflows the text, so a revealed word appears exactly where
  its cover was.
* The Uthmani text carries standalone pause and hizb marks (`ۖ`, `۞` and the
  rest). They are printed in the Mushaf but nobody recites them, so they are
  never covered — and, as in the recogniser, which works from the phoneme text
  and never sees them, they are not counted when working out how far into an
  ayah the reciter has got. `_AyahBlock._isWord` decides this by asking
  `normalizeArabic` whether anything survives, which is the same question the
  recogniser asks, so the two cannot drift apart. For the ~200 verses where the
  two texts still split tokens differently, the position is scaled across
  rather than trusted as an index.

`MushafPageFrame` went with the page layout: it had no other caller, and a
decorative frame nobody draws is dead weight. The scanned Qaloon Mushaf is
still one tap away behind the book icon, which is where a reader belongs.

## Reader load time

The reader parsed `quran.json` (3.2 MB) plus `quran_index.json` (375 KB) on the
UI isolate. Most of those bytes are repetition: every one of the 6,236 rows
restates its surah names and its JSON field names.

`tools/build_display_index.py` packs the same facts into `quran_display.json` —
positional rows, surah names stored once — which is 2.1 MB against 3.5 MB of
former input, in one file instead of two. It derives entirely from the two
sources and checks its row counts against both.

That file is then parsed inside `compute`, so the work happens off the UI
isolate and no frame is blocked. (`compute` runs inline on the web, which has no
isolates; there the saving is the smaller file alone.)

## Verified

* `flutter analyze` — clean.
* `flutter test` — 56 tests: Arabic normalization, Levenshtein/fragment/partial
  scoring, CTC decode and word-end derivation, CTC forward scoring and prefix
  selection, verse indexing, basmala stripping, surah rollover, matching,
  continuation bonuses, tracker commit/progress/reset/no-match behaviour,
  config clamping, the mark-versus-word rule the reader's covers rely on,
  and an app boot smoke test.
* `dotnet test` — 46 tests: the mastery model, plus integration tests over the real HTTP pipeline: anonymous
  rejection, sign-in and account reuse, provider separation, refresh rotation
  and replay rejection, sign-out revocation, the 114-surah catalogue,
  assessment and progress maths, plan CRUD and validation, recitation session
  round-trip and clamping, and cross-account isolation for progress, plans and
  sessions.
* `flutter build bundle` — Dart compiles for Android and all five corpus assets
  are packaged.
* `flutter build web --release` — builds, and was exercised in a browser:
  onboarding, guest entry, dashboard, the offline fallback when the API is
  unreachable, self-assessment writing through to mastery/XP/streak and the
  114-surah navigator, settings, and the recitation screen — covered text,
  tap-to-peek on a word, tap-an-ayah-number, reveal-all, the basmala shown for
  Al-Baqarah and withheld for At-Tawba and Al-Fatiha, and verse text rendering
  in the Uthmanic face with its ayah medallions. Guest state and progress
  survived a reload, confirming the `localStorage` path.

Not verified here: the Gradle APK build (the sandbox blocks the loopback socket
Gradle needs), and anything requiring a device — real microphone capture, ONNX
inference on-device, the Google/Apple sign-in dialogs, and therefore the one
part of the reveal that only the recogniser can drive: words uncovering as they
are recited, and the list following the reciter down the surah.

# Tilawa

A Quran hifdh companion that listens to your recitation **entirely on-device**
and follows along, ayah by ayah — then tracks your revision the way a study
plan should.

It is the merge of two earlier projects:

* **Revise / HifdhTracker** — the Flutter app (Duolingo-style progress path,
  streaks, XP, revision plans, Mushaf reader with annotations, EN/AR with RTL)
  and the ASP.NET Core API behind it.
* **Tilawa (offline-tarteel)** — the offline recitation recogniser: a
  FastConformer CTC model exported to ONNX plus a streaming verse tracker that
  reached 100% recall and 100% sequence accuracy on its benchmark corpus.

## What makes it work offline

The recogniser takes raw 16 kHz mono audio and returns CTC log-probabilities;
feature extraction is compiled into the ONNX graph, so there is no separate
mel-spectrogram step. A greedy BPE decode is matched against a bundled index of
all 6,236 verses, then re-ranked by scoring each candidate's token sequence
against the same acoustic frames.

Everything runs in a background isolate on the phone. **No audio ever leaves the
device** — the API only ever receives which ayat were matched.

```
microphone → 16 kHz PCM → ONNX CTC → greedy decode → candidate retrieval
                                          ↓                    ↓
                                    verse tracker  ←  CTC re-ranking
                                          ↓
                            verse_match / word_progress events
```

## Layout

```
app/                     Flutter client (Android, iOS, web, Windows, macOS, Linux)
  lib/core/              theme, localization, config, utilities
  lib/domain/            entities, repository contracts, use cases
  lib/data/              API client, local store, Quran text index
  lib/presentation/      views, widgets, providers
  lib/features/recitation/
    engine/              pure Dart: normalizer, Levenshtein, CTC decode/rescore,
                         verse index, streaming tracker
    data/                corpus loader, model download + checksum
    service/             ONNX session, worker isolate, microphone capture
    presentation/        live recitation screen and providers
  assets/quran/          verse text, CTC token table, vocabulary, page index,
                         and the generated display index the reader loads
  assets/fonts/          Amiri Quran, Scheherazade New, Outfit (all SIL OFL)
backend/Tilawa.Api/      ASP.NET Core 8 API (SQLite, JWT, Google/Apple sign-in)
backend/Tilawa.Api.Tests/ integration tests against the real HTTP pipeline
tools/                   asset and catalogue generators, build scripts
docs/                    architecture and product context
```

## Running it

### Backend

```bash
dotnet run --project backend/Tilawa.Api/Tilawa.Api.csproj --urls http://localhost:5188
```

Swagger is at `http://localhost:5188/swagger` in development. In development a
throwaway JWT signing key is generated at startup; in any other environment
`Jwt:SigningKey` must be supplied or the API refuses to start.

With Docker:

```bash
TILAWA_JWT_SIGNING_KEY=$(openssl rand -base64 48) docker compose up --build
```

### App

```bash
cd app
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5188 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id> \
  --dart-define=GOOGLE_CLIENT_ID=<ios client id>
```

`10.0.2.2` is the host as seen from the Android emulator; use `localhost` for
iOS simulators and desktop, or your machine's LAN IP for a physical device.

To build an installable APK:

```bash
cd app && flutter build apk --release
```

### Web

The same app runs in a browser, which is the quickest way to click through it:

```bash
./tools/build_web.ps1 -AllowGuest -Serve
```

Then open <http://localhost:8080>. `-AllowGuest` adds a "Continue without an
account" button so the build is explorable without a configured OAuth client or
a running API; progress is kept in `localStorage` and nothing syncs.

On-device recitation is the one feature the web build cannot do. The model's
quantized convolutions need the `ConvInteger` operator, which ONNX Runtime Web
does not implement, so the recitation screen says so and disables the
microphone. Bundling the model does not help — see
[docs/MERGE_NOTES.md](docs/MERGE_NOTES.md). Use an Android, iOS or desktop build
to try the recogniser.

### The recitation model

The ONNX model is ~88 MB, too large to ship inside the app bundle, so it is
downloaded once on first use and cached in the app's support directory. The
download is verified against the SHA-256 in `assets/quran/export_metadata.json`
before it is used.

To bundle it instead — fully self-contained, no first-run download — drop the
file at `app/assets/model/fastconformer_full_mixed.onnx` before building. To
serve it from your own host, build with
`--dart-define=MODEL_URL=https://your.cdn/fastconformer_full_mixed.onnx`.

## Sign-in

Identity is federated to Google and Apple. The app obtains an identity token
from the provider, the API verifies it against the provider's published keys,
and issues its own short-lived access token plus a rotating refresh token. The
app never handles a password, and the API stores no password hash.

Configure the accepted audiences on the API:

```json
{
  "Auth": {
    "Google": { "ClientIds": ["<web client id>", "<ios client id>"] },
    "Apple":  { "ClientIds": ["com.tilawa.app", "<service id>"] }
  }
}
```

## Data provenance

Quran text comes from the corpus published with the recognition model, and the
Mushaf position index (`assets/quran/quran_index.json`) is imported from the
alquran.cloud Uthmani edition by `tools/build_quran_index.py`, which records the
source, generation date and a checksum in the file itself and cross-checks every
one of the 6,236 verses against the corpus. `tools/build_surah_catalog.py`
generates the API's surah catalogue from the same corpus, so the app and the
API cannot drift apart. `tools/build_display_index.py` packs the corpus and the
position index into the single compact file the reader loads. No Quran text or
position data is hand-written or generated.

Re-run `build_display_index.py` after changing either source.

## Verification

```bash
cd app && flutter analyze && flutter test
cd backend && dotnet test Tilawa.slnx
```

See [docs/MERGE_NOTES.md](docs/MERGE_NOTES.md) for what came from where and why.

# Project structure

Two deliverables in one repo:

```
app/        Flutter client
backend/    ASP.NET Core 8 API (EF Core + SQLite)
tools/      Generators for the checked-in Quran datasets
docs/       This, plus MERGE_NOTES.md and HANDOFF.md
```

## `app/lib` — layers

The four layers depend strictly downward: `presentation → domain ← data`, with
`core` and `services` available to all. Nothing in `domain` imports Flutter.

```
core/          Cross-cutting: config, localization, theme, utils.
domain/        Entities, repository interfaces, use cases. Pure Dart, no
               Flutter, no I/O — which is why it is where the rules live
               (mastery decay, hasanat counting, qibla bearing) and why those
               are the parts with real unit tests.
data/          Repository implementations, API client, local database, and the
               generated Quran datasets.
services/      Platform edges: on-device storage, notifications.
presentation/  Everything the reciter sees.
recitation/    The on-device recogniser, kept as a bounded module (see below).
```

### Imports are `package:` URIs, everywhere

Not relative paths. Moving a file then only requires repointing references to
it, rather than recomputing `../..` in every file it touches. It also makes the
layer a file belongs to legible from its own import list.

## `presentation/` — feature-first

```
presentation/
  features/
    <feature>/
      <feature>_view.dart     The screen: routing, state, layout.
      widgets/                One file per component on that screen.
  providers/                  Riverpod providers, shared across features.
  widgets/                    Widgets used by more than one feature.
```

Features: `account`, `auth`, `home`, `leaderboard`, `mushaf`, `onboarding`,
`plan`, `progress`, `settings`, `shell`, `surah_detail`, `utilities`.

`shell` holds `MainView` and `RootNavigator` — the navigation frame rather than
a screen of its own.

**One component per file.** A widget that had been a private class inside a
1,000-line view is now a public class in its own file. Privacy in Dart is per
*library*, not per class, so a widget in its own file must be public to be used
— that is the cost, and it is worth paying: the previous arrangement made
`home_view.dart` 1,053 lines and gave eight unrelated widgets access to each
other's internals.

The rule of thumb: if it has a `build` method, it has a file.

### Where a widget belongs

- Used by one feature → `features/<feature>/widgets/`.
- Used by two or more → `presentation/widgets/`.

A widget that starts in a feature and is later wanted elsewhere moves up. That
is a real move, not a shortcut import across features: features do not import
each other's widgets.

## `recitation/` — a bounded module

The recogniser is separate from `presentation/features/` on purpose. It is a
port of a research codebase with its own engine, corpus, isolate management and
platform splits, and it changes for reasons that have nothing to do with the
rest of the app.

```
recitation/
  engine/        Pure Dart: decoder, tracker, matcher, normalizer. No Flutter.
  data/          The recogniser's own corpus and model management.
  service/       The isolate and ONNX session, with io/web variants.
  presentation/  The live recitation screen and its widgets.
```

## Platform variants

Where behaviour genuinely differs between mobile and web, the split is a
conditional import on a shared interface, not an `if (kIsWeb)` scattered
through the code:

```dart
import 'local_store_io.dart'
    if (dart.library.js_interop) 'local_store_web.dart' as impl;
```

Used by `services/local_store`, `recitation/data/model_manager` and
`recitation/service/recitation_engine`.

## Quran data is generated, never written by hand

`app/assets/quran/*.json` is produced by the scripts in `tools/` from
checked-in, checksummed sources. To change what the app displays, change the
generator and re-run it. Nothing — no person, no model — writes Quranic text
directly into this repo.

## Tests

```
app/test/
  domain/       The rules: mastery decay, hasanat, qibla, preferences.
  recitation/   The engine.
  *.dart        Widget and integration tests.
backend/Tilawa.Api.Tests/
```

Rules implemented on both sides — mastery decay and the surah difficulty table
— have mirrored suites in Dart and C#. Change one, change the other.

## Verifying

```bash
cd app && flutter analyze && flutter test
cd ../backend && dotnet test
```

`flutter analyze` is expected to report zero issues. Two environment notes that
will otherwise cost an hour each are in [HANDOFF.md](HANDOFF.md): Flutter is not
on `PATH`, and Gradle needs `TEMP`/`TMP` moved off the default.

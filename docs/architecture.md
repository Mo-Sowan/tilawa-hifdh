# Architecture

## Layers

- `core`
- `data`
- `domain`
- `presentation`
- `recitation` (self-contained offline recognition module)

## Core

- Theme
- Localization
- Shared constants

## Data

- API client and offline-first repositories
- Local database: settings, ayah annotations, recitation sessions
- `QuranTextIndex`: the bundled corpus as the UI needs it

No generated Quran text belongs here.

## Domain

- Surah revision entity
- Revision plan entity
- Repository contracts
- Use cases for overview, weakest/priority Surah, and self-assessment

## Presentation

- Dashboard
- Surah navigator
- Surah detail/self-assessment
- Revision plan sheet
- Reminder banner

## Recitation

A bounded module with its own layering:

- `engine` - pure Dart, no Flutter: Arabic normalization, edit distance, CTC
  decoding and forward scoring, the verse index, the streaming tracker.
- `data` - corpus loader and model download with checksum verification.
- `service` - ONNX session, the worker isolate that owns it, microphone capture.
- `presentation` - the live recitation screen and its providers.

Inference and matching run on a background isolate. Nothing in `engine` imports
Flutter, so all of it is unit-testable without a device.

## Not Part Of The Architecture

- Quran quiz engine
- Generated Quran prompts
- AI-created Quran text
- Quran answer validation

## Ayah Highlighting Overlay

The Mushaf image reader uses a mapping layer rather than selectable text:

`Surah -> Ayah -> Page -> Source-image bounding boxes`

Highlights and annotation controls are rendered in `MushafAnnotationOverlay` above the scanned page. Original page images are never modified. The mapping layer intentionally ships empty until verified Libyan Qaloon/Jamahiriya coordinate data is imported.

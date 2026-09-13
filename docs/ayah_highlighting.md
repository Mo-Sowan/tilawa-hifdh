# Ayah Highlighting And Annotation Architecture

## Principle

The Mushaf reader uses scanned page images. Quran text is not selectable in that mode, and the app must not draw highlights into the original image files.

All ayah interaction is powered by a separate mapping layer:

`Surah -> Ayah -> Page -> Bounding Region`

The image asset remains read-only. Highlights, notes, bookmarks, and revision markers are rendered through a Flutter overlay above the scanned page.

## Mapping Model

The mapping layer stores source-image coordinates, not device coordinates.

```json
{
  "surah": 2,
  "ayah": 255,
  "page": 44,
  "line": 8,
  "boxes": [
    { "x": 120, "y": 840, "width": 620, "height": 55 }
  ]
}
```

A single ayah may have multiple boxes when it spans more than one line. The model also reserves `words` for future word-level mapping.

## Scaling

Coordinates are measured against the original scanned page image size. The overlay maps those rectangles into the current viewport using `BoxFit.contain`, so the same saved annotation remains aligned across:

- screen size changes,
- orientation changes,
- zoom level changes,
- different device pixel ratios.

## Persistence

User annotations are stored separately from image assets in the local database table `ayah_annotations`.

Stored fields:

- annotation id,
- surah number,
- ayah number,
- page number,
- annotation type,
- highlight color,
- optional user note,
- created timestamp,
- updated timestamp.

## Safety

The project currently ships no fabricated ayah coordinate dataset. The mapper returns empty page mappings until a verified Libyan Qaloon/Jamahiriya mapping file is added and reviewed.

Do not generate Quran text or ayah positions with AI. Mapping data must be imported from a verified source or produced through a reviewed manual/data pipeline with provenance and checksum metadata.

## Future Compatibility

The architecture supports:

- complete ayah highlighting,
- multi-ayah highlighting,
- notes,
- bookmarks,
- revision markers,
- return-to-highlight navigation,
- edit/remove annotation flows,
- word-level highlighting,
- audio synchronization,
- mistake tracking,
- tafsir links,
- AI-assisted revision metadata that references ayah IDs but never fabricates Quran text.

import 'dart:ui';

/// Immutable reference to an ayah.
///
/// The app uses this as the primary key for annotations instead of storing
/// Quran text. Quran content must come from a verified Libyan Qaloon source.
class AyahReference {
  const AyahReference({
    required this.surahNumber,
    required this.ayahNumber,
  });

  final int surahNumber;
  final int ayahNumber;

  String get key => '$surahNumber:$ayahNumber';

  factory AyahReference.fromJson(Map<String, dynamic> json) {
    return AyahReference(
      surahNumber: json['surah'] as int,
      ayahNumber: json['ayah'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surah': surahNumber,
      'ayah': ayahNumber,
    };
  }
}

/// A rectangle measured against the original scanned page image.
///
/// Do not store screen coordinates here. Keeping source-image coordinates lets
/// the overlay scale accurately across phones, tablets, zoom, and orientation.
class PageBoundingBox {
  const PageBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Rect toRect() => Rect.fromLTWH(x, y, width, height);

  factory PageBoundingBox.fromJson(Map<String, dynamic> json) {
    return PageBoundingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

/// Region for a complete ayah on an image page.
///
/// One ayah can occupy multiple line boxes, so this model stores a list of
/// boxes. Word-level regions can be attached later without changing ayah IDs.
class AyahRegion {
  const AyahRegion({
    required this.reference,
    required this.pageNumber,
    required this.lineNumber,
    required this.boxes,
    this.wordRegions = const [],
  });

  final AyahReference reference;
  final int pageNumber;
  final int lineNumber;
  final List<PageBoundingBox> boxes;
  final List<WordRegion> wordRegions;

  factory AyahRegion.fromJson(Map<String, dynamic> json) {
    return AyahRegion(
      reference: AyahReference.fromJson(json),
      pageNumber: json['page'] as int,
      lineNumber: json['line'] as int? ?? 0,
      boxes: (json['boxes'] as List<dynamic>? ?? const [])
          .map((box) => PageBoundingBox.fromJson(box as Map<String, dynamic>))
          .toList(),
      wordRegions: (json['words'] as List<dynamic>? ?? const [])
          .map((word) => WordRegion.fromJson(word as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...reference.toJson(),
      'page': pageNumber,
      'line': lineNumber,
      'boxes': boxes.map((box) => box.toJson()).toList(),
      'words': wordRegions.map((word) => word.toJson()).toList(),
    };
  }
}

/// Future-ready word region for audio sync, word highlighting, and mistakes.
class WordRegion {
  const WordRegion({
    required this.wordIndex,
    required this.box,
  });

  final int wordIndex;
  final PageBoundingBox box;

  factory WordRegion.fromJson(Map<String, dynamic> json) {
    return WordRegion(
      wordIndex: json['wordIndex'] as int,
      box: PageBoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wordIndex': wordIndex,
      'bbox': box.toJson(),
    };
  }
}

/// All spatial mapping data for a scanned Mushaf page.
class MushafPageMapping {
  const MushafPageMapping({
    required this.pageNumber,
    required this.sourceImageSize,
    required this.ayahRegions,
  });

  final int pageNumber;
  final Size sourceImageSize;
  final List<AyahRegion> ayahRegions;

  factory MushafPageMapping.empty(int pageNumber) {
    return MushafPageMapping(
      pageNumber: pageNumber,
      sourceImageSize: QuranPageMapper.defaultSourceImageSize,
      ayahRegions: const [],
    );
  }

  factory MushafPageMapping.fromJson(Map<String, dynamic> json) {
    return MushafPageMapping(
      pageNumber: json['page'] as int,
      sourceImageSize: Size(
        (json['imageWidth'] as num).toDouble(),
        (json['imageHeight'] as num).toDouble(),
      ),
      ayahRegions: (json['ayahs'] as List<dynamic>? ?? const [])
          .map((ayah) => AyahRegion.fromJson(ayah as Map<String, dynamic>))
          .toList(),
    );
  }

  AyahRegion? regionFor(AyahReference reference) {
    for (final region in ayahRegions) {
      if (region.reference.key == reference.key) {
        return region;
      }
    }
    return null;
  }
}

/// Mapping repository for image-based Mushaf interaction.
///
/// This intentionally ships with no fabricated coordinate data. A later phase
/// should load reviewed JSON from assets/mapping and verify its checksum.
class QuranPageMapper {
  static const Size defaultSourceImageSize = Size(1024, 1536);

  const QuranPageMapper();

  Future<MushafPageMapping> loadPageMapping(int pageNumber) async {
    // TODO: Load assets/mapping/qaloon_jamahiriya_page_map.json after it is
    // reviewed. Returning an empty mapping keeps image rendering safe today.
    return MushafPageMapping.empty(pageNumber);
  }

  Future<int?> getPageForAyah(AyahReference reference) async {
    // TODO: Resolve from verified mapping index.
    return null;
  }
}

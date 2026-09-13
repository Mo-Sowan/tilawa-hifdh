/// Arabic normalization shared by the decoder, the verse index and the matcher.
///
/// Ported 1:1 from the reference TypeScript implementation so that a decoded
/// transcript and a precomputed verse string are always comparable.
library;

final RegExp _diacritics = RegExp(
  '[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DE\u06DF-\u06ED\u0640]',
);

const Map<String, String> _normalizationMap = {
  '\u0623': '\u0627', // أ -> ا
  '\u0625': '\u0627', // إ -> ا
  '\u0622': '\u0627', // آ -> ا
  '\u0671': '\u0627', // ٱ -> ا
  '\u0629': '\u0647', // ة -> ه
  '\u0649': '\u064A', // ى -> ي
};

final RegExp _whitespace = RegExp(r'\s+');

/// Strips the byte-order mark and Quranic diacritics, folds hamza/alif
/// variants, then collapses whitespace.
String normalizeArabic(String text) {
  final stripped = text.replaceAll('\ufeff', '').replaceAll(_diacritics, '');
  final buffer = StringBuffer();
  for (final rune in stripped.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_normalizationMap[ch] ?? ch);
  }
  return buffer
      .toString()
      .split(_whitespace)
      .where((part) => part.isNotEmpty)
      .join(' ');
}

/// Splits on runs of whitespace, dropping empty fragments.
List<String> splitWords(String text) =>
    text.split(_whitespace).where((word) => word.isNotEmpty).toList();

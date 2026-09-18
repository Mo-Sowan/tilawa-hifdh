
/// One saying, with where it came from.
class Wisdom {
  const Wisdom({
    required this.arabic,
    required this.english,
    required this.reference,
    required this.isQuran,
  });

  final String arabic;
  final String english;
  final String reference;

  /// Quran or Sunnah, shown as a badge so the two are never conflated.
  final bool isQuran;
}

/// Which part of a surah a review covered.
///
/// Stored as the enum's name rather than as its label, so a session recorded
/// in Arabic still reads correctly after the app is switched to English, and
/// so the value can be counted and compared later. Free text could do none of
/// that: a hundred sessions produce a hundred spellings of the same three
/// ideas.
///
/// The ayah ranges are computed from each surah's own length, so "the first
/// quarter" means something different for Al-Baqarah than for An-Nas, as it
/// should.
enum RevisionSection {
  whole,
  firstQuarter,
  firstHalf,
  secondHalf,
  lastQuarter,
  scattered;

  /// Prefix marking a stored value as an explicit ayah range.
  static const String customPrefix = 'custom:';

  /// The stored form of a range the reciter typed, e.g. `custom:12-40`.
  static String customValue(int from, int to) => '$customPrefix$from-$to';

  /// Reads a stored value back as a range, or null if it is not one.
  static (int, int)? parseCustom(String? value) {
    if (value == null || !value.startsWith(customPrefix)) return null;
    final parts = value.substring(customPrefix.length).split('-');
    if (parts.length != 2) return null;
    final from = int.tryParse(parts[0]);
    final to = int.tryParse(parts[1]);
    if (from == null || to == null) return null;
    return (from, to);
  }

  /// How a stored value reads, whether it is a preset or a typed range.
  static String describe(
    String? value, {
    required bool isArabic,
    required int ayahCount,
  }) {
    final custom = parseCustom(value);
    if (custom != null) {
      return isArabic
          ? 'الآيات ${custom.$1}-${custom.$2}'
          : 'Ayahs ${custom.$1}-${custom.$2}';
    }
    final section = fromName(value);
    if (section == null) return '';
    return section.label(isArabic: isArabic, ayahCount: ayahCount);
  }

  static RevisionSection? fromName(String? name) =>
      name == null ? null : values.where((v) => v.name == name).firstOrNull;

  /// The ayah range this covers in a surah of [ayahCount] ayahs, or null for
  /// the sections that do not describe a contiguous run.
  (int, int)? rangeIn(int ayahCount) {
    if (ayahCount <= 0) return null;
    final quarter = (ayahCount / 4).ceil();
    final half = (ayahCount / 2).ceil();

    switch (this) {
      case RevisionSection.whole:
        return (1, ayahCount);
      case RevisionSection.firstQuarter:
        return (1, quarter);
      case RevisionSection.firstHalf:
        return (1, half);
      case RevisionSection.secondHalf:
        return (half + 1, ayahCount);
      case RevisionSection.lastQuarter:
        return (ayahCount - quarter + 1, ayahCount);
      case RevisionSection.scattered:
        return null;
    }
  }

  String baseLabel({required bool isArabic}) {
    switch (this) {
      case RevisionSection.whole:
        return isArabic ? 'السورة كاملة' : 'The whole surah';
      case RevisionSection.firstQuarter:
        return isArabic ? 'الربع الأول' : 'First quarter';
      case RevisionSection.firstHalf:
        return isArabic ? 'النصف الأول' : 'First half';
      case RevisionSection.secondHalf:
        return isArabic ? 'النصف الثاني' : 'Second half';
      case RevisionSection.lastQuarter:
        return isArabic ? 'الربع الأخير' : 'Last quarter';
      case RevisionSection.scattered:
        return isArabic ? 'آيات متفرقة' : 'Scattered ayahs';
    }
  }

  /// The label with its ayah range, where it has one.
  String label({required bool isArabic, required int ayahCount}) {
    final base = baseLabel(isArabic: isArabic);
    final range = rangeIn(ayahCount);
    if (range == null || this == RevisionSection.whole) return base;
    return '$base (${range.$1}-${range.$2})';
  }
}

/// The four landmarks of the backward hifdh path.
///
/// Memorisation is most often walked from the end — Juz Amma first, then
/// backwards towards Al-Baqarah — and along that road three surahs mark the
/// quarters. They are not arbitrary: each sits on a real juz boundary.
///
/// | Landmark          | Reached from An-Nas | Juz  | Share |
/// | ----------------- | ------------------- | ---- | ----- |
/// | Yaseen (36)       | 114 → 36            | 23–30| ~1/4  |
/// | Al-Kahf (18)      | 114 → 18            | 15–30| 1/2   |
/// | Al-Anfal (8)      | 114 → 8             | 9–30 | ~3/4  |
/// | the whole Quran   | 114 → 1             | 1–30 | 1     |
///
/// Al-Kahf is the midpoint of the Mushaf, so the half is the one landmark that
/// can be reached from either end: juz 1–15 is as much half the Quran as juz
/// 15–30. The quarter and three-quarters have no equivalent landmark going
/// forward, which is why they are recognised only backwards.
///
/// A milestone needs an unbroken run, not a tally. Someone who has revised
/// Yaseen alone has not memorised a quarter of anything, and a celebration that
/// said so would be a lie the reciter would notice.
enum QuranMilestone {
  quarter(landmarkSurah: 36, arabicName: 'الربع'),
  half(landmarkSurah: 18, arabicName: 'النصف'),
  threeQuarters(landmarkSurah: 8, arabicName: 'ثلاثة أرباع'),
  whole(landmarkSurah: 1, arabicName: 'القرآن كاملاً');

  const QuranMilestone({
    required this.landmarkSurah,
    required this.arabicName,
  });

  /// The surah the run has to reach, counting down from An-Nas.
  final int landmarkSurah;

  final String arabicName;

  static const int firstSurah = 1;
  static const int lastSurah = 114;

  /// Whether the half may also be earned from the front of the Mushaf.
  ///
  /// Only [half]: Al-Kahf is the midpoint, so juz 1–15 is genuinely half. No
  /// other landmark has a forward counterpart.
  bool get isReachableFromStart => this == QuranMilestone.half;

  /// Whether [revised] earns this milestone.
  ///
  /// [revised] is every surah the reciter has been through at least once.
  bool isEarnedBy(Set<int> revised) {
    if (_coversRange(revised, landmarkSurah, lastSurah)) return true;
    if (isReachableFromStart &&
        _coversRange(revised, firstSurah, landmarkSurah)) {
      return true;
    }
    return false;
  }

  /// How far along this milestone's run the reciter is, 0 to 1.
  ///
  /// The better of the two directions where both count, so progress never
  /// appears to go backwards when someone switches which end they work from.
  double progressFor(Set<int> revised) {
    final backwards = _shareOfRange(revised, landmarkSurah, lastSurah);
    if (!isReachableFromStart) return backwards;
    final forwards = _shareOfRange(revised, firstSurah, landmarkSurah);
    return backwards > forwards ? backwards : forwards;
  }

  /// Every milestone [revised] earns, in order.
  static List<QuranMilestone> earnedBy(Set<int> revised) =>
      values.where((milestone) => milestone.isEarnedBy(revised)).toList();

  /// The next milestone still to reach, or null once all four are earned.
  static QuranMilestone? nextAfter(Set<int> revised) {
    for (final milestone in values) {
      if (!milestone.isEarnedBy(revised)) return milestone;
    }
    return null;
  }

  static bool _coversRange(Set<int> revised, int from, int to) {
    for (var surah = from; surah <= to; surah++) {
      if (!revised.contains(surah)) return false;
    }
    return true;
  }

  static double _shareOfRange(Set<int> revised, int from, int to) {
    final total = to - from + 1;
    if (total <= 0) return 0;
    var done = 0;
    for (var surah = from; surah <= to; surah++) {
      if (revised.contains(surah)) done++;
    }
    return done / total;
  }
}

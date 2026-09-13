import 'package:tilawa/domain/entities/reciter_profile.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';

/// Extent describes volume, not which surahs are memorised; it must not hide the catalogue.
class PlanPreferences {
  const PlanPreferences._();

  static int maxSurahs(MemorisationExtent? extent) => switch (extent) {
        MemorisationExtent.justStarting => 3,
        MemorisationExtent.upToFiveJuz => 10,
        MemorisationExtent.halfTheQuran => 20,
        MemorisationExtent.entireQuran || null => 40,
      };

  static void validateSize(Set<int> surahs, int maximum) {
    if (surahs.isEmpty || surahs.length > maximum) {
      throw StateError('Choose between 1 and $maximum surahs.');
    }
  }

  static Set<int> defaultSelection(
      ReciterProfile profile, List<SurahRevision> surahs) {
    if (profile.extent == null &&
        profile.difficulty != MemorisationDifficulty.longSurahs) {
      return {};
    }
    final candidates = [...surahs];
    candidates.sort((a, b) {
      // Prefer evidence of memorisation without guessing a starting juz from an extent answer.
      final assessed = (b.isAssessed ? 1 : 0).compareTo(a.isAssessed ? 1 : 0);
      if (assessed != 0) return assessed;
      if (profile.difficulty == MemorisationDifficulty.longSurahs ||
          profile.extent == MemorisationExtent.justStarting) {
        final length = a.ayahCount.compareTo(b.ayahCount);
        if (length != 0) return length;
      }
      return a.number.compareTo(b.number);
    });
    return candidates
        .take(maxSurahs(profile.extent))
        .map((s) => s.number)
        .toSet();
  }
}

import 'package:tilawa/domain/entities/mastery.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/services/database_service.dart';
import 'package:tilawa/data/quran/surah_catalog.dart';

/// One completed revision, kept as a dated record.
///
/// Mastery is a running number, so it can say how well a surah is known but
/// never *when* the work happened. The activity calendar, the streak and
/// today's progress all need that, which is why every review also leaves one
/// of these behind.
class RevisionEvent {
  const RevisionEvent({
    required this.id,
    required this.surahNumber,
    required this.occurredAt,
    required this.confidence,
    required this.durationSeconds,
    required this.xp,
    required this.quranReadCount,
  });

  final String id;
  final int surahNumber;
  final DateTime occurredAt;
  final int confidence;
  final int durationSeconds;
  final int xp;
  final int quranReadCount;

  Map<String, Object?> toRow() => {
        'id': id,
        'surahNumber': surahNumber,
        'occurredAt': occurredAt.toIso8601String(),
        'confidence': confidence,
        'durationSeconds': durationSeconds,
        'xp': xp,
        'quranReadCount': quranReadCount,
      };

  static RevisionEvent fromRow(Map<String, Object?> row) => RevisionEvent(
        id: row['id'] as String,
        surahNumber: (row['surahNumber'] as num).toInt(),
        occurredAt: DateTime.parse(row['occurredAt'] as String),
        confidence: (row['confidence'] as num).toInt(),
        durationSeconds: (row['durationSeconds'] as num).toInt(),
        xp: (row['xp'] as num).toInt(),
        quranReadCount: (row['quranReadCount'] as num).toInt(),
      );
}

/// The reciter's revision state on this device.
///
/// The 114 surahs come from the checked-in catalogue and are always all
/// present; what is stored is only the history laid over them, so a surah with
/// no history reads as never reviewed rather than as reviewed badly.
///
/// Everything is written through to [DatabaseService], so progress survives the
/// app being closed — it used to live in memory alone, which meant a reciter
/// lost every review the moment they left the app.
class LocalRevisionDatabase {
  LocalRevisionDatabase(
      {DatabaseService? database, this.personalFrequentlyRecited})
      : _database = database ?? DatabaseService();

  final DatabaseService _database;
  final Set<int>? personalFrequentlyRecited;

  List<SurahRevision>? _cache;

  Future<List<SurahRevision>> readAll() async {
    final cached = _cache;
    if (cached != null) return List.unmodifiable(cached);

    final states = {
      for (final row in await _database.revisionStates())
        (row['surahNumber'] as num).toInt(): row,
    };

    final surahs = [
      for (final surah in _catalogue())
        if (states.containsKey(surah.number))
          _applyState(surah, states[surah.number]!)
              .copyWith(personalFrequentlyRecited: personalFrequentlyRecited)
        else
          surah.copyWith(personalFrequentlyRecited: personalFrequentlyRecited),
    ];

    _cache = surahs;
    return List.unmodifiable(surahs);
  }

  Future<void> clearAll() async {
    await _database.clearProgress();
    _cache = null;
  }

  /// The surah most in need of attention.
  ///
  /// Surahs never reviewed are not "weak" — nothing is known about them — so
  /// they are only offered once everything with a history is in good shape.
  Future<SurahRevision> readWeakest() async {
    final surahs = await readAll();
    final reviewed = surahs.where((surah) => surah.isAssessed).toList();
    if (reviewed.isEmpty) return surahs.first;

    reviewed.sort((a, b) {
      final aScore = a.mastery - a.mistakeRate;
      final bScore = b.mastery - b.mistakeRate;
      return aScore.compareTo(bScore);
    });
    return reviewed.first;
  }

  Future<List<RevisionEvent>> eventsSince(DateTime from) async {
    final rows = await _database.revisionEventsSince(from);
    return rows.map(RevisionEvent.fromRow).toList();
  }

  Future<List<SurahRevision>> updateResult(
    int surahNumber,
    int confidence,
    int durationSeconds,
    String? section,
    int quranReadCount,
  ) async {
    final surahs = await readAll();
    final existing = surahs.firstWhere(
      (surah) => surah.number == surahNumber,
      orElse: () => SurahRevision.empty(surahNumber, '$surahNumber'),
    );

    // Same rules as the API, so an offline review and a synced one land on the
    // same number. See MasteryModel.
    final updated = existing.copyWith(
      masteryAtReview: MasteryModel.afterReview(
        currentMastery: existing.mastery,
        confidence: confidence,
        previousRevisionCount: existing.revisionCount,
      ),
      mistakeRate: MasteryModel.mistakeRateAfterReview(
        currentMistakeRate: existing.mistakeRate,
        confidence: confidence,
      ),
      revisionCount: existing.revisionCount + 1,
      consecutiveGoodReviews: MasteryModel.consecutiveGoodAfterReview(
        currentStreak: existing.consecutiveGoodReviews,
        confidence: confidence,
      ),
      lastReviewed: DateTime.now(),
      revisionIntensity:
          confidence > 8 ? RevisionIntensity.light : RevisionIntensity.deep,
      lastRevisionDurationSeconds: durationSeconds,
      lastRevisionSection: section,
      quranReadCount: existing.quranReadCount + quranReadCount,
    );

    await _database.upsertRevisionState(_toRow(updated));

    final now = DateTime.now();
    await _database.insertRevisionEvent(
      RevisionEvent(
        id: '${now.microsecondsSinceEpoch}-$surahNumber',
        surahNumber: surahNumber,
        occurredAt: now,
        confidence: confidence,
        durationSeconds: durationSeconds,
        // Worth more when it was recalled well, so a day of solid revision
        // reads differently from a day of struggling through.
        xp: 10 + confidence * 4,
        quranReadCount: quranReadCount,
      ).toRow(),
    );

    _cache = [
      for (final surah in surahs)
        if (surah.number == surahNumber) updated else surah,
    ];
    return List.unmodifiable(_cache!);
  }

  static Map<String, Object?> _toRow(SurahRevision surah) => {
        'surahNumber': surah.number,
        'masteryAtReview': surah.masteryAtReview,
        'mistakeRate': surah.mistakeRate,
        'revisionCount': surah.revisionCount,
        'consecutiveGoodReviews': surah.consecutiveGoodReviews,
        'lastReviewed': surah.lastReviewed?.toIso8601String(),
        'revisionIntensity': surah.revisionIntensity.name,
        'lastRevisionDurationSeconds': surah.lastRevisionDurationSeconds,
        'lastRevisionSection': surah.lastRevisionSection,
        'quranReadCount': surah.quranReadCount,
      };

  static SurahRevision _applyState(
    SurahRevision surah,
    Map<String, Object?> row,
  ) {
    final lastReviewed = row['lastReviewed'] as String?;
    return surah.copyWith(
      masteryAtReview: (row['masteryAtReview'] as num).toDouble(),
      mistakeRate: (row['mistakeRate'] as num).toDouble(),
      revisionCount: (row['revisionCount'] as num).toInt(),
      consecutiveGoodReviews: (row['consecutiveGoodReviews'] as num).toInt(),
      lastReviewed: lastReviewed == null ? null : DateTime.parse(lastReviewed),
      revisionIntensity: RevisionIntensity.values.firstWhere(
        (value) => value.name == row['revisionIntensity'],
        orElse: () => RevisionIntensity.light,
      ),
      lastRevisionDurationSeconds:
          (row['lastRevisionDurationSeconds'] as num).toInt(),
      lastRevisionSection: row['lastRevisionSection'] as String?,
      quranReadCount: (row['quranReadCount'] as num).toInt(),
    );
  }

  static List<SurahRevision> _catalogue() {
    return [
      for (final entry in SurahCatalog.surahs.entries)
        SurahRevision(
          number: entry.key,
          englishName: entry.key == 76
              ? 'Al-Insan'
              : entry.value['name_trans'] as String,
          arabicName:
              entry.key == 76 ? 'الإنسان' : entry.value['name_ar'] as String,
          juzNumber: (entry.value['juz_start'] as num).toInt(),
          ayahCount: entry.value['verses'] as int,
          masteryAtReview: 0.0,
          mistakeRate: 0.0,
          revisionCount: 0,
          consecutiveGoodReviews: 0,
          lastReviewed: null,
          revisionIntensity: RevisionIntensity.light,
          lastRevisionDurationSeconds: 0,
          lastRevisionSection: null,
          quranReadCount: 0,
        ),
    ];
  }
}

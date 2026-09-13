import 'package:tilawa/domain/entities/progress_summary.dart';
import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';

abstract class RevisionRepository {
  Future<List<SurahRevision>> fetchRevisionStatus();

  Future<SurahRevision> fetchWeakestSurah();

  Future<List<RevisionPlan>> fetchPlans();

  Future<RevisionPlan> createPlan({
    required String name,
    required Set<int> surahNumbers,
    required DateTime reminderTime,
    required bool isActive,
  });

  Future<RevisionPlan> updatePlan(RevisionPlan plan);

  Future<void> deletePlan(String id);

  Future<ProgressSummary> fetchProgressSummary();

  Future<List<SurahRevision>> recordSelfAssessment(int surahNumber, int confidence, int durationSeconds, String? section, int quranReadCount);
}

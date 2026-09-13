import 'package:tilawa/domain/entities/activity_day.dart';
import 'package:tilawa/domain/entities/progress_summary.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';
import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/domain/entities/plan_preferences.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/repositories/revision_repository.dart';
import 'package:tilawa/data/datasources/api_client.dart';

class RemoteRevisionRepository implements RevisionRepository {
  const RemoteRevisionRepository(this._apiClient, this._fallback,
      {this.personalFrequentlyRecited, this.maxPlanSurahs});

  final TilawaApiClient _apiClient;
  final RevisionRepository _fallback;
  final Set<int>? personalFrequentlyRecited;
  final int? maxPlanSurahs;

  @override
  Future<List<SurahRevision>> fetchRevisionStatus() async {
    try {
      return (await _apiClient.getSurahs()).map(_surahFromJson).toList();
    } catch (_) {
      return _fallback.fetchRevisionStatus();
    }
  }

  @override
  Future<SurahRevision> fetchWeakestSurah() async {
    try {
      return _surahFromJson(await _apiClient.getPrioritySurah());
    } catch (_) {
      return _fallback.fetchWeakestSurah();
    }
  }

  @override
  Future<List<RevisionPlan>> fetchPlans() async {
    try {
      return (await _apiClient.getPlans()).map(_planFromJson).toList();
    } catch (_) {
      return _fallback.fetchPlans();
    }
  }

  @override
  Future<RevisionPlan> createPlan({
    required String name,
    required Set<int> surahNumbers,
    required DateTime reminderTime,
    required bool isActive,
  }) async {
    PlanPreferences.validateSize(
        surahNumbers, maxPlanSurahs ?? PlanPreferences.maxSurahs(null));
    try {
      return _planFromJson(await _apiClient.createPlan({
        'name': name,
        'surahNumbers': surahNumbers.toList()..sort(),
        'reminderTime': reminderTime.toUtc().toIso8601String(),
        'isActive': isActive,
      }));
    } catch (_) {
      return _fallback.createPlan(
        name: name,
        surahNumbers: surahNumbers,
        reminderTime: reminderTime,
        isActive: isActive,
      );
    }
  }

  @override
  Future<RevisionPlan> updatePlan(RevisionPlan plan) async {
    PlanPreferences.validateSize(
        plan.surahNumbers, maxPlanSurahs ?? PlanPreferences.maxSurahs(null));
    try {
      return _planFromJson(await _apiClient.updatePlan(plan.id, {
        'name': plan.name,
        'surahNumbers': plan.surahNumbers.toList()..sort(),
        'reminderTime': plan.reminderTime.toUtc().toIso8601String(),
        'isActive': plan.isActive,
      }));
    } catch (_) {
      return _fallback.updatePlan(plan);
    }
  }

  @override
  Future<void> deletePlan(String id) async {
    try {
      await _apiClient.deletePlan(id);
    } catch (_) {
      await _fallback.deletePlan(id);
    }
  }

  @override
  Future<ProgressSummary> fetchProgressSummary() async {
    try {
      return _progressFromJson(await _apiClient.getProgress());
    } catch (_) {
      return _fallback.fetchProgressSummary();
    }
  }

  @override
  Future<List<SurahRevision>> recordSelfAssessment(
      int surahNumber,
      int confidence,
      int durationSeconds,
      String? section,
      int quranReadCount) async {
    try {
      final jsonList = await _apiClient.recordSelfAssessment(
        surahNumber: surahNumber,
        confidence: confidence,
        durationSeconds: durationSeconds,
        section: section,
        quranReadCount: quranReadCount,
      );
      return jsonList.map(_surahFromJson).toList();
    } catch (_) {
      return _fallback.recordSelfAssessment(
          surahNumber, confidence, durationSeconds, section, quranReadCount);
    }
  }

  /// The juz a surah starts in.
  ///
  /// Newer API builds send it as a number. Older ones send only `juzLabel`,
  /// an English string like "Juz 30", so the digits are read back out of it
  /// rather than the English being shown to an Arabic reader.
  static int _juzNumber(Map<String, dynamic> json) {
    final number = json['juzNumber'];
    if (number is num) return number.toInt();
    final label = json['juzLabel'] as String? ?? '';
    return int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '') ?? 1;
  }

  SurahRevision _surahFromJson(Map<String, dynamic> json) {
    return SurahRevision(
      personalFrequentlyRecited: personalFrequentlyRecited,
      number: json['number'] as int,
      englishName: json['englishName'] as String,
      arabicName: json['arabicName'] as String,
      juzNumber: _juzNumber(json),
      ayahCount: json['ayahCount'] as int,
      // The API sends mastery as it stood at the last review; both sides then
      // apply the same decay, so the wire carries a stable fact rather than a
      // value that is already stale by the time it arrives.
      masteryAtReview: (json['masteryAtReview'] as num).toDouble(),
      mistakeRate: (json['mistakeRate'] as num).toDouble(),
      revisionCount: json['revisionCount'] as int,
      consecutiveGoodReviews: json['consecutiveGoodReviews'] as int? ?? 0,
      lastReviewed: json['lastReviewed'] == null
          ? null
          : DateTime.parse(json['lastReviewed'] as String).toLocal(),
      revisionIntensity: RevisionIntensity.values.firstWhere(
          (e) =>
              e.name.toLowerCase() ==
              (json['revisionIntensity'] as String).toLowerCase(),
          orElse: () => RevisionIntensity.light),
      lastRevisionDurationSeconds:
          json['lastRevisionDurationSeconds'] as int? ?? 0,
      lastRevisionSection: json['lastRevisionSection'] as String?,
      quranReadCount: json['quranReadCount'] as int? ?? 0,
    );
  }

  static RevisionPlan _planFromJson(Map<String, dynamic> json) {
    return RevisionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      surahNumbers: (json['surahNumbers'] as List<dynamic>).cast<int>().toSet(),
      reminderTime: DateTime.parse(json['reminderTime'] as String).toLocal(),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  static ProgressSummary _progressFromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      totalXp: json['totalXp'] as int,
      streak: json['streak'] as int,
      score: json['score'] as int,
      plannedSurahs: json['plannedSurahs'] as int,
      reviewedToday: json['reviewedToday'] as int,
      calendar: (json['calendar'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_activityFromJson)
          .toList(),
      masteryBuckets: (json['masteryBuckets'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_bucketFromJson)
          .toList(),
    );
  }

  static ActivityDay _activityFromJson(Map<String, dynamic> json) {
    return ActivityDay(
      date: DateTime.parse(json['date'] as String),
      revisionCount: json['revisionCount'] as int,
      xp: json['xp'] as int,
      score: json['score'] as int? ?? 0,
      surahNumbers: (json['surahNumbers'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toSet() ??
          {},
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      quranReadCount: json['quranReadCount'] as int? ?? 0,
    );
  }

  static MasteryBucket _bucketFromJson(Map<String, dynamic> json) {
    return MasteryBucket(
      label: json['label'] as String,
      count: json['count'] as int,
      ratio: (json['ratio'] as num).toDouble(),
    );
  }
}

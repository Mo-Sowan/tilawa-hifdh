import 'dart:convert';

import 'package:tilawa/domain/entities/activity_day.dart';
import 'package:tilawa/domain/entities/progress_summary.dart';
import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/domain/entities/plan_preferences.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/repositories/revision_repository.dart';
import 'package:tilawa/services/database_service.dart';
import 'package:tilawa/data/datasources/local_revision_database.dart';

/// The on-device implementation of the repository.
///
/// This is not a stand-in for the API: it is what the app runs on when there
/// is no account or no network, which for an offline-first hifdh tracker is
/// most of the time. Plans and the progress summary are therefore built from
/// stored facts, not from placeholder zeroes.
class LocalRevisionRepository implements RevisionRepository {
  LocalRevisionRepository(this._database,
      {DatabaseService? store, int? maxPlanSurahs})
      : _maxPlanSurahs = maxPlanSurahs ?? PlanPreferences.maxSurahs(null),
        _store = store ?? DatabaseService();

  /// How far back the activity calendar reaches.
  static const int calendarDays = 28;

  final LocalRevisionDatabase _database;
  final DatabaseService _store;
  final int _maxPlanSurahs;

  @override
  Future<List<SurahRevision>> fetchRevisionStatus() => _database.readAll();

  @override
  Future<SurahRevision> fetchWeakestSurah() => _database.readWeakest();

  @override
  Future<List<RevisionPlan>> fetchPlans() async {
    final rows = await _store.plans();
    return rows.map(_planFromRow).toList();
  }

  @override
  Future<RevisionPlan> createPlan({
    required String name,
    required Set<int> surahNumbers,
    required DateTime reminderTime,
    required bool isActive,
  }) async {
    PlanPreferences.validateSize(surahNumbers, _maxPlanSurahs);
    final now = DateTime.now();
    final plan = RevisionPlan(
      id: 'local-${now.microsecondsSinceEpoch}',
      name: name.trim(),
      surahNumbers: surahNumbers,
      reminderTime: reminderTime,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
    await _store.upsertPlan(_planToRow(plan));
    return plan;
  }

  @override
  Future<RevisionPlan> updatePlan(RevisionPlan plan) async {
    PlanPreferences.validateSize(plan.surahNumbers, _maxPlanSurahs);
    final existing = await fetchPlans();
    if (!existing.any((item) => item.id == plan.id)) {
      throw StateError('Plan not found.');
    }
    final updated = plan.copyWith(updatedAt: DateTime.now());
    await _store.upsertPlan(_planToRow(updated));
    return updated;
  }

  @override
  Future<void> deletePlan(String id) => _store.deletePlan(id);

  @override
  Future<ProgressSummary> fetchProgressSummary() async {
    final surahs = await fetchRevisionStatus();
    final plans = await fetchPlans();

    final today = _dayOf(DateTime.now());
    final firstDay = today.subtract(const Duration(days: calendarDays - 1));
    final events = await _database.eventsSince(firstDay);

    // Fold the events onto the days they happened, so an empty day stays empty
    // and a busy one carries everything that went into it.
    final byDay = <DateTime, ActivityDay>{};
    for (final event in events) {
      final day = _dayOf(event.occurredAt);
      final current = byDay[day] ?? ActivityDay.empty(day);
      byDay[day] = current.copyWith(
        revisionCount: current.revisionCount + 1,
        xp: current.xp + event.xp,
        score: current.score + event.confidence,
        surahNumbers: {...current.surahNumbers, event.surahNumber},
        durationSeconds: current.durationSeconds + event.durationSeconds,
        quranReadCount: current.quranReadCount + event.quranReadCount,
      );
    }

    final calendar = [
      for (var i = 0; i < calendarDays; i++)
        () {
          final day = firstDay.add(Duration(days: i));
          return byDay[day] ?? ActivityDay.empty(day);
        }(),
    ];

    MasteryBucket bucket(String label, bool Function(SurahRevision) test) {
      // Only surahs with a history are placed in a band. Counting the other
      // hundred-odd as "Weak" would say the reciter has forgotten what they
      // never claimed to have memorised.
      final assessed = surahs.where((surah) => surah.isAssessed).toList();
      final count = assessed.where(test).length;
      return MasteryBucket(
        label: label,
        count: count,
        ratio: assessed.isEmpty ? 0 : count / assessed.length,
      );
    }

    final todayRow = byDay[today];

    return ProgressSummary(
      totalXp: surahs.fold<int>(0, (sum, surah) => sum + surah.xpValue),
      streak: _streak(byDay, today),
      score: todayRow?.score ?? 0,
      plannedSurahs: plans
          .where((p) => p.isActive)
          .expand((p) => p.surahNumbers)
          .toSet()
          .length,
      reviewedToday: todayRow?.revisionCount ?? 0,
      calendar: calendar,
      masteryBuckets: [
        bucket('Excellent', (s) => s.mastery >= .8),
        bucket('Good', (s) => s.mastery >= .6 && s.mastery < .8),
        bucket('Shaky', (s) => s.mastery >= .4 && s.mastery < .6),
        bucket('Weak', (s) => s.mastery < .4),
      ],
    );
  }

  @override
  Future<List<SurahRevision>> recordSelfAssessment(
    int surahNumber,
    int confidence,
    int durationSeconds,
    String? section,
    int quranReadCount,
  ) {
    return _database.updateResult(
      surahNumber,
      confidence,
      durationSeconds,
      section,
      quranReadCount,
    );
  }

  /// Consecutive days of revision ending today.
  ///
  /// A day with nothing on it ends the streak — except today itself, which is
  /// still in progress: a streak built yesterday should not read as broken
  /// simply because this morning's revision has not happened yet.
  static int _streak(Map<DateTime, ActivityDay> byDay, DateTime today) {
    var streak = 0;
    var day = today;
    if (!(byDay[today]?.hasActivity ?? false)) {
      day = today.subtract(const Duration(days: 1));
    }
    while (byDay[day]?.hasActivity ?? false) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static Map<String, Object?> _planToRow(RevisionPlan plan) => {
        'id': plan.id,
        'name': plan.name,
        'surahNumbers': jsonEncode(plan.surahNumbers.toList()),
        'reminderTime': plan.reminderTime.toIso8601String(),
        'isActive': plan.isActive ? 1 : 0,
        'createdAt': plan.createdAt.toIso8601String(),
        'updatedAt': plan.updatedAt.toIso8601String(),
      };

  static RevisionPlan _planFromRow(Map<String, Object?> row) => RevisionPlan(
        id: row['id'] as String,
        name: row['name'] as String,
        surahNumbers: {
          for (final number
              in jsonDecode(row['surahNumbers'] as String) as List)
            (number as num).toInt(),
        },
        reminderTime: DateTime.parse(row['reminderTime'] as String),
        isActive: (row['isActive'] as num).toInt() == 1,
        createdAt: DateTime.parse(row['createdAt'] as String),
        updatedAt: DateTime.parse(row['updatedAt'] as String),
      );
}

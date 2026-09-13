import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/data/datasources/local_revision_database.dart';
import 'package:tilawa/data/repositories/local_revision_repository.dart';
import 'package:tilawa/domain/entities/mastery.dart';
import 'package:tilawa/services/database_service.dart';
import 'package:tilawa/services/local_store.dart';

class MemoryRevisionStore implements LocalStore {
  final states = <int, Map<String, Object?>>{};
  final savedPlans = <Map<String, Object?>>[];
  @override
  Future<List<Map<String, Object?>>> revisionStates() async =>
      states.values.toList();
  @override
  Future<void> upsertRevisionState(Map<String, Object?> state) async {
    states[state['surahNumber'] as int] = state;
  }

  @override
  Future<void> insertRevisionEvent(Map<String, Object?> event) async {}
  @override
  Future<void> upsertPlan(Map<String, Object?> plan) async {
    savedPlans.add(plan);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('local reviews use personal decay before writing the next mastery',
      () async {
    final store = MemoryRevisionStore();
    final database = DatabaseService.withStore(store);
    final local = LocalRevisionDatabase(
        database: database, personalFrequentlyRecited: {67});
    await local.updateResult(18, 8, 60, null, 0);
    store.states[18]!['lastReviewed'] =
        DateTime.now().subtract(const Duration(days: 5)).toIso8601String();
    final restarted = LocalRevisionDatabase(
        database: database, personalFrequentlyRecited: {67});
    final before =
        (await restarted.readAll()).singleWhere((s) => s.number == 18);
    expect(before.decayCoefficient, 1);
    final expected = MasteryModel.afterReview(
        currentMastery: before.mastery,
        confidence: 8,
        previousRevisionCount: 1);
    final result = await restarted.updateResult(18, 8, 60, null, 0);
    expect(result.singleWhere((s) => s.number == 18).masteryAtReview,
        closeTo(expected, .0001));
    expect(store.states[18]!['masteryAtReview'], closeTo(expected, .0001));
  });
  test('local plan creation enforces profile size before writing', () async {
    final store = MemoryRevisionStore();
    final database = DatabaseService.withStore(store);
    final repository = LocalRevisionRepository(
        LocalRevisionDatabase(database: database),
        store: database,
        maxPlanSurahs: 3);
    await expectLater(
        repository.createPlan(
            name: 'Large',
            surahNumbers: {1, 2, 3, 4},
            reminderTime: DateTime.now(),
            isActive: true),
        throwsStateError);
    expect(store.savedPlans, isEmpty);
    await repository.createPlan(
        name: 'Small',
        surahNumbers: {1, 2, 3},
        reminderTime: DateTime.now(),
        isActive: true);
    expect(store.savedPlans, hasLength(1));
  });
}

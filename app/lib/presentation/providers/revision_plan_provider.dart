import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';

class RevisionPlanController
    extends AutoDisposeAsyncNotifier<List<RevisionPlan>> {
  @override
  Future<List<RevisionPlan>> build() {
    return ref.watch(revisionRepositoryProvider).fetchPlans();
  }

  Future<void> createPlan({
    required String name,
    required Set<int> surahNumbers,
    required DateTime reminderTime,
    bool isActive = true,
  }) async {
    if (surahNumbers.isEmpty) {
      throw StateError('Choose at least one Surah.');
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.watch(revisionRepositoryProvider).createPlan(
            name: name,
            surahNumbers: surahNumbers,
            reminderTime: reminderTime,
            isActive: isActive,
          );
      ref.invalidate(progressSummaryProvider);
      return ref.watch(revisionRepositoryProvider).fetchPlans();
    });
  }

  Future<void> updatePlan(RevisionPlan plan) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.watch(revisionRepositoryProvider).updatePlan(plan);
      ref.invalidate(progressSummaryProvider);
      return ref.watch(revisionRepositoryProvider).fetchPlans();
    });
  }

  Future<void> deletePlan(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.watch(revisionRepositoryProvider).deletePlan(id);
      ref.invalidate(progressSummaryProvider);
      return ref.watch(revisionRepositoryProvider).fetchPlans();
    });
  }
}

class TimeParts {
  const TimeParts(this.hour, this.minute);

  final int hour;
  final int minute;
}

final revisionPlansProvider = AutoDisposeAsyncNotifierProvider<
    RevisionPlanController, List<RevisionPlan>>(
  RevisionPlanController.new,
);

final activeRevisionPlanProvider = Provider<RevisionPlan?>((ref) {
  final plans = ref.watch(revisionPlansProvider).valueOrNull ?? const [];
  return plans.isEmpty ? null : plans.first;
});

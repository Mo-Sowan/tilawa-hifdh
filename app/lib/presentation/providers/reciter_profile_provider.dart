import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/data/repositories/reciter_profile_repository.dart';
import 'package:tilawa/domain/entities/reciter_profile.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';

final reciterProfileRepositoryProvider =
    Provider<ReciterProfileRepository>((ref) {
  return ReciterProfileRepository(api: ref.watch(apiClientProvider));
});

/// The reciter's answers, loaded once and updated as they are given.
///
/// Held as [AsyncValue] because the app must not decide whether to show the
/// questionnaire before it knows whether there is already an answer — doing
/// that would ask a returning reciter the same four questions again.
class ReciterProfileNotifier extends StateNotifier<AsyncValue<ReciterProfile>> {
  ReciterProfileNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    _load();
  }

  final ReciterProfileRepository _repository;

  Future<void> _load() async {
    state = await AsyncValue.guard(_repository.load);
  }

  /// Records an answer as it is given, so a flow abandoned halfway is not lost.
  Future<void> update(
    ReciterProfile Function(ReciterProfile current) change,
  ) async {
    final current = state.valueOrNull ?? const ReciterProfile();
    final next = change(current);
    state = AsyncValue.data(next);
    await _repository.save(next);
  }

  /// Marks the questionnaire finished, which is what stops it being shown again.
  Future<void> complete() async {
    await update((current) => current.copyWith(completedAt: DateTime.now()));
  }
}

final reciterProfileProvider = StateNotifierProvider<ReciterProfileNotifier,
    AsyncValue<ReciterProfile>>((ref) {
  return ReciterProfileNotifier(ref.watch(reciterProfileRepositoryProvider));
});

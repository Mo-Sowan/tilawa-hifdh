import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/data/datasources/api_client.dart';
import 'package:tilawa/data/datasources/local_revision_database.dart';
import 'package:tilawa/data/repositories/local_revision_repository.dart';
import 'package:tilawa/data/repositories/remote_revision_repository.dart';
import 'package:tilawa/domain/entities/progress_summary.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/entities/plan_preferences.dart';
import 'package:tilawa/domain/repositories/revision_repository.dart';
import 'package:tilawa/domain/usecases/get_revision_overview.dart';
import 'package:tilawa/domain/usecases/get_weakest_surah.dart';
import 'package:tilawa/domain/usecases/submit_self_assessment.dart';
import 'package:tilawa/services/database_service.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/auth_provider.dart';
import 'package:tilawa/presentation/providers/reciter_profile_provider.dart';

final localRevisionDatabaseProvider = Provider<LocalRevisionDatabase>((ref) {
  return LocalRevisionDatabase(
      personalFrequentlyRecited: ref
          .watch(reciterProfileProvider)
          .valueOrNull
          ?.personalRecitationHabits);
});

final apiClientProvider = Provider<TilawaApiClient>((ref) {
  final client = TilawaApiClient(
    baseUrl: ref.watch(appSettingsProvider.select((s) => s.serverUrl)),
    tokens: ref.watch(authTokenSourceProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final localRevisionRepositoryProvider = Provider<RevisionRepository>((ref) {
  return LocalRevisionRepository(ref.watch(localRevisionDatabaseProvider),
      maxPlanSurahs: PlanPreferences.maxSurahs(
          ref.watch(reciterProfileProvider).valueOrNull?.extent));
});

final revisionRepositoryProvider = Provider<RevisionRepository>((ref) {
  return RemoteRevisionRepository(
    ref.watch(apiClientProvider),
    ref.watch(localRevisionRepositoryProvider),
    personalFrequentlyRecited:
        ref.watch(reciterProfileProvider).valueOrNull?.personalRecitationHabits,
    maxPlanSurahs: PlanPreferences.maxSurahs(
        ref.watch(reciterProfileProvider).valueOrNull?.extent),
  );
});

final getRevisionOverviewProvider = Provider<GetRevisionOverview>((ref) {
  return GetRevisionOverview(ref.watch(revisionRepositoryProvider));
});

final getWeakestSurahProvider = Provider<GetWeakestSurah>((ref) {
  return GetWeakestSurah(ref.watch(revisionRepositoryProvider));
});

final submitSelfAssessmentProvider = Provider<SubmitSelfAssessment>((ref) {
  return SubmitSelfAssessment(ref.watch(revisionRepositoryProvider));
});

final revisionOverviewProvider =
    FutureProvider<List<SurahRevision>>((ref) async {
  final surahs = await ref.watch(getRevisionOverviewProvider).call();
  return [...surahs]..sort((a, b) => a.number.compareTo(b.number));
});

final weakestSurahProvider = FutureProvider<SurahRevision>((ref) {
  return ref.watch(getWeakestSurahProvider).call();
});

final totalXpProvider = Provider<int>((ref) {
  final overview = ref.watch(revisionOverviewProvider).valueOrNull ??
      const <SurahRevision>[];
  return overview.fold<int>(0, (sum, surah) => sum + surah.xpValue);
});

final streakProvider = Provider<int>((ref) {
  final summary = ref.watch(progressSummaryProvider).valueOrNull;
  return summary?.streak ?? 0;
});

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) {
  return ref.watch(revisionRepositoryProvider).fetchProgressSummary();
});

final apiHealthProvider = FutureProvider<bool>((ref) {
  return ref.watch(apiClientProvider).healthCheck();
});

/// Remembers the confidence the user gave each surah last time, so the
/// assessment screen can tell them whether they improved.
class LastConfidenceNotifier extends StateNotifier<Map<int, int>> {
  LastConfidenceNotifier(this._database) : super(const {}) {
    unawaited(_load());
  }

  static const String _settingKey = 'lastConfidence';

  final DatabaseService _database;

  Future<void> _load() async {
    try {
      final raw = await _database.getSetting(_settingKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final entry in decoded.entries)
          int.parse(entry.key): (entry.value as num).toInt(),
      };
    } catch (error) {
      debugPrint('Could not read last confidence values: $error');
    }
  }

  Future<void> setConfidence(int surahNumber, int confidence) async {
    state = {...state, surahNumber: confidence};
    try {
      await _database.saveSetting(
        _settingKey,
        jsonEncode(state.map((key, value) => MapEntry('$key', value))),
      );
    } catch (error) {
      debugPrint('Could not persist last confidence values: $error');
    }
  }
}

final lastConfidenceProvider =
    StateNotifierProvider<LastConfidenceNotifier, Map<int, int>>((ref) {
  return LastConfidenceNotifier(DatabaseService());
});

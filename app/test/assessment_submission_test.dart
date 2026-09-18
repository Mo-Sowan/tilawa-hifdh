import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/domain/entities/progress_summary.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/repositories/revision_repository.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/providers/revision_session_provider.dart';
import 'package:tilawa/presentation/features/surah_detail/surah_detail_view.dart';
import 'package:tilawa/services/database_service.dart';

class DelayedRepository implements RevisionRepository {
  int calls = 0;
  Completer<List<SurahRevision>> reply = Completer();
  @override
  Future<List<SurahRevision>> recordSelfAssessment(
      int number, int confidence, int seconds, String? section, int reads) {
    calls++;
    return reply.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemorySettings implements DatabaseService {
  @override
  Future<String?> getSetting(String key) async => null;
  @override
  Future<void> saveSetting(String key, String value) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<ProviderContainer> open(
      WidgetTester tester, DelayedRepository repository) async {
    final surah = SurahRevision.empty(36, 'Yaseen');
    final container = ProviderContainer(overrides: [
      appStringsProvider
          .overrideWithValue(const AppStrings(AppLanguage.english)),
      revisionRepositoryProvider.overrideWithValue(repository),
      activeRevisionPlanProvider.overrideWithValue(null),
      revisionOverviewProvider.overrideWith((ref) async => [surah]),
      weakestSurahProvider.overrideWith((ref) async => surah),
      progressSummaryProvider.overrideWith((ref) async => const ProgressSummary(
          totalXp: 0,
          streak: 0,
          score: 0,
          plannedSurahs: 0,
          reviewedToday: 0,
          calendar: [],
          masteryBuckets: [])),
      lastConfidenceProvider
          .overrideWith((ref) => LastConfidenceNotifier(MemorySettings())),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => SurahDetailView(surah: surah))),
                    child: const Text('Open assessment'),
                  ))),
        )));
    await tester.tap(find.text('Open assessment'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('save-assessment')), 250,
        scrollable: find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)
            .first);
    return container;
  }

  testWidgets(
      'two callbacks before a rebuild produce one write and one history entry',
      (tester) async {
    final repository = DelayedRepository();
    final container = await open(tester, repository);
    final callback = tester
        .widget<FilledButton>(find.byKey(const Key('save-assessment')))
        .onPressed!;
    callback();
    callback();
    expect(repository.calls, 1);
    expect(container.read(revisionSessionsProvider), isEmpty);
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-assessment')))
            .onPressed,
        isNull);
    expect(find.text('Saving…'), findsOneWidget);
    repository.reply.complete([]);
    await tester.pumpAndSettle();
    expect(container.read(revisionSessionsProvider), hasLength(1));
    expect(repository.calls, 1);
    expect(find.byType(SurahDetailView), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed saves add no history and allow a deliberate retry',
      (tester) async {
    final repository = DelayedRepository();
    final container = await open(tester, repository);
    await tester.tap(find.byKey(const Key('save-assessment')));
    repository.reply.completeError(StateError('Disk unavailable'));
    await tester.pumpAndSettle();
    expect(container.read(revisionSessionsProvider), isEmpty);
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-assessment')))
            .onPressed,
        isNotNull);
    repository.reply = Completer();
    await tester.tap(find.byKey(const Key('save-assessment')));
    repository.reply.complete([]);
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(container.read(revisionSessionsProvider), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}

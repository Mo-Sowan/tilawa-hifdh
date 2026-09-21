import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/presentation/features/plan/widgets/plan_composer.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/widgets/mushaf_page_image.dart';
import 'package:tilawa/features/recitation/data/model_manager.dart';
import 'package:tilawa/features/recitation/data/model_manager_web.dart';
import 'package:tilawa/features/recitation/presentation/recitation_providers.dart';
import 'package:tilawa/features/recitation/presentation/widgets/recitation_status_bar.dart';
import 'package:tilawa/features/recitation/service/recitation_engine.dart';

void main() {
  test('native development API addresses do not delay Mushaf scans', () {
    expect(
      MushafPageImage.preferredUrl('http://10.0.2.2:5190', 2),
      MushafPageImage.archiveUrl(2),
    );
    expect(
      MushafPageImage.preferredUrl('https://api.tilawa.example', 2),
      'https://api.tilawa.example/api/v1/mushaf/page/2',
    );
  });

  test('web model manager opens the bundled model asset', () async {
    final manager = BundledModelManager();
    addTearDown(manager.dispose);

    expect(await manager.isModelCached(), isTrue);
    expect(
      await manager.ensureModel(expectedSha256: 'checked-by-build-manifest'),
      ModelManager.bundledAsset,
    );
    expect(manager.currentStatus.stage, ModelStage.ready);

    await manager.clearCache();
    expect(manager.currentStatus.stage, ModelStage.idle);
  });

  testWidgets('plan details are step one and creation follows selection',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStringsProvider.overrideWithValue(
            const AppStrings(AppLanguage.english),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlanComposer(
              nameController: controller,
              selectedSurahs: const {1, 2},
              reminderTime: const TimeOfDay(hour: 19, minute: 0),
              onReminderChanged: (_) {},
              onShowSelected: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Name and reminder'), findsOneWidget);
    expect(find.text('2 Surahs selected'), findsOneWidget);
    expect(find.text('Create plan'), findsNothing);
  });

  testWidgets('unsupported AI status explains the supplied limitation',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecitationStatusBar(
            status: EngineStatus(
              state: EngineState.unsupported,
              message: 'Recognition is unavailable on this device.',
            ),
            session: RecitationSessionState(),
            isArabic: false,
          ),
        ),
      ),
    );

    expect(
      find.text('Recognition is unavailable on this device.'),
      findsOneWidget,
    );
  });
}

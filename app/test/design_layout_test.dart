import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/utilities/utilities_view.dart';
import 'package:tilawa/presentation/widgets/settings_tile.dart';

void main() {
  for (final width in [320.0, 1024.0]) {
    testWidgets('utilities adapt at $width with Arabic and enlarged text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            appStringsProvider
                .overrideWithValue(const AppStrings(AppLanguage.arabic)),
          ],
          child: MaterialApp(
            theme: AppTheme.buildTheme(AppTheme.palettes[1]),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: Directionality(
                    textDirection: TextDirection.rtl, child: child!)),
            home: const UtilitiesView(),
          )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('عداد التسبيح'), findsOneWidget);
    });
  }

  testWidgets('settings control moves below its label on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.buildTheme(AppTheme.palettes[1]),
        home: Scaffold(
          body: Padding(
              padding: const EdgeInsets.all(20),
              child: SettingsTile(
                icon: Icons.color_lens_outlined,
                title: 'Appearance',
                subtitle: 'Choose your reading theme',
                trailing: DropdownButton<int>(
                    value: 1,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Emerald Day'))
                    ],
                    onChanged: (_) {}),
              )),
        )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        tester.getTopLeft(find.byType(DropdownButton<int>)).dy,
        greaterThan(
            tester.getBottomLeft(find.text('Choose your reading theme')).dy));
  });
}

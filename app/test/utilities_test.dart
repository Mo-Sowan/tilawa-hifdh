import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/views/qibla_view.dart';
import 'package:tilawa/presentation/views/tasbeeh_view.dart';
import 'package:tilawa/presentation/views/utilities_view.dart';
import 'package:tilawa/services/qibla_service.dart';

Widget app(Widget child, {QiblaService? service}) => ProviderScope(
      overrides: [
        appStringsProvider
            .overrideWithValue(const AppStrings(AppLanguage.english)),
        if (service != null) qiblaServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(home: child),
    );

class FakeQibla extends QiblaService {
  FakeQibla({this.failure});
  final QiblaFailure? failure;
  final controller = StreamController<double?>.broadcast();
  @override
  Future<double> bearing() async {
    if (failure != null) throw failure!;
    return 136;
  }

  @override
  Stream<double?> get headings => controller.stream;
}

void main() {
  testWidgets('utilities opens tasbeeh; target taps, haptics and reset work',
      (tester) async {
    final feedback = <Object?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') feedback.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(app(const UtilitiesView()));
    await tester.tap(find.text('Digital tasbeeh'));
    await tester.pumpAndSettle();
    expect(find.byType(TasbeehView), findsOneWidget);
    feedback.clear();
    for (var i = 0; i < 33; i++) {
      await tester.tap(find.byKey(const Key('tasbeeh-tap')));
      await tester.pump();
    }
    expect(find.text('33 / 33'), findsOneWidget);
    expect(find.text('Target reached'), findsOneWidget);
    expect(
        feedback.where((value) => value == 'HapticFeedbackType.selectionClick'),
        hasLength(32));
    expect(feedback.where((value) => value == 'HapticFeedbackType.heavyImpact'),
        hasLength(1));
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('0 / 33'), findsOneWidget);
  });

  testWidgets('changing tasbeeh target starts a new round', (tester) async {
    await tester.pumpWidget(app(const TasbeehView()));
    await tester.tap(find.byKey(const Key('tasbeeh-tap')));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('99').last);
    await tester.pumpAndSettle();
    expect(find.text('0 / 99'), findsOneWidget);
  });

  for (final entry in {
    QiblaFailure.servicesOff: 'Location services are off.',
    QiblaFailure.denied: 'Location permission was denied.',
    QiblaFailure.deniedForever: 'Allow location access in app settings.',
  }.entries) {
    testWidgets('Qibla explains ${entry.key.name}', (tester) async {
      final service = FakeQibla(failure: entry.key);
      addTearDown(service.controller.close);
      await tester.pumpWidget(app(const QiblaView(), service: service));
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  }

  testWidgets('Qibla accepts headings and cancels sensor subscription on exit',
      (tester) async {
    final service = FakeQibla();
    await tester.pumpWidget(app(const UtilitiesView(), service: service));
    await tester.tap(find.text('Qibla compass'));
    await tester.pumpAndSettle();
    service.controller.add(-1);
    await tester.pumpAndSettle();
    expect(find.text('136.0°'), findsOneWidget);
    expect(find.byType(AnimatedRotation), findsOneWidget);
    service.controller.add(1);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.controller.hasListener, isFalse);
    await service.controller.close();
  });

  testWidgets(
      'missing sensor keeps numeric bearing and gives explicit fallback',
      (tester) async {
    final service = FakeQibla();
    await tester.pumpWidget(app(const QiblaView(), service: service));
    await tester.pumpAndSettle();
    service.controller.add(null);
    await tester.pumpAndSettle();
    expect(find.textContaining('Compass unavailable'), findsOneWidget);
    expect(find.byType(AnimatedRotation), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await service.controller.close();
  });
}

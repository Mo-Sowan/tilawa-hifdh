import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/presentation/views/root_navigator.dart';
import 'package:tilawa/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  runApp(const ProviderScope(child: TilawaApp()));
}

class TilawaApp extends ConsumerStatefulWidget {
  const TilawaApp({super.key});

  @override
  ConsumerState<TilawaApp> createState() => _TilawaAppState();
}

class _TilawaAppState extends ConsumerState<TilawaApp> {
  @override
  void initState() {
    super.initState();
    // Warm the Quran text index: every reader surface needs it, and loading it
    // now keeps the first navigation from stalling.
    ref.read(quranTextIndexProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final strings = ref.watch(appStringsProvider);

    return MaterialApp(
      title: strings.appName,
      scrollBehavior: const AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(AppTheme.palettes[settings.themeIndex]),
      locale: settings.language.locale,
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: settings.language.direction,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const RootNavigator(),
    );
  }
}

/// Allows drag-scrolling with a mouse and trackpad, not just touch — the app
/// also ships on desktop.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

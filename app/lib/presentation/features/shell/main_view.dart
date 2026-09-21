import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/daily_progress_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/widgets/celebration/celebration_sheet.dart';
import 'package:tilawa/presentation/widgets/celebration/celebration_tier.dart';
import 'package:tilawa/services/notification_service.dart';
import 'package:tilawa/presentation/features/home/home_view.dart';
import 'package:tilawa/presentation/features/plan/plan_view.dart';
import 'package:tilawa/presentation/features/progress/progress_view.dart';
import 'package:tilawa/presentation/features/settings/settings_view.dart';
import 'package:tilawa/presentation/providers/main_tab_provider.dart';

class MainView extends ConsumerStatefulWidget {
  const MainView({super.key});

  @override
  ConsumerState<MainView> createState() => _MainViewState();
}

class _MainViewState extends ConsumerState<MainView>
    with WidgetsBindingObserver {
  final List<Widget> _views = [
    const HomeView(),
    const PlanView(),
    const ProgressView(),
    const SettingsView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Only nudge on the way out. Firing on resume and detach as well meant
    // three notifications for a single app switch.
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }

    // Only worth interrupting someone who started and stopped. Nothing done
    // yet is not a fact worth a notification, and finished is a job done.
    final progress = ref.read(dailyProgressProvider);
    if (!progress.isPartial) return;

    final strings = ref.read(appStringsProvider);
    NotificationService().sendNotification(
      title: strings.appName,
      body: strings.exitReminder(
        progress.percentComplete,
        progress.percentRemaining,
      ),
    );
  }

  /// Shows the celebration the first time today's target is met.
  ///
  /// Hung off [MainView] rather than the dashboard so it fires wherever the
  /// reciter happens to be when the last review lands.
  void _celebrateIfTargetJustMet(DailyProgress progress) {
    if (!progress.isComplete) return;

    final settings = ref.read(appSettingsProvider.notifier);
    final today = DateTime.now();
    if (settings.hasCelebrated(today)) return;

    final streak = ref.read(progressSummaryProvider).valueOrNull?.streak ?? 1;
    unawaited(settings.markStreakCelebrated(today));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = ref.read(appStringsProvider);
      unawaited(showCelebration(
        context,
        tier: CelebrationTier.dailyStreak,
        title: strings.streakCelebrationTitle(streak > 0 ? streak : 1),
        body: strings.streakCelebrationBody,
        strings: strings,
        withSound: ref.read(appSettingsProvider).celebrationSoundEnabled,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    ref.listen<DailyProgress>(
      dailyProgressProvider,
      (_, progress) => _celebrateIfTargetJustMet(progress),
    );

    final currentIndex = ref.watch(mainTabProvider);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final labels = [
      strings.homeTab,
      strings.planTab,
      strings.progressTab,
      strings.settingsTab
    ];
    const icons = [
      Icons.home_outlined,
      Icons.event_note_outlined,
      Icons.insights_outlined,
      Icons.settings_outlined
    ];
    const selectedIcons = [
      Icons.home_rounded,
      Icons.event_note_rounded,
      Icons.insights_rounded,
      Icons.settings_rounded
    ];
    void select(int index) => ref.read(mainTabProvider.notifier).state = index;

    return Scaffold(
      body: Row(children: [
        if (wide) ...[
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1200,
            selectedIndex: currentIndex,
            onDestinationSelected: select,
            leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(strings.appName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800))),
            destinations: List.generate(
                labels.length,
                (i) => NavigationRailDestination(
                    icon: Icon(icons[i]),
                    selectedIcon: Icon(selectedIcons[i]),
                    label: Text(labels[i]))),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: IndexedStack(
                      index: currentIndex,
                      children: _views,
                    )))),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: select,
              backgroundColor: Theme.of(context).colorScheme.surface,
              destinations: List.generate(
                  labels.length,
                  (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      selectedIcon: Icon(selectedIcons[i]),
                      label: labels[i])),
            ),
    );
  }
}

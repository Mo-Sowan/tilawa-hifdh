import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/widgets/active_revision_card.dart';
import 'package:tilawa/presentation/widgets/reminder_banner.dart';
import 'package:tilawa/presentation/widgets/status_bar.dart';
import 'package:tilawa/presentation/widgets/tarteel_surah_navigator.dart';
import 'package:tilawa/features/recitation/presentation/live_recitation_view.dart';
import 'package:tilawa/presentation/features/home/widgets/quran_completion_card.dart';
import 'package:tilawa/presentation/features/home/widgets/daily_wisdom_card.dart';
import 'package:tilawa/presentation/features/home/widgets/daily_goal_progress_card.dart';
import 'package:tilawa/presentation/features/home/widgets/due_today_list.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isExpanded =
              ref.read(appSettingsProvider).showSurahListExpandedDefault;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(revisionOverviewProvider);
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return SafeArea(
      child: overview.when(
        data: (surahs) => ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppStatusBar(),
                  const SizedBox(height: 14),
                  const ReminderBanner(),
                  const SizedBox(height: 18),
                  ActiveRevisionCard(
                    onStart: () {
                      final target = ref.read(weakestSurahProvider).valueOrNull;
                      if (target == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LiveRecitationView(surah: target),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Full width: it is a progress bar, and it carries its own
                  // bottom spacing so the dashboard does not gap on the days
                  // it hides itself.
                  const QuranCompletionCard(),
                  const DailyGoalProgressCard(),
                  const SizedBox(height: 16),
                  const DailyWisdomCard(),
                  const SizedBox(height: 18),
                  DueTodayList(surahs: surahs),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.revisionPath,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.revisionPathSubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_isExpanded)
                    InkWell(
                      onTap: () => setState(() => _isExpanded = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${strings.showSurahList} (114)',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _isExpanded = false),
                        icon: const Icon(Icons.expand_less_rounded, size: 18),
                        label: Text(strings.hideSurahList,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_isExpanded)
              TarteelSurahNavigator(
                surahs: surahs,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onOpenSurah: (surah) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveRecitationView(surah: surah),
                    ),
                  );
                },
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load path: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}

// ─── Daily Wisdom Card ──────────────────────────────────────────────────────

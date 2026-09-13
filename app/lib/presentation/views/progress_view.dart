import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/activity_day.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/leaderboard/leaderboard_view.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/providers/revision_session_provider.dart';

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final progress = ref.watch(progressSummaryProvider);

    return SafeArea(
      child: progress.when(
        data: (summary) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.progressTab,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: strings.leaderboardTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaderboardView(),
                    ),
                  ),
                  icon: const Icon(Icons.leaderboard_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _StatCard(
                  title: strings.xp,
                  value: '${summary.totalXp}',
                  icon: Icons.star_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  onTap: () => _showInfoSheet(
                      context, strings.xp, strings.xpDescription),
                ),
                _StatCard(
                  title: strings.streak,
                  value: '${summary.streak}',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.rose,
                  onTap: () => _showInfoSheet(
                      context, strings.streak, strings.streakDescription),
                ),
                _StatCard(
                  title: strings.score,
                  value: '${summary.score}',
                  icon: Icons.military_tech_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                _StatCard(
                  title: strings.reviewedToday,
                  value: '${summary.reviewedToday}',
                  icon: Icons.fact_check_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _CalendarCard(days: summary.calendar),
            const SizedBox(height: 22),
            const _SessionLogCard(),
            const SizedBox(height: 22),
            Text(
              strings.mastery,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            for (final bucket in summary.masteryBuckets) ...[
              _MasteryBar(
                label: _localizedBucket(strings, bucket.label),
                count: bucket.count,
                ratio: bucket.ratio,
                color: _bucketColor(bucket.label, context),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showInfoSheet(BuildContext context, String title, String description) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _localizedBucket(AppStrings strings, String label) {
    switch (label.toLowerCase()) {
      case 'excellent':
        return strings.excellent;
      case 'good':
        return strings.good;
      case 'shaky':
        return strings.shaky;
      default:
        return strings.weak;
    }
  }

  Color _bucketColor(String label, BuildContext context) {
    switch (label.toLowerCase()) {
      case 'excellent':
        return Theme.of(context).colorScheme.primary;
      case 'good':
        return Theme.of(context).colorScheme.primary;
      case 'shaky':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }
}

class _SessionLogCard extends ConsumerWidget {
  const _SessionLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final sessions = ref.watch(revisionSessionsProvider);
    final totalTime =
        ref.read(revisionSessionsProvider.notifier).totalTimeToday;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.revisionLog,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (sessions.isNotEmpty)
                Text(
                  '${strings.totalTimeToday}: ${totalTime.inMinutes} ${strings.minutesLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Text(
                  strings.noSessionsYet,
                  style: TextStyle(color: muted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.take(5).length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final timeFormatter = DateFormat(
                    'h:mm a', strings.currentLanguage.locale.languageCode);

                return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text(
                          strings.assessmentEmoji(session.confidence),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.surahName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timeFormatter.format(session.timestamp),
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${session.duration.inMinutes}:${(session.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              strings.sessionDuration,
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ));
              },
            ),
        ],
      ),
    );
  }
}

/// A GitHub-style contribution grid for the last four weeks.
///
/// Shaded by [ActivityDay.weightedScore] rather than by raw time, so a day of
/// real revision stands out from a day the app was merely open. Tapping a cell
/// gives the numbers behind the shade.
class _CalendarCard extends ConsumerWidget {
  const _CalendarCard({required this.days});

  final List<ActivityDay> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                strings.activityCalendar,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.calendarSubtitle(
              days.length,
              days.where((day) => day.hasActivity).length,
            ),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              return Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 3),
                message: strings.heatmapTooltip(
                  DateFormat.MMMd().format(day.date),
                  day.minutesSpent,
                  day.surahNumbers.length,
                ),
                child: _HeatCell(day: day, isDark: isDark),
              );
            },
          ),
          const SizedBox(height: 12),
          _HeatLegend(strings: strings, muted: muted),
        ],
      ),
    );
  }
}

/// One day in the grid.
class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.day, required this.isDark});

  final ActivityDay day;
  final bool isDark;

  /// The five tiers, as opacity of the primary colour.
  static const List<double> tierOpacity = [0.0, 0.25, 0.5, 0.75, 1.0];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = day.heatTier;
    final fill = tier == 0
        ? scheme.surfaceContainerHighest
        : scheme.primary.withValues(alpha: tierOpacity[tier]);

    // Readable against the fill: the darker tiers need light text.
    final onFill = tier >= 3
        ? Colors.black
        : (isDark ? AppColors.textMuted : AppColors.lightTextMuted);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tier == 0
              ? scheme.outline
              : scheme.primary.withValues(alpha: .45),
        ),
      ),
      alignment: Alignment.center,
      child: day.hasActivity
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: onFill,
                ),
                Text(
                  '${day.date.day}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: onFill,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                ),
              ],
            )
          : Text(
              '${day.date.day}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: onFill,
                    fontWeight: FontWeight.w900,
                  ),
            ),
    );
  }
}

/// The "less ... more" key under the grid.
class _HeatLegend extends StatelessWidget {
  const _HeatLegend({required this.strings, required this.muted});

  final AppStrings strings;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: muted);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(strings.heatmapLess, style: style),
        const SizedBox(width: 6),
        for (final opacity in _HeatCell.tierOpacity)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: opacity == 0
                  ? scheme.surfaceContainerHighest
                  : scheme.primary.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: opacity == 0
                    ? scheme.outline
                    : scheme.primary.withValues(alpha: .45),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(strings.heatmapMore, style: style),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 26),
              if (onTap != null)
                Icon(Icons.info_outline_rounded,
                    color:
                        isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.lightTextMuted,
                    ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }
}

class _MasteryBar extends StatelessWidget {
  const _MasteryBar({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int count;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              '$count',
              style: TextStyle(
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: ratio.clamp(0, 1).toDouble(),
          color: color,
          backgroundColor: isDark ? AppColors.outline : AppColors.lightOutline,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

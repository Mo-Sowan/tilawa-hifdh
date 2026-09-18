import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/activity_day.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/progress/widgets/heat_cell.dart';
import 'package:tilawa/presentation/features/progress/widgets/heat_legend.dart';

/// A GitHub-style contribution grid for the last four weeks.
///
/// Shaded by [ActivityDay.weightedScore] rather than by raw time, so a day of
/// real revision stands out from a day the app was merely open. Tapping a cell
/// gives the numbers behind the shade.
class ActivityHeatmapCard extends ConsumerWidget {
  const ActivityHeatmapCard({super.key, required this.days});

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
                child: HeatCell(day: day, isDark: isDark),
              );
            },
          ),
          const SizedBox(height: 12),
          HeatLegend(strings: strings, muted: muted),
        ],
      ),
    );
  }
}

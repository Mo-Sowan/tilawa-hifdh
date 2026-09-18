import 'package:flutter/material.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/leaderboard_entry.dart';
import 'package:tilawa/presentation/features/leaderboard/widgets/leaderboard_metrics.dart';

class LeaderboardEntryRow extends StatelessWidget {
  const LeaderboardEntryRow({super.key, required this.entry, required this.strings});

  final LeaderboardEntry entry;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = entry.isCurrentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: mine ? scheme.primary.withValues(alpha: 0.08) : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mine
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outline.withValues(alpha: 0.7),
          width: mine ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: rankColour(entry.rank, scheme),
                  ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary.withValues(alpha: 0.18),
            child: Text(
              entry.initial,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? '${entry.displayName} (${strings.leaderboardYou})'
                       : entry.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                LeaderboardMetrics(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gold, silver and bronze for the top three; everyone else reads as plain.
  static Color rankColour(int rank, ColorScheme scheme) => switch (rank) {
        1 => AppColors.amber,
        2 => Colors.blueGrey,
        3 => const Color(0xFFB87333),
        _ => scheme.onSurface.withValues(alpha: 0.55),
      };
}

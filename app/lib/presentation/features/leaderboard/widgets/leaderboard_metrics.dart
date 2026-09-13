import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/leaderboard_entry.dart';

/// Streak, score and today's work, side by side.
class LeaderboardMetrics extends StatelessWidget {
  const LeaderboardMetrics({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.65);

    Widget metric(IconData icon, Color colour, String value) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colour),
              const SizedBox(width: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
              ),
            ],
          ),
        );

    return Row(
      children: [
        metric(
          Icons.local_fire_department_rounded,
          AppColors.rose,
          '${entry.streak}',
        ),
        metric(
          Icons.emoji_events_rounded,
          AppColors.amber,
          '${entry.totalXp}',
        ),
        metric(
          Icons.menu_book_rounded,
          Theme.of(context).colorScheme.primary,
          '${entry.reviewedToday}',
        ),
      ],
    );
  }
}

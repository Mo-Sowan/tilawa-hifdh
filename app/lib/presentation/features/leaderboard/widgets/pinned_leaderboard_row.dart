import 'package:flutter/material.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/domain/entities/leaderboard_entry.dart';

/// The reciter's own row, held at the bottom when they rank below the page.
class PinnedLeaderboardRow extends StatelessWidget {
  const PinnedLeaderboardRow({super.key, required this.entry, required this.strings});

  final LeaderboardEntry entry;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 12,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: LeaderboardEntryRow(entry: entry, strings: strings),
        ),
      ),
    );
  }
}

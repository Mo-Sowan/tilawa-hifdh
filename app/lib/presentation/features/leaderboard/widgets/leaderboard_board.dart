import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/leaderboard_provider.dart';

class LeaderboardBoard extends ConsumerWidget {
  const LeaderboardBoard({super.key, required this.scope});

  final LeaderboardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final board = ref.watch(leaderboardProvider(scope));

    return board.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LeaderboardMessage(text: strings.leaderboardOffline),
      data: (data) {
        if (data.isEmpty) {
          return LeaderboardMessage(
            text: scope == LeaderboardScope.friends
                ? strings.leaderboardFriendsEmpty
                : strings.leaderboardEmpty,
          );
        }

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(leaderboardProvider(scope)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: data.entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => LeaderboardEntryRow(
                    entry: data.entries[index],
                    strings: strings,
                  ),
                ),
              ),
            ),
            // Pinned only when they are not already above, so their row is
            // never shown twice.
            if (data.currentUser != null && !data.currentUserIsListed)
              PinnedLeaderboardRow(entry: data.currentUser!, strings: strings),
          ],
        );
      },
    );
  }
}

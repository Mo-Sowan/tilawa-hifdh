import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/domain/entities/leaderboard_entry.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';

/// Which board is being shown.
enum LeaderboardScope {
  global,
  friends;

  String get wireName => name;
}

/// The board for [scope].
///
/// Unlike the rest of the app there is no offline fallback here, and there
/// should not be: a leaderboard of one person is not a leaderboard. When the
/// API cannot be reached the screen says so rather than inventing a ranking.
final leaderboardProvider =
    FutureProvider.family<Leaderboard, LeaderboardScope>((ref, scope) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getLeaderboard(scope: scope.wireName, limit: 25);
  return Leaderboard.fromJson(json);
});

/// Follows another reciter, then refreshes the friends board.
final addFriendProvider =
    Provider<Future<void> Function(String email)>((ref) {
  return (email) async {
    await ref.read(apiClientProvider).addFriend(email);
    ref.invalidate(leaderboardProvider(LeaderboardScope.friends));
  };
});

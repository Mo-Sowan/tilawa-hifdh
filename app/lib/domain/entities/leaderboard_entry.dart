/// One reciter's standing on the board.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.streak,
    required this.totalXp,
    required this.reviewedToday,
    required this.isCurrentUser,
  });

  final int rank;
  final String userId;
  final String displayName;
  final int streak;
  final int totalXp;
  final int reviewedToday;

  /// Decided by the server, so the app does not need to know its own id to
  /// highlight the right row.
  final bool isCurrentUser;

  /// The letter shown when there is no picture to show.
  String get initial {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  static LeaderboardEntry fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      totalXp: (json['totalXp'] as num?)?.toInt() ?? 0,
      reviewedToday: (json['reviewedToday'] as num?)?.toInt() ?? 0,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }
}

/// A page of the board.
class Leaderboard {
  const Leaderboard({required this.entries, this.currentUser});

  const Leaderboard.empty() : entries = const [], currentUser = null;

  final List<LeaderboardEntry> entries;

  /// The caller's own row whatever their rank, so it can be pinned without
  /// paging through the board to find them.
  final LeaderboardEntry? currentUser;

  bool get isEmpty => entries.isEmpty;

  /// Whether the reciter's own row is already on screen, which decides whether
  /// pinning it at the bottom would be a duplicate.
  bool get currentUserIsListed =>
      currentUser != null &&
      entries.any((entry) => entry.userId == currentUser!.userId);

  static Leaderboard fromJson(Map<String, dynamic> json) {
    final entries = json['entries'];
    final current = json['currentUser'];

    return Leaderboard(
      entries: [
        if (entries is List)
          for (final row in entries)
            LeaderboardEntry.fromJson(row as Map<String, dynamic>),
      ],
      currentUser: current is Map<String, dynamic>
          ? LeaderboardEntry.fromJson(current)
          : null,
    );
  }
}

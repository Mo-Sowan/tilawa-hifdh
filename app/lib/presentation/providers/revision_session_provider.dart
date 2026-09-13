import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/domain/entities/revision_session.dart';

class RevisionSessionNotifier extends StateNotifier<List<RevisionSession>> {
  RevisionSessionNotifier() : super([]);

  void addSession({
    required int surahNumber,
    required String surahName,
    required Duration duration,
    required int confidence,
  }) {
    final session = RevisionSession(
      surahNumber: surahNumber,
      surahName: surahName,
      duration: duration,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
    state = [session, ...state];
  }

  Duration get totalTimeToday {
    final now = DateTime.now();
    return state
        .where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day)
        .fold(Duration.zero, (prev, s) => prev + s.duration);
  }

  void clearAll() {
    state = [];
  }
}

final revisionSessionsProvider = StateNotifierProvider<RevisionSessionNotifier, List<RevisionSession>>((ref) {
  return RevisionSessionNotifier();
});

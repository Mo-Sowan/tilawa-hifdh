import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tilawa/services/database_service.dart';
import 'package:tilawa/data/datasources/api_client.dart';

/// A completed offline follow-along session.
class RecitationSessionRecord {
  const RecitationSessionRecord({
    required this.id,
    required this.surahNumber,
    required this.startedAt,
    required this.duration,
    required this.versesMatched,
    required this.versesAttempted,
    required this.averageConfidence,
    required this.coveredRefs,
    this.synced = false,
  });

  final String id;
  final int surahNumber;
  final DateTime startedAt;
  final Duration duration;
  final int versesMatched;
  final int versesAttempted;
  final double averageConfidence;
  final List<String> coveredRefs;
  final bool synced;

  Map<String, Object?> toRow() => {
        'id': id,
        'surahNumber': surahNumber,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'versesMatched': versesMatched,
        'versesAttempted': versesAttempted,
        'averageConfidence': averageConfidence,
        'coveredRefs': jsonEncode(coveredRefs),
        'synced': synced ? 1 : 0,
      };

  static RecitationSessionRecord fromRow(Map<String, Object?> row) {
    return RecitationSessionRecord(
      id: row['id'] as String,
      surahNumber: (row['surahNumber'] as num).toInt(),
      startedAt: DateTime.parse(row['startedAt'] as String),
      duration: Duration(seconds: (row['durationSeconds'] as num).toInt()),
      versesMatched: (row['versesMatched'] as num).toInt(),
      versesAttempted: (row['versesAttempted'] as num).toInt(),
      averageConfidence: (row['averageConfidence'] as num).toDouble(),
      coveredRefs:
          (jsonDecode(row['coveredRefs'] as String) as List).cast<String>(),
      synced: (row['synced'] as num).toInt() == 1,
    );
  }

  Map<String, dynamic> toApiJson() => {
        'surahNumber': surahNumber,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'versesMatched': versesMatched,
        'versesAttempted': versesAttempted,
        'averageConfidence': averageConfidence,
        'coveredRefs': coveredRefs,
      };
}

/// Stores follow-along sessions locally, then mirrors them to the API.
///
/// Recitation works with no network at all, so the local write is the
/// authoritative one and the upload is a best-effort mirror that is retried on
/// the next successful sync.
class RecitationSessionRepository {
  RecitationSessionRepository(this._api, {DatabaseService? database})
      : _database = database ?? DatabaseService();

  final TilawaApiClient _api;
  final DatabaseService _database;

  /// Persists [session] locally and tries to upload it straight away.
  Future<void> save(RecitationSessionRecord session) async {
    await _database.insertRecitationSession(session.toRow());

    if (await _upload(session)) {
      await _database.markRecitationSessionSynced(session.id);
    }
  }

  /// Uploads everything still marked unsynced. Safe to call on app start.
  Future<int> syncPending({int limit = 50}) async {
    final rows = await _database.recitationSessions(
      limit: limit,
      onlyUnsynced: true,
    );

    var uploaded = 0;
    for (final row in rows) {
      final session = RecitationSessionRecord.fromRow(row);
      if (!await _upload(session)) break; // Offline: stop and retry later.
      await _database.markRecitationSessionSynced(session.id);
      uploaded++;
    }
    return uploaded;
  }

  Future<List<RecitationSessionRecord>> recent({int limit = 50}) async {
    final rows = await _database.recitationSessions(limit: limit);
    return rows.map(RecitationSessionRecord.fromRow).toList();
  }

  Future<bool> _upload(RecitationSessionRecord session) async {
    try {
      await _api.recordRecitationSession(session.toApiJson());
      return true;
    } on Exception catch (error) {
      debugPrint('Recitation session upload deferred: $error');
      return false;
    }
  }
}

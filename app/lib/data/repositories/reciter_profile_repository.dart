import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tilawa/domain/entities/reciter_profile.dart';
import 'package:tilawa/services/database_service.dart';
import 'package:tilawa/data/datasources/api_client.dart';

/// Where the reciter's answers live.
///
/// On the device first, always. The answers shape what the app offers, so they
/// have to be there before any network is, and a reciter who never signs in
/// still gets a personalised plan. The API copy is a mirror for when they move
/// to another device, and failing to write it is never allowed to lose the
/// local answer or block the flow.
class ReciterProfileRepository {
  ReciterProfileRepository({
    required TilawaApiClient api,
    DatabaseService? database,
  })  : _api = api,
        _database = database ?? DatabaseService();

  static const String _settingKey = 'reciterProfile';

  final TilawaApiClient _api;
  final DatabaseService _database;

  Future<ReciterProfile> load() async {
    final raw = await _database.getSetting(_settingKey);
    if (raw == null || raw.isEmpty) return const ReciterProfile();
    try {
      return ReciterProfile.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } catch (error) {
      // Written by an older build, or truncated storage. Asking the four
      // questions again is a far better outcome than failing to start.
      debugPrint('Discarding an unreadable reciter profile: $error');
      return const ReciterProfile();
    }
  }

  /// Stores [profile] on the device, then mirrors it to the API if it answers.
  Future<void> save(ReciterProfile profile) async {
    await _database.saveSetting(_settingKey, jsonEncode(profile.toJson()));
    await _mirrorToApi(profile);
  }

  Future<void> _mirrorToApi(ReciterProfile profile) async {
    try {
      await _api.putReciterProfile(Map<String, dynamic>.from(profile.toJson()));
    } catch (error) {
      // Offline, signed out, or an older server without the endpoint. The
      // answers are safe on the device; the next save tries again.
      debugPrint('Could not mirror the reciter profile to the API: $error');
    }
  }
}

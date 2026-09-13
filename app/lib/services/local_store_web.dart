import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:tilawa/services/local_store.dart';

LocalStore createLocalStore() => BrowserLocalStore();

/// `localStorage`-backed store for the web build.
///
/// The data here is small and per-device — settings, Mushaf annotations, and
/// the queue of recitation sessions still to upload — so a key/value store is
/// the right shape. Collections are held in memory and written back as JSON on
/// every mutation; that is cheap at these sizes and keeps reads synchronous.
class BrowserLocalStore implements LocalStore {
  static const String _settingsKey = 'tilawa.settings';
  static const String _annotationsKey = 'tilawa.annotations';
  static const String _sessionsKey = 'tilawa.sessions';
  static const String _revisionStatesKey = 'tilawa.revisionStates';
  static const String _revisionEventsKey = 'tilawa.revisionEvents';
  static const String _plansKey = 'tilawa.plans';

  final Map<String, String> _settings = {};
  final Map<String, Map<String, Object?>> _annotations = {};
  final Map<String, Map<String, Object?>> _sessions = {};
  final Map<String, Map<String, Object?>> _revisionStates = {};
  final Map<String, Map<String, Object?>> _revisionEvents = {};
  final Map<String, Map<String, Object?>> _plans = {};

  bool _loaded = false;

  @override
  Future<void> initialize() async {
    if (_loaded) return;

    _settings.addAll(_readMap(_settingsKey).map(
      (key, value) => MapEntry(key, value.toString()),
    ));
    _annotations.addAll(_readRows(_annotationsKey));
    _sessions.addAll(_readRows(_sessionsKey));
    _revisionStates.addAll(_readRows(_revisionStatesKey));
    _revisionEvents.addAll(_readRows(_revisionEventsKey));
    _plans.addAll(_readRows(_plansKey));
    _loaded = true;
  }

  @override
  Future<String?> getSetting(String key) async {
    await initialize();
    return _settings[key];
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    await initialize();
    _settings[key] = value;
    _write(_settingsKey, _settings);
  }

  @override
  Future<void> deleteSetting(String key) async {
    await initialize();
    _settings.remove(key);
    _write(_settingsKey, _settings);
  }

  @override
  Future<List<Map<String, Object?>>> annotationsForPage(int pageNumber) async {
    await initialize();
    return _sortedAnnotations(
      (row) => (row['pageNumber'] as num?)?.toInt() == pageNumber,
    );
  }

  @override
  Future<List<Map<String, Object?>>> annotationsForAyah(
    int surahNumber,
    int ayahNumber,
  ) async {
    await initialize();
    return _sortedAnnotations(
      (row) =>
          (row['surahNumber'] as num?)?.toInt() == surahNumber &&
          (row['ayahNumber'] as num?)?.toInt() == ayahNumber,
    );
  }

  @override
  Future<void> upsertAnnotation(Map<String, Object?> annotation) async {
    await initialize();
    _annotations[annotation['id'] as String] = Map.of(annotation);
    _write(_annotationsKey, _annotations);
  }

  @override
  Future<void> deleteAnnotation(String id) async {
    await initialize();
    _annotations.remove(id);
    _write(_annotationsKey, _annotations);
  }

  @override
  Future<void> insertRecitationSession(Map<String, Object?> session) async {
    await initialize();
    _sessions[session['id'] as String] = Map.of(session);
    _write(_sessionsKey, _sessions);
  }

  @override
  Future<List<Map<String, Object?>>> recitationSessions({
    int limit = 50,
    bool onlyUnsynced = false,
  }) async {
    await initialize();
    final rows = _sessions.values
        .where((row) => !onlyUnsynced || (row['synced'] as num?)?.toInt() == 0)
        .toList()
      ..sort((a, b) {
        final left = a['startedAt'] as String? ?? '';
        final right = b['startedAt'] as String? ?? '';
        return onlyUnsynced ? left.compareTo(right) : right.compareTo(left);
      });
    return rows.take(limit).map(Map<String, Object?>.of).toList();
  }

  @override
  Future<void> markRecitationSessionSynced(String id) async {
    await initialize();
    final row = _sessions[id];
    if (row == null) return;
    row['synced'] = 1;
    _write(_sessionsKey, _sessions);
  }

  @override
  Future<List<Map<String, Object?>>> revisionStates() async {
    await initialize();
    return _revisionStates.values.map(Map<String, Object?>.of).toList();
  }

  @override
  Future<void> upsertRevisionState(Map<String, Object?> state) async {
    await initialize();
    _revisionStates['${state['surahNumber']}'] = Map.of(state);
    _write(_revisionStatesKey, _revisionStates);
  }

  @override
  Future<void> insertRevisionEvent(Map<String, Object?> event) async {
    await initialize();
    _revisionEvents[event['id'] as String] = Map.of(event);
    _write(_revisionEventsKey, _revisionEvents);
  }

  @override
  Future<List<Map<String, Object?>>> revisionEventsSince(DateTime from) async {
    await initialize();
    final cutoff = from.toIso8601String();
    final rows = _revisionEvents.values
        .where((row) => (row['occurredAt'] as String? ?? '').compareTo(cutoff) >= 0)
        .toList()
      ..sort((a, b) => (a['occurredAt'] as String? ?? '')
          .compareTo(b['occurredAt'] as String? ?? ''));
    return rows.map(Map<String, Object?>.of).toList();
  }

  @override
  Future<List<Map<String, Object?>>> plans() async {
    await initialize();
    final rows = _plans.values.toList()
      ..sort((a, b) => (a['createdAt'] as String? ?? '')
          .compareTo(b['createdAt'] as String? ?? ''));
    return rows.map(Map<String, Object?>.of).toList();
  }

  @override
  Future<void> upsertPlan(Map<String, Object?> plan) async {
    await initialize();
    _plans[plan['id'] as String] = Map.of(plan);
    _write(_plansKey, _plans);
  }

  @override
  Future<void> deletePlan(String id) async {
    await initialize();
    _plans.remove(id);
    _write(_plansKey, _plans);
  }

  @override
  Future<void> clearProgress() async {
    await initialize();
    _revisionStates.clear();
    _revisionEvents.clear();
    _plans.clear();
    _write(_revisionStatesKey, _revisionStates);
    _write(_revisionEventsKey, _revisionEvents);
    _write(_plansKey, _plans);
  }

  List<Map<String, Object?>> _sortedAnnotations(
    bool Function(Map<String, Object?>) matches,
  ) {
    final rows = _annotations.values.where(matches).toList()
      ..sort((a, b) => (b['createdAt'] as String? ?? '')
          .compareTo(a['createdAt'] as String? ?? ''));
    return rows.map(Map<String, Object?>.of).toList();
  }

  Map<String, dynamic> _readMap(String key) {
    try {
      final raw = web.window.localStorage.getItem(key);
      if (raw == null || raw.isEmpty) return const {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (error) {
      // Private browsing, cleared site data, or a value written by an older
      // build: start clean rather than blocking the app.
      debugPrint('Discarding unreadable "$key" from localStorage: $error');
      return const {};
    }
  }

  Map<String, Map<String, Object?>> _readRows(String key) {
    return _readMap(key).map(
      (id, row) => MapEntry(id, Map<String, Object?>.from(row as Map)),
    );
  }

  void _write(String key, Object value) {
    try {
      web.window.localStorage.setItem(key, jsonEncode(value));
    } catch (error) {
      // Quota exceeded or storage disabled. The in-memory copy still serves
      // this session.
      debugPrint('Could not persist "$key" to localStorage: $error');
    }
  }
}

import 'package:tilawa/services/local_store.dart';

/// The app's on-device storage.
///
/// A single façade over [LocalStore] so callers never care whether the backing
/// store is SQLite or the browser's `localStorage`.
class DatabaseService {
  DatabaseService._internal() : _store = createLocalStore();

  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  /// Test seam: pass a store instead of the platform default.
  DatabaseService.withStore(this._store);

  final LocalStore _store;

  Future<void> initialize() => _store.initialize();

  // --- Settings -------------------------------------------------------------

  Future<String?> getSetting(String key) => _store.getSetting(key);

  Future<void> saveSetting(String key, String value) =>
      _store.saveSetting(key, value);

  Future<void> deleteSetting(String key) => _store.deleteSetting(key);

  // --- Ayah annotations -----------------------------------------------------

  Future<List<Map<String, Object?>>> annotationsForPage(int pageNumber) =>
      _store.annotationsForPage(pageNumber);

  Future<List<Map<String, Object?>>> annotationsForAyah(
    int surahNumber,
    int ayahNumber,
  ) =>
      _store.annotationsForAyah(surahNumber, ayahNumber);

  Future<void> upsertAnnotation(Map<String, Object?> annotation) =>
      _store.upsertAnnotation(annotation);

  Future<void> deleteAnnotation(String id) => _store.deleteAnnotation(id);

  // --- Recitation sessions --------------------------------------------------

  Future<void> insertRecitationSession(Map<String, Object?> session) =>
      _store.insertRecitationSession(session);

  Future<List<Map<String, Object?>>> recitationSessions({
    int limit = 50,
    bool onlyUnsynced = false,
  }) =>
      _store.recitationSessions(limit: limit, onlyUnsynced: onlyUnsynced);

  Future<void> markRecitationSessionSynced(String id) =>
      _store.markRecitationSessionSynced(id);

  // --- Revision progress ----------------------------------------------------

  Future<List<Map<String, Object?>>> revisionStates() =>
      _store.revisionStates();

  Future<void> upsertRevisionState(Map<String, Object?> state) =>
      _store.upsertRevisionState(state);

  Future<void> insertRevisionEvent(Map<String, Object?> event) =>
      _store.insertRevisionEvent(event);

  Future<List<Map<String, Object?>>> revisionEventsSince(DateTime from) =>
      _store.revisionEventsSince(from);

  // --- Revision plans -------------------------------------------------------

  Future<List<Map<String, Object?>>> plans() => _store.plans();

  Future<void> upsertPlan(Map<String, Object?> plan) => _store.upsertPlan(plan);

  Future<void> deletePlan(String id) => _store.deletePlan(id);

  Future<void> clearProgress() => _store.clearProgress();
}

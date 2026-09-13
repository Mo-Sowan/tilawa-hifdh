import 'package:tilawa/services/local_store_io.dart'
    if (dart.library.js_interop) 'package:tilawa/services/local_store_web.dart' as impl;

/// On-device persistence, independent of how it is stored.
///
/// Mobile and desktop back this with SQLite; the web build backs it with
/// `localStorage`, which is enough for settings, annotations and the queue of
/// recitation sessions waiting to sync.
abstract class LocalStore {
  Future<void> initialize();

  // --- Settings -------------------------------------------------------------

  Future<String?> getSetting(String key);

  Future<void> saveSetting(String key, String value);

  Future<void> deleteSetting(String key);

  // --- Ayah annotations -----------------------------------------------------

  Future<List<Map<String, Object?>>> annotationsForPage(int pageNumber);

  Future<List<Map<String, Object?>>> annotationsForAyah(
    int surahNumber,
    int ayahNumber,
  );

  /// Inserts, or replaces the row with the same `id`.
  Future<void> upsertAnnotation(Map<String, Object?> annotation);

  Future<void> deleteAnnotation(String id);

  // --- Recitation sessions --------------------------------------------------

  Future<void> insertRecitationSession(Map<String, Object?> session);

  /// Newest first, unless [onlyUnsynced] is set — those come oldest first so
  /// they upload in the order they happened.
  Future<List<Map<String, Object?>>> recitationSessions({
    int limit = 50,
    bool onlyUnsynced = false,
  });

  Future<void> markRecitationSessionSynced(String id);

  // --- Revision progress ----------------------------------------------------

  /// One row per surah that has been reviewed at least once. Surahs with no
  /// history are absent rather than stored as zeroes, so "never reviewed" and
  /// "reviewed badly" stay different facts.
  Future<List<Map<String, Object?>>> revisionStates();

  Future<void> upsertRevisionState(Map<String, Object?> state);

  /// One row per completed revision. The activity calendar, the streak and
  /// today's progress are all counted from these, which is why a review has to
  /// leave a dated record behind and not only update a running total.
  Future<void> insertRevisionEvent(Map<String, Object?> event);

  /// Events on or after [from], oldest first.
  Future<List<Map<String, Object?>>> revisionEventsSince(DateTime from);

  // --- Revision plans -------------------------------------------------------

  Future<List<Map<String, Object?>>> plans();

  Future<void> upsertPlan(Map<String, Object?> plan);

  Future<void> deletePlan(String id);

  /// Drops revision states, events and plans. Settings and annotations stay.
  Future<void> clearProgress();
}

/// The store for the platform this build targets.
LocalStore createLocalStore() => impl.createLocalStore();

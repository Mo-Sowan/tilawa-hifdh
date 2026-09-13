import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:tilawa/services/local_store.dart';

LocalStore createLocalStore() => SqfliteLocalStore();

/// SQLite-backed store for mobile and desktop.
class SqfliteLocalStore implements LocalStore {
  static const String _databaseName = 'tilawa.db';
  static const int _databaseVersion = 2;

  static const String _settings = 'settings';
  static const String _annotations = 'ayah_annotations';
  static const String _sessions = 'recitation_sessions';
  static const String _revisionStates = 'revision_states';
  static const String _revisionEvents = 'revision_events';
  static const String _plans = 'revision_plans';

  Database? _database;

  Future<Database> get _db async => _database ??= await _open();

  @override
  Future<void> initialize() async {
    await _db;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, _) => _createSchema(db),
      onUpgrade: (db, _, __) => _createSchema(db),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_annotations(
        id TEXT PRIMARY KEY,
        surahNumber INTEGER NOT NULL,
        ayahNumber INTEGER NOT NULL,
        pageNumber INTEGER NOT NULL,
        type TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_annotations_page ON $_annotations(pageNumber)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_annotations_ayah ON $_annotations(surahNumber, ayahNumber)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_sessions(
        id TEXT PRIMARY KEY,
        surahNumber INTEGER NOT NULL,
        startedAt TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL,
        versesMatched INTEGER NOT NULL,
        versesAttempted INTEGER NOT NULL,
        averageConfidence REAL NOT NULL,
        coveredRefs TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_synced ON $_sessions(synced)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_revisionStates(
        surahNumber INTEGER PRIMARY KEY,
        masteryAtReview REAL NOT NULL,
        mistakeRate REAL NOT NULL,
        revisionCount INTEGER NOT NULL,
        consecutiveGoodReviews INTEGER NOT NULL,
        lastReviewed TEXT,
        revisionIntensity TEXT NOT NULL,
        lastRevisionDurationSeconds INTEGER NOT NULL,
        lastRevisionSection TEXT,
        quranReadCount INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_revisionEvents(
        id TEXT PRIMARY KEY,
        surahNumber INTEGER NOT NULL,
        occurredAt TEXT NOT NULL,
        confidence INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        xp INTEGER NOT NULL,
        quranReadCount INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_at ON $_revisionEvents(occurredAt)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_plans(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        surahNumbers TEXT NOT NULL,
        reminderTime TEXT NOT NULL,
        isActive INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<String?> getSetting(String key) async {
    final db = await _db;
    final rows = await db.query(_settings, where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      _settings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteSetting(String key) async {
    final db = await _db;
    await db.delete(_settings, where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<List<Map<String, Object?>>> annotationsForPage(int pageNumber) async {
    final db = await _db;
    return db.query(
      _annotations,
      where: 'pageNumber = ?',
      whereArgs: [pageNumber],
      orderBy: 'createdAt DESC',
    );
  }

  @override
  Future<List<Map<String, Object?>>> annotationsForAyah(
    int surahNumber,
    int ayahNumber,
  ) async {
    final db = await _db;
    return db.query(
      _annotations,
      where: 'surahNumber = ? AND ayahNumber = ?',
      whereArgs: [surahNumber, ayahNumber],
      orderBy: 'createdAt DESC',
    );
  }

  @override
  Future<void> upsertAnnotation(Map<String, Object?> annotation) async {
    final db = await _db;
    await db.insert(
      _annotations,
      annotation,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAnnotation(String id) async {
    final db = await _db;
    await db.delete(_annotations, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> insertRecitationSession(Map<String, Object?> session) async {
    final db = await _db;
    await db.insert(
      _sessions,
      session,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, Object?>>> recitationSessions({
    int limit = 50,
    bool onlyUnsynced = false,
  }) async {
    final db = await _db;
    return db.query(
      _sessions,
      where: onlyUnsynced ? 'synced = 0' : null,
      orderBy: onlyUnsynced ? 'startedAt ASC' : 'startedAt DESC',
      limit: limit,
    );
  }

  @override
  Future<void> markRecitationSessionSynced(String id) async {
    final db = await _db;
    await db.update(
      _sessions,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Map<String, Object?>>> revisionStates() async {
    final db = await _db;
    return db.query(_revisionStates);
  }

  @override
  Future<void> upsertRevisionState(Map<String, Object?> state) async {
    final db = await _db;
    await db.insert(
      _revisionStates,
      state,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertRevisionEvent(Map<String, Object?> event) async {
    final db = await _db;
    await db.insert(
      _revisionEvents,
      event,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, Object?>>> revisionEventsSince(DateTime from) async {
    final db = await _db;
    return db.query(
      _revisionEvents,
      where: 'occurredAt >= ?',
      whereArgs: [from.toIso8601String()],
      orderBy: 'occurredAt ASC',
    );
  }

  @override
  Future<List<Map<String, Object?>>> plans() async {
    final db = await _db;
    return db.query(_plans, orderBy: 'createdAt ASC');
  }

  @override
  Future<void> upsertPlan(Map<String, Object?> plan) async {
    final db = await _db;
    await db.insert(_plans, plan, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deletePlan(String id) async {
    final db = await _db;
    await db.delete(_plans, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearProgress() async {
    final db = await _db;
    await db.delete(_revisionStates);
    await db.delete(_revisionEvents);
    await db.delete(_plans);
  }
}

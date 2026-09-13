import 'package:tilawa/domain/entities/ayah_annotation.dart';
import 'package:tilawa/domain/entities/quran_page_mapper.dart';
import 'package:tilawa/services/database_service.dart';

/// Mushaf highlights, notes and bookmarks.
///
/// Annotations are stored separately from the page images, which stay
/// read-only; the overlay draws them back on at render time.
class AyahAnnotationRepository {
  AyahAnnotationRepository({DatabaseService? databaseService})
      : _database = databaseService ?? DatabaseService();

  final DatabaseService _database;

  Future<List<AyahAnnotation>> getForPage(int pageNumber) async {
    final rows = await _database.annotationsForPage(pageNumber);
    return rows.map(AyahAnnotation.fromMap).toList();
  }

  Future<List<AyahAnnotation>> getForAyah(AyahReference reference) async {
    final rows = await _database.annotationsForAyah(
      reference.surahNumber,
      reference.ayahNumber,
    );
    return rows.map(AyahAnnotation.fromMap).toList();
  }

  Future<void> upsert(AyahAnnotation annotation) =>
      _database.upsertAnnotation(annotation.toMap());

  Future<void> delete(String id) => _database.deleteAnnotation(id);
}

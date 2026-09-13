import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/repositories/revision_repository.dart';

class GetWeakestSurah {
  const GetWeakestSurah(this._repository);

  final RevisionRepository _repository;

  Future<SurahRevision> call() => _repository.fetchWeakestSurah();
}

import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/repositories/revision_repository.dart';

class GetRevisionOverview {
  const GetRevisionOverview(this._repository);

  final RevisionRepository _repository;

  Future<List<SurahRevision>> call() => _repository.fetchRevisionStatus();
}

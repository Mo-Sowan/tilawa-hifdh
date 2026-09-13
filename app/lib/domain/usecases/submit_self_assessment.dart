import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/repositories/revision_repository.dart';

class SubmitSelfAssessment {
  const SubmitSelfAssessment(this._repository);

  final RevisionRepository _repository;

  Future<List<SurahRevision>> call(int surahNumber, int confidence, int durationSeconds, String? section, int quranReadCount) {
    return _repository.recordSelfAssessment(surahNumber, confidence, durationSeconds, section, quranReadCount);
  }
}

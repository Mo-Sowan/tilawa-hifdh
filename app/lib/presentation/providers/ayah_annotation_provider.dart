import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/data/repositories/ayah_annotation_repository.dart';
import 'package:tilawa/domain/entities/ayah_annotation.dart';
import 'package:tilawa/domain/entities/quran_page_mapper.dart';

final ayahAnnotationRepositoryProvider =
    Provider<AyahAnnotationRepository>((ref) {
  return AyahAnnotationRepository();
});

final quranPageMapperProvider = Provider<QuranPageMapper>((ref) {
  return const QuranPageMapper();
});

final mushafPageMappingProvider =
    FutureProvider.family<MushafPageMapping, int>((ref, pageNumber) async {
  return ref.read(quranPageMapperProvider).loadPageMapping(pageNumber);
});

final ayahAnnotationsForPageProvider =
    FutureProvider.family<List<AyahAnnotation>, int>((ref, pageNumber) async {
  return ref.read(ayahAnnotationRepositoryProvider).getForPage(pageNumber);
});

class AyahAnnotationController extends StateNotifier<AsyncValue<void>> {
  AyahAnnotationController(this._repository) : super(const AsyncData(null));

  final AyahAnnotationRepository _repository;

  Future<void> saveHighlight({
    required AyahReference reference,
    required int pageNumber,
    required Color color,
    String? note,
    AyahAnnotationType type = AyahAnnotationType.highlight,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final annotation = AyahAnnotation(
        id: '${reference.key}:${type.name}',
        reference: reference,
        pageNumber: pageNumber,
        type: type,
        colorValue: color.toARGB32(),
        note: note,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.upsert(annotation);
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.delete(id));
  }
}

final ayahAnnotationControllerProvider =
    StateNotifierProvider<AyahAnnotationController, AsyncValue<void>>((ref) {
  return AyahAnnotationController(ref.read(ayahAnnotationRepositoryProvider));
});

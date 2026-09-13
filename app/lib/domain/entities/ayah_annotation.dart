import 'package:flutter/material.dart';

import 'package:tilawa/domain/entities/quran_page_mapper.dart';

enum AyahAnnotationType {
  highlight,
  bookmark,
  revisionMarker,
}

class AyahAnnotation {
  const AyahAnnotation({
    required this.id,
    required this.reference,
    required this.pageNumber,
    required this.type,
    required this.colorValue,
    required this.createdAt,
    this.note,
    this.updatedAt,
  });

  final String id;
  final AyahReference reference;
  final int pageNumber;
  final AyahAnnotationType type;
  final int colorValue;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Color get color => Color(colorValue);

  AyahAnnotation copyWith({
    AyahAnnotationType? type,
    int? colorValue,
    String? note,
    DateTime? updatedAt,
  }) {
    return AyahAnnotation(
      id: id,
      reference: reference,
      pageNumber: pageNumber,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AyahAnnotation.fromMap(Map<String, Object?> map) {
    return AyahAnnotation(
      id: map['id'] as String,
      reference: AyahReference(
        surahNumber: map['surahNumber'] as int,
        ayahNumber: map['ayahNumber'] as int,
      ),
      pageNumber: map['pageNumber'] as int,
      type: AyahAnnotationType.values.byName(map['type'] as String),
      colorValue: map['colorValue'] as int,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: (map['updatedAt'] as String?) == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'surahNumber': reference.surahNumber,
      'ayahNumber': reference.ayahNumber,
      'pageNumber': pageNumber,
      'type': type.name,
      'colorValue': colorValue,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

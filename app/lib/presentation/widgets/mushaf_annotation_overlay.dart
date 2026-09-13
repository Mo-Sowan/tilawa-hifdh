import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:tilawa/domain/entities/ayah_annotation.dart';
import 'package:tilawa/domain/entities/quran_page_mapper.dart';

class MushafAnnotationOverlay extends StatelessWidget {
  const MushafAnnotationOverlay({
    super.key,
    required this.mapping,
    required this.annotations,
    required this.onAyahSelected,
  });

  final MushafPageMapping mapping;
  final List<AyahAnnotation> annotations;
  final ValueChanged<AyahRegion> onAyahSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final transform = PageOverlayTransform.contain(
          viewport: Size(constraints.maxWidth, constraints.maxHeight),
          source: mapping.sourceImageSize,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MushafAnnotationPainter(
                  mapping: mapping,
                  annotations: annotations,
                  transform: transform,
                ),
              ),
            ),
            for (final region in mapping.ayahRegions)
              for (final box in region.boxes)
                Positioned.fromRect(
                  rect: transform.mapRect(box.toRect()),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => onAyahSelected(region),
                    child: const SizedBox.expand(),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class PageOverlayTransform {
  const PageOverlayTransform({
    required this.scale,
    required this.offset,
  });

  final double scale;
  final Offset offset;

  factory PageOverlayTransform.contain({
    required Size viewport,
    required Size source,
  }) {
    final fitted = applyBoxFit(BoxFit.contain, source, viewport);
    final destination = fitted.destination;
    final scale = destination.width / source.width;
    return PageOverlayTransform(
      scale: scale,
      offset: Offset(
        (viewport.width - destination.width) / 2,
        (viewport.height - destination.height) / 2,
      ),
    );
  }

  Rect mapRect(Rect sourceRect) {
    return Rect.fromLTWH(
      offset.dx + sourceRect.left * scale,
      offset.dy + sourceRect.top * scale,
      sourceRect.width * scale,
      sourceRect.height * scale,
    );
  }
}

class _MushafAnnotationPainter extends CustomPainter {
  const _MushafAnnotationPainter({
    required this.mapping,
    required this.annotations,
    required this.transform,
  });

  final MushafPageMapping mapping;
  final List<AyahAnnotation> annotations;
  final PageOverlayTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    final byAyah = {
      for (final annotation in annotations)
        annotation.reference.key: annotation,
    };

    for (final region in mapping.ayahRegions) {
      final annotation = byAyah[region.reference.key];
      if (annotation == null) {
        continue;
      }

      final basePaint = Paint()
        ..color = annotation.color.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = annotation.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      for (final box in region.boxes) {
        final rect = transform.mapRect(box.toRect());
        final radius =
            Radius.circular(ui.lerpDouble(5, 9, transform.scale) ?? 6);
        final rounded = RRect.fromRectAndRadius(rect, radius);
        canvas.drawRRect(rounded, basePaint);
        canvas.drawRRect(rounded, borderPaint);
      }

      if (annotation.type == AyahAnnotationType.bookmark ||
          annotation.type == AyahAnnotationType.revisionMarker) {
        _paintMarker(canvas, region, annotation);
      }
    }
  }

  void _paintMarker(
    Canvas canvas,
    AyahRegion region,
    AyahAnnotation annotation,
  ) {
    if (region.boxes.isEmpty) {
      return;
    }
    final firstRect = transform.mapRect(region.boxes.first.toRect());
    final markerPaint = Paint()..color = annotation.color;
    canvas.drawCircle(
      Offset(firstRect.right + 8, firstRect.center.dy),
      5,
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MushafAnnotationPainter oldDelegate) {
    return oldDelegate.mapping != mapping ||
        oldDelegate.annotations != annotations ||
        oldDelegate.transform != transform;
  }
}

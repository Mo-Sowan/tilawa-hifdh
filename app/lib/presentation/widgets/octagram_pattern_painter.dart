import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Rub el Hizb, tiled — two squares at 45° to each other forming an
/// eight-pointed star, the mark that divides the Mushaf into quarters.
///
/// Drawn procedurally rather than shipped as an image so it stays crisp at any
/// size and costs nothing to bundle. The stars interlock: each sits at the
/// centre of its cell and the ring drawn at the cell corner closes the lattice
/// between four of them, which is what makes the tiling read as one pattern
/// rather than as repeated stamps.
class OctagramPatternPainter extends CustomPainter {
  const OctagramPatternPainter({
    required this.color,
    this.cell = 72,
    this.strokeWidth = 1.2,
  });

  /// Stroke colour. Intended to be very low contrast — this is texture behind
  /// text, and anything assertive competes with what the card is there to say.
  final Color color;

  /// Distance between star centres.
  final double cell;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final radius = cell * 0.34;
    final columns = (size.width / cell).ceil() + 2;
    final rows = (size.height / cell).ceil() + 2;

    for (var row = -1; row < rows; row++) {
      for (var column = -1; column < columns; column++) {
        final centre = Offset(column * cell, row * cell);

        canvas.save();
        canvas.translate(centre.dx, centre.dy);

        // Two squares, the second turned an eighth of a turn: the octagram.
        final square = Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: radius * 2,
        );
        canvas.drawRect(square, stroke);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(square, stroke);
        canvas.rotate(-math.pi / 4);

        // The circle the eight points touch.
        canvas.drawCircle(Offset.zero, radius * math.sqrt2 * 0.72, stroke);

        canvas.restore();

        // The knot where four stars meet, which ties the lattice together.
        canvas.drawCircle(
          centre + Offset(cell / 2, cell / 2),
          radius * 0.28,
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant OctagramPatternPainter oldDelegate) =>
      color != oldDelegate.color ||
      cell != oldDelegate.cell ||
      strokeWidth != oldDelegate.strokeWidth;
}

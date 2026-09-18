import 'dart:math' as math;
import 'package:flutter/material.dart';

class QiblaDial extends CustomPainter {
  const QiblaDial(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);
    for (var i = 0; i < 36; i++) {
      final angle = i * math.pi / 18;
      final vector = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
          center + vector * (radius - 8), center + vector * radius, paint);
    }
    paint.style = PaintingStyle.fill;
    canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - radius + 20)
          ..lineTo(center.dx - 24, center.dy + 30)
          ..lineTo(center.dx, center.dy + 15)
          ..lineTo(center.dx + 24, center.dy + 30)
          ..close(),
        paint);
  }

  @override
  bool shouldRepaint(QiblaDial oldDelegate) => color != oldDelegate.color;
}

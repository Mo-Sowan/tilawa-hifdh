import 'package:flutter/material.dart';

// ─── Islamic Geometric Background Painter ───────────────────────────────────
class IslamicDecorationPainter extends CustomPainter {
  IslamicDecorationPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.3)
      ..style = PaintingStyle.fill;

    const spacing = 60.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    for (int r = -1; r < rows; r++) {
      for (int c = -1; c < cols; c++) {
        // Stagger the grid slightly
        final dx = c * spacing + ((r % 2 == 0) ? 0 : spacing / 2);
        final dy = r * (spacing * 0.866); // Hexagonal stagger

        canvas.save();
        canvas.translate(dx, dy);

        // Draw an 8-pointed star pattern (Rub el Hizb style)
        const radius = 24.0;
        for (int i = 0; i < 2; i++) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: radius, height: radius),
            paint,
          );
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: radius, height: radius),
            fillPaint,
          );
          canvas.rotate(3.14159 / 4); // Rotate 45 degrees
        }

        // Inner circle
        canvas.drawCircle(Offset.zero, radius * 0.3, paint);

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant IslamicDecorationPainter oldDelegate) =>
      color != oldDelegate.color;
}

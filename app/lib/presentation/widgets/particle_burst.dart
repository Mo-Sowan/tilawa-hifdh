import 'dart:math';

import 'package:flutter/material.dart';

/// How a burst of particles moves.
///
/// [explode] throws them outward from where they started — the shape a
/// celebration wants. [rain] drops them from above and [float] lifts them from
/// below, both of which read as ambient rather than as an event.
enum ParticleMode { explode, rain, float }

/// One particle, with the randomness fixed at construction so it moves the
/// same way for the whole animation instead of jittering every  frame.

class Particle {
  Particle(Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        size = rng.nextDouble() * 6 + 2,
        speed = rng.nextDouble() * 0.6 + 0.2,
        angle = rng.nextDouble() * 2 * pi,
        rotationSpeed = (rng.nextDouble() - 0.5) * 4,
        shape = rng.nextInt(4); // 0=circle, 1=star, 2=diamond, 3=rubElHizb

  final double x;
  final double y;
  final double size;
  final double speed;
  final double angle;
  final double rotationSpeed;
  final int shape;
}

/// Draws a burst of [Particle]s, shaped by [ParticleMode].
class ParticlePainter extends CustomPainter {
  ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
    required this.opacity,
    required this.mode,
  });

  final List<Particle> particles;
  final double progress;
  final Color color;
  final double opacity;
  final ParticleMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      double dx = 0;
      double dy = 0;

      if (mode == ParticleMode.explode) {
        dx = p.x * size.width + cos(p.angle) * p.speed * progress * 200;
        dy = p.y * size.height - p.speed * progress * size.height * 0.5 + sin(p.angle) * 30;
      } else if (mode == ParticleMode.rain) {
        dx = p.x * size.width + sin(progress * 10 + p.angle) * 20;
        dy = (p.y * size.height - 200) + progress * p.speed * size.height * 1.5;
      } else if (mode == ParticleMode.float) {
        dx = p.x * size.width + sin(progress * 5 + p.angle) * 40;
        dy = (size.height + 100) - progress * p.speed * size.height * 1.2;
      }

      final fadeOut = (1 - progress).clamp(0, 1).toDouble();
      final alpha = (fadeOut * opacity * 0.8).clamp(0, 1).toDouble();

      final paint = Paint()
        ..color = HSLColor.fromColor(color)
            .withLightness(
              (HSLColor.fromColor(color).lightness + (p.size / 16)).clamp(0, 1),
            )
            .toColor()
            .withValues(alpha: alpha);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotationSpeed * progress * (mode == ParticleMode.explode ? 1 : 3));

      switch (p.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size, paint);
          break;
        case 1:
          _drawStar(canvas, p.size, paint);
          break;
        case 2:
          _drawDiamond(canvas, p.size, paint);
          break;
        default:
          _drawRubElHizb(canvas, p.size, paint);
      }

      canvas.restore();
    }
  }

  void _drawRubElHizb(Canvas canvas, double size, Paint paint) {
    canvas.save();
    final rect = Rect.fromCenter(center: Offset.zero, width: size * 1.5, height: size * 1.5);
    canvas.drawRect(rect, paint);
    canvas.rotate(pi / 4);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  void _drawStar(Canvas canvas, double size, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (i * 4 * pi / 5) - pi / 2;
      final point = Offset(cos(angle) * size, sin(angle) * size);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, double size, Paint paint) {
    final path = Path()
      ..moveTo(0, -size)
      ..lineTo(size * 0.6, 0)
      ..lineTo(0, size)
      ..lineTo(-size * 0.6, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) =>
      progress != oldDelegate.progress || opacity != oldDelegate.opacity;
}

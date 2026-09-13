import 'dart:math';
import 'package:flutter/material.dart';

import 'package:tilawa/presentation/widgets/particle_burst.dart';

enum CelebrationType { planCreated, revisionComplete, encouragement, streak }

class CelebrationOverlay {
  static void show(
    BuildContext context, {
    required CelebrationType type,
    required String title,
    required String subtitle,
    OverlayState? overlayState,
    VoidCallback? onComplete,
  }) {
    final overlay = overlayState ?? Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _CelebrationWidget(
        type: type,
        title: title,
        subtitle: subtitle,
        onDismiss: () {
          entry.remove();
          onComplete?.call();
        },
      ),
    );

    overlay.insert(entry);
  }
}


class _CelebrationWidget extends StatefulWidget {
  const _CelebrationWidget({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.onDismiss,
  });

  final CelebrationType type;
  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _particleController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _subtitleFade;
  late final List<Particle> _particles;

  late final ParticleMode _mode;

  @override
  void initState() {
    super.initState();

    final rng = Random();
    _mode = ParticleMode.values[rng.nextInt(ParticleMode.values.length)];

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.05, 0.4, curve: Curves.elasticOut),
      ),
    );

    _subtitleFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.25, 0.5, curve: Curves.easeIn),
    );

    _particles = List.generate(rng.nextInt(50) + 40, (_) => Particle(rng));

    _mainController.forward();
    _particleController.forward();

    // Auto-dismiss after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        _mainController.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.type) {
      case CelebrationType.planCreated:
        return Icons.auto_awesome_rounded;
      case CelebrationType.revisionComplete:
        return Icons.emoji_events_rounded;
      case CelebrationType.encouragement:
        return Icons.favorite_rounded;
      case CelebrationType.streak:
        return Icons.local_fire_department_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color accentColor;
    List<Color> gradientColors;
    
    switch (widget.type) {
      case CelebrationType.planCreated:
        accentColor = const Color(0xFF00C6FF);
        gradientColors = isDark
            ? [const Color(0xFF00C6FF), const Color(0xFF0072FF), Colors.black]
            : [const Color(0xFF00C6FF), const Color(0xFF0072FF), Colors.white];
        break;
      case CelebrationType.revisionComplete:
        accentColor = const Color(0xFF38EF7D);
        gradientColors = isDark
            ? [const Color(0xFF38EF7D), const Color(0xFF11998E), Colors.black]
            : [const Color(0xFF38EF7D), const Color(0xFF11998E), Colors.white];
        break;
      case CelebrationType.encouragement:
        accentColor = const Color(0xFFFF512F);
        gradientColors = isDark
            ? [const Color(0xFFFF512F), const Color(0xFFF09819), Colors.black]
            : [const Color(0xFFFF512F), const Color(0xFFF09819), Colors.white];
        break;
      case CelebrationType.streak:
        accentColor = const Color(0xFFFF9800);
        gradientColors = isDark
            ? [const Color(0xFFFF9800), const Color(0xFFFF5722), Colors.black]
            : [const Color(0xFFFF9800), const Color(0xFFFF5722), Colors.white];
        break;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _particleController]),
      builder: (context, _) {
        return GestureDetector(
          onTap: () {
            _mainController.reverse().then((_) {
              if (mounted) widget.onDismiss();
            });
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    ...gradientColors.map(
                      (c) => c.withValues(alpha: _fadeIn.value * 0.95),
                    ),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Background Islamic decoration watermark
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: CustomPaint(
                        painter: _IslamicDecorationPainter(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  // Particles
                  CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: ParticlePainter(
                      particles: _particles,
                      progress: _particleController.value,
                      color: accentColor,
                      opacity: _fadeIn.value,
                      mode: _mode,
                    ),
                  ),
                  // Center content
                  Center(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon with glow
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(alpha: 0.15),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.3),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _icon,
                                size: 42,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Title
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: accentColor.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Subtitle
                            FadeTransition(
                              opacity: _subtitleFade,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  widget.subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Islamic Geometric Background Painter ───────────────────────────────────
class _IslamicDecorationPainter extends CustomPainter {
  _IslamicDecorationPainter({required this.color});

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
  bool shouldRepaint(covariant _IslamicDecorationPainter oldDelegate) =>
      color != oldDelegate.color;
}

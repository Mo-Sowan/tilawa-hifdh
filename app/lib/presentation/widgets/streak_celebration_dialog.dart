import 'dart:math';

import 'package:flutter/material.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/widgets/particle_burst.dart';

/// The moment the day's target is met.
///
/// Shown once, when the target is first reached — not on every later review of
/// the same day. Whoever calls this is responsible for that; see
/// `streakCelebrationProvider`.
Future<void> showStreakCelebration(
  BuildContext context, {
  required int streak,
  required AppStrings strings,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.continueLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 650),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, __) {
      // Overshoot and settle. The curve is the celebration: a linear scale
      // would land like any other dialog.
      final scale = CurvedAnimation(parent: animation, curve: Curves.elasticOut);
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.35, curve: Curves.easeOut),
      );

      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: _StreakDialog(streak: streak, strings: strings),
        ),
      );
    },
  );
}

class _StreakDialog extends StatefulWidget {
  const _StreakDialog({required this.streak, required this.strings});

  final int streak;
  final AppStrings strings;

  @override
  State<_StreakDialog> createState() => _StreakDialogState();
}

class _StreakDialogState extends State<_StreakDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  late final List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(70, (_) => Particle(rng));
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = widget.strings;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Thrown behind the card so the card stays readable through it.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (context, _) => CustomPaint(
                    painter: ParticlePainter(
                      particles: _particles,
                      progress: _confetti.value,
                      color: AppColors.amber,
                      opacity: 1,
                      mode: ParticleMode.explode,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.45),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.streakCelebrationTitle(widget.streak),
                    textAlign: TextAlign.center,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                            ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.streakCelebrationBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        strings.continueLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

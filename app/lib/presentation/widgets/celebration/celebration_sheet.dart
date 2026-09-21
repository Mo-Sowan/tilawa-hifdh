import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/widgets/celebration/celebration_tier.dart';
import 'package:tilawa/presentation/widgets/octagram_pattern_painter.dart';
import 'package:tilawa/presentation/widgets/particle_burst.dart';

/// Shows a celebration at the given [tier].
///
/// One entry point for all five moments, from meeting the daily target to
/// finishing the Mushaf. [CelebrationTier] carries everything that differs, so
/// the escalation is a parameter rather than five screens that happen to look
/// related.
///
/// [withSound] is the reciter's preference; the caller reads it rather than
/// this reaching for settings, so the celebration stays a pure widget.
Future<void> showCelebration(
  BuildContext context, {
  required CelebrationTier tier,
  required String title,
  required String body,
  required AppStrings strings,
  bool withSound = true,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.continueLabel,
    barrierColor: Colors.black.withValues(alpha: tier.fullScreen ? 0.86 : 0.55),
    transitionDuration: const Duration(milliseconds: 700),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, __) {
      // Overshoot and settle. The curve is the celebration: a linear scale
      // would land like any other dialog.
      final scale =
          CurvedAnimation(parent: animation, curve: Curves.elasticOut);
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.35, curve: Curves.easeOut),
      );

      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: _CelebrationSheet(
            tier: tier,
            title: title,
            body: body,
            strings: strings,
            withSound: withSound,
          ),
        ),
      );
    },
  );
}

class _CelebrationSheet extends StatefulWidget {
  const _CelebrationSheet({
    required this.tier,
    required this.title,
    required this.body,
    required this.strings,
    required this.withSound,
  });

  final CelebrationTier tier;
  final String title;
  final String body;
  final AppStrings strings;
  final bool withSound;

  @override
  State<_CelebrationSheet> createState() => _CelebrationSheetState();
}

class _CelebrationSheetState extends State<_CelebrationSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  late final List<Particle> _particles;
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(widget.tier.particles, (_) => Particle(rng));
    _burst = AnimationController(vsync: this, duration: widget.tier.duration)
      ..forward();
    _playHaptics();
    if (widget.withSound) _playChime();
  }

  /// Pulses spaced far enough apart to be felt as separate taps.
  Future<void> _playHaptics() async {
    for (final haptic in widget.tier.haptics) {
      if (!mounted) return;
      await haptic.play();
      await Future<void>.delayed(const Duration(milliseconds: 110));
    }
  }

  Future<void> _playChime() async {
    try {
      final player = AudioPlayer();
      _player = player;
      await player.play(AssetSource(
        // AssetSource is rooted at assets/, so the prefix is already implied.
        widget.tier.assetPath.replaceFirst('assets/', ''),
      ));
    } catch (error) {
      // No audio route, a device with sound disabled, or a platform without
      // the plugin. The celebration is still a celebration without it.
      debugPrint('Could not play the celebration chime: $error');
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = widget.tier;

    final card = Container(
      margin: EdgeInsets.symmetric(horizontal: tier.fullScreen ? 24 : 32),
      padding: EdgeInsets.fromLTRB(28, tier.fullScreen ? 40 : 32, 28, 24),
      constraints: BoxConstraints(maxWidth: tier.fullScreen ? 460 : 360),
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The bigger moments earn the geometry behind them.
          if (tier.fullScreen)
            Positioned.fill(
              child: CustomPaint(
                painter: OctagramPatternPainter(
                  color: AppColors.amber.withValues(alpha: 0.07),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                      fontSize: tier.fullScreen ? 30 : null,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.body,
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
                    widget.strings.continueLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

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
                  animation: _burst,
                  builder: (context, _) => CustomPaint(
                    painter: ParticlePainter(
                      particles: _particles,
                      progress: _burst.value,
                      color: AppColors.amber,
                      opacity: 1,
                      mode: ParticleMode.explode,
                    ),
                  ),
                ),
              ),
            ),
            card,
          ],
        ),
      ),
    );
  }
}

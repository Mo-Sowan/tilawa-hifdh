import 'package:flutter/services.dart';

/// How big a moment this is.
///
/// One scale rather than five separate celebrations. Every parameter below
/// rises monotonically across the tiers, so completing the Quran is felt as
/// more than a daily streak because it literally is the same celebration
/// turned up — longer, louder, more of the screen, more particles. Five
/// bespoke animations would have made the difference a matter of taste, and
/// nothing would guarantee the biggest moment looked biggest.
enum CelebrationTier {
  /// Today's target met. Frequent, so deliberately modest — this fires most
  /// days and anything grander would wear out fast.
  dailyStreak(
    sound: 'streak',
    particles: 60,
    durationMs: 2200,
    fullScreen: false,
    haptics: [HapticKind.medium],
  ),

  quarter(
    sound: 'quarter',
    particles: 120,
    durationMs: 3200,
    fullScreen: true,
    haptics: [HapticKind.medium, HapticKind.heavy],
  ),

  half(
    sound: 'half',
    particles: 180,
    durationMs: 3800,
    fullScreen: true,
    haptics: [HapticKind.medium, HapticKind.heavy, HapticKind.heavy],
  ),

  threeQuarters(
    sound: 'three_quarters',
    particles: 240,
    durationMs: 4400,
    fullScreen: true,
    haptics: [
      HapticKind.medium,
      HapticKind.heavy,
      HapticKind.heavy,
      HapticKind.heavy,
    ],
  ),

  /// The whole Mushaf. Once in a lifetime for most reciters, so it is allowed
  /// to take over the screen and take its time.
  whole(
    sound: 'whole',
    particles: 320,
    durationMs: 6000,
    fullScreen: true,
    haptics: [
      HapticKind.heavy,
      HapticKind.heavy,
      HapticKind.heavy,
      HapticKind.heavy,
      HapticKind.heavy,
    ],
  );

  const CelebrationTier({
    required this.sound,
    required this.particles,
    required this.durationMs,
    required this.fullScreen,
    required this.haptics,
  });

  /// Basename of the chime under `assets/sounds/`.
  final String sound;

  final int particles;
  final int durationMs;

  /// Whether the celebration covers the screen or sits as a card.
  final bool fullScreen;

  /// Pulses played in sequence as the celebration opens.
  final List<HapticKind> haptics;

  String get assetPath => 'assets/sounds/$sound.wav';

  Duration get duration => Duration(milliseconds: durationMs);
}

/// The strength of one haptic pulse.
///
/// Named rather than calling [HapticFeedback] directly so a tier can describe
/// its pattern as data and the player stays in one place.
enum HapticKind {
  light,
  medium,
  heavy;

  Future<void> play() {
    switch (this) {
      case HapticKind.light:
        return HapticFeedback.lightImpact();
      case HapticKind.medium:
        return HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        return HapticFeedback.heavyImpact();
    }
  }
}

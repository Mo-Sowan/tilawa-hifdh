import 'package:flutter/material.dart';
import 'package:tilawa/recitation/service/recitation_engine.dart';
import 'package:tilawa/recitation/presentation/recitation_providers.dart';
import 'package:tilawa/recitation/presentation/widgets/status_strip.dart';

/// Model download progress, listening state and errors in one strip.
class RecitationStatusBar extends StatelessWidget {
  const RecitationStatusBar({
    super.key,
    required this.status,
    required this.session,
    required this.isArabic,
  });

  final EngineStatus status;
  final RecitationSessionState session;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = session.error ??
        (status.state == EngineState.failed ? status.message : null);

    if (status.state == EngineState.unsupported) {
      return StatusStrip(
        icon: Icons.info_outline_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        label: status.message ??
            (isArabic
                ? 'التعرّف الصوتي غير متاح في هذا الإصدار.'
                : 'Voice recognition is unavailable in this build.'),
      );
    }

    if (error != null) {
      return StatusStrip(
        icon: Icons.error_outline_rounded,
        color: theme.colorScheme.error,
        label: error,
      );
    }

    if (status.state == EngineState.preparing) {
      final percent = status.progress;
      return StatusStrip(
        icon: Icons.downloading_rounded,
        color: theme.colorScheme.primary,
        label: percent == null
            ? (status.message ??
                (isArabic ? 'جارٍ التحضير...' : 'Preparing...'))
            : '${status.message ?? (isArabic ? 'جارٍ التنزيل' : 'Downloading')}'
                ' ${(percent * 100).round()}%',
        progress: percent,
      );
    }

    if (session.isListening) {
      final covered = session.covered.length;
      return StatusStrip(
        icon: Icons.graphic_eq_rounded,
        color: theme.colorScheme.primary,
        label: isArabic
            ? 'يستمع — $covered آية'
            : 'Listening — $covered ${covered == 1 ? 'ayah' : 'ayat'} matched',
      );
    }

    return StatusStrip(
      icon: Icons.mic_none_rounded,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      label: isArabic
          ? 'اضغط على المِيكروفون لبدء المتابعة'
          : 'Tap the microphone to follow along',
    );
  }
}

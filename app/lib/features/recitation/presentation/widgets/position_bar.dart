import 'package:flutter/material.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/features/recitation/presentation/recitation_providers.dart';

/// Where the reciter is and how far into the ayah, in one strip.
class PositionBar extends StatelessWidget {
  const PositionBar({super.key, required this.session, required this.strings});

  final RecitationSessionState session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final current = session.current;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: session.verseProgress,
              minHeight: 4,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            current == null
                ? strings.reciteFromMemoryHint
                : '${strings.ayahPosition(current.surah, current.ayah)}'
                    ' · ${strings.ayatThisSession(session.covered.length)}',
            style: TextStyle(
              fontSize: 12,
              color: current == null ? muted : scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

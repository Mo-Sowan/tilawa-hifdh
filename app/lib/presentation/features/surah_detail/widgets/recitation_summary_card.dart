import 'package:flutter/material.dart';

/// What the offline recogniser observed during the live recitation.
///
/// Deliberately separate from the recall slider: recognition confidence says
/// how clearly the audio matched the verse, not how well the reciter knows it.
class RecitationSummaryCard extends StatelessWidget {
  const RecitationSummaryCard({super.key, 
    required this.versesRecited,
    required this.confidence,
    required this.isArabic,
  });

  final int versesRecited;
  final double confidence;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (confidence * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'متابعة التلاوة' : 'Recitation follow-along',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'تم التعرف على $versesRecited آية بدقة $percent%'
                      : '$versesRecited ayat recognised, $percent% mean confidence',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

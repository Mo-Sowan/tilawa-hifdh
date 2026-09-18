import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';

class ConfidenceSelector extends ConsumerWidget {
  const ConfidenceSelector({super.key, 
    required this.value,
    required this.onChanged,
  });

  final int value; // 1 to 10
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            strings.howWellDidYouDo,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          // Large emoji and text representing current selected level
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                strings.assessmentEmoji(value),
                style: const TextStyle(fontSize: 42),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${strings.score}: $value / 10',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    strings.assessmentLabel(value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              valueIndicatorColor: theme.colorScheme.primary,
              valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              showValueIndicator: ShowValueIndicator.onDrag,
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1.0,
              max: 10.0,
              divisions: 9,
              label: value.toString(),
              onChanged: (val) {
                onChanged(val.round());
              },
            ),
          ),
          // Show 1 and 10 labels at the ends
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 (${strings.level1})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                ),
                Text(
                  '10 (${strings.level10})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

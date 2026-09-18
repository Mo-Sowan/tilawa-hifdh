import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/activity_day.dart';

/// One day in the grid.
class HeatCell extends StatelessWidget {
  const HeatCell({super.key, required this.day, required this.isDark});

  final ActivityDay day;
  final bool isDark;

  /// The five tiers, as opacity of the primary colour.
  static const List<double> tierOpacity = [0.0, 0.25, 0.5, 0.75, 1.0];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = day.heatTier;
    final fill = tier == 0
        ? scheme.surfaceContainerHighest
        : scheme.primary.withValues(alpha: tierOpacity[tier]);

    // Readable against the fill: the darker tiers need light text.
    final onFill = tier >= 3
        ? Colors.black
        : (isDark ? AppColors.textMuted : AppColors.lightTextMuted);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tier == 0
              ? scheme.outline
              : scheme.primary.withValues(alpha: .45),
        ),
      ),
      alignment: Alignment.center,
      child: day.hasActivity
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: onFill,
                ),
                Text(
                  '${day.date.day}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: onFill,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                ),
              ],
            )
          : Text(
              '${day.date.day}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: onFill,
                    fontWeight: FontWeight.w900,
                  ),
            ),
    );
  }
}

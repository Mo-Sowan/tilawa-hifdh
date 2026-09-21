import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/activity_day.dart';

/// One day in the grid.
class HeatCell extends StatelessWidget {
  const HeatCell({super.key, required this.day, required this.isDark});

  final ActivityDay day;
  final bool isDark;

  /// The five tiers, as opacity of the primary colour.
  ///
  /// Opacity alone made the low tiers wash out to almost nothing against the
  /// card, so a day of real work looked like an empty one. The scale now
  /// starts higher and the colour warms as it climbs — the same idea as the
  /// streak flame, so the two read as one language.
  static const List<double> tierOpacity = [0.0, 0.45, 0.65, 0.85, 1.0];

  /// The fill for a tier: emerald at the bottom of the scale, warming through
  /// amber to the ember at the top.
  static Color fillFor(BuildContext context, int tier) {
    final scheme = Theme.of(context).colorScheme;
    if (tier == 0) return scheme.surfaceContainerHighest;

    final base = switch (tier) {
      1 => scheme.primary,
      2 => Color.lerp(scheme.primary, AppColors.streakCool, 0.45)!,
      3 => AppColors.streakWarm,
      _ => AppColors.streakHot,
    };
    return base.withValues(alpha: tierOpacity[tier]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = day.heatTier;
    final fill = fillFor(context, tier);

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

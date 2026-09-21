import 'package:flutter/material.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/presentation/features/progress/widgets/heat_cell.dart';

/// The "less ... more" key under the grid.
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key, required this.strings, required this.muted});

  final AppStrings strings;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: muted);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(strings.heatmapLess, style: style),
        const SizedBox(width: 6),
        for (var tier = 0; tier < HeatCell.tierOpacity.length; tier++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: HeatCell.fillFor(context, tier),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: tier == 0
                    ? scheme.outline
                    : scheme.primary.withValues(alpha: .45),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(strings.heatmapMore, style: style),
      ],
    );
  }
}

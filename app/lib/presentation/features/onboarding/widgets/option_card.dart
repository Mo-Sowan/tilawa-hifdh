import 'package:flutter/material.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/profiling_option.dart';

class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.option});

  final ProfilingOption option;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = option.selected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.7),
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: option.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w600,
                          color: selected ? scheme.primary : scheme.onSurface,
                        ),
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tilawa/core/localization/app_strings.dart';

/// Progress bar and the way out.
class ProfilingHeader extends StatelessWidget {
  const ProfilingHeader({super.key, 
    required this.step,
    required this.stepCount,
    required this.strings,
    required this.onSkip,
  });

  final int step;
  final int stepCount;
  final AppStrings strings;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                strings.profilingStep(step + 1, stepCount),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                child: Text(strings.profilingSkip),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (step + 1) / stepCount),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

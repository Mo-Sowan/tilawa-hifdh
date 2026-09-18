import 'package:flutter/material.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/animated_in.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/option_card.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/profiling_option.dart';

/// One question and its answers.
class QuestionPage extends StatelessWidget {
  const QuestionPage({super.key, 
    required this.title,
    required this.hint,
    required this.options,
    this.showContinue = false,
    this.onContinue,
    this.continueLabel,
  });

  final String title;
  final String hint;
  final List<ProfilingOption> options;
  final bool showContinue;
  final VoidCallback? onContinue;
  final String? continueLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < options.length; i++) ...[
            // Staggered so the answers arrive rather than appearing all at once.
            AnimatedIn(
              delay: Duration(milliseconds: 60 * i),
              child: OptionCard(option: options[i]),
            ),
            const SizedBox(height: 12),
          ],
          if (showContinue) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                continueLabel ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

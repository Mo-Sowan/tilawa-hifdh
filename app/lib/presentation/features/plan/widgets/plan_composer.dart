import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/plan/widgets/composer_metric.dart';

class PlanComposer extends StatelessWidget {
  const PlanComposer({
    super.key,
    required this.nameController,
    required this.selectedSurahs,
    required this.reminderTime,
    required this.onReminderChanged,
    required this.onShowSelected,
  });

  final TextEditingController nameController;
  final Set<int> selectedSurahs;
  final TimeOfDay reminderTime;
  final ValueChanged<TimeOfDay> onReminderChanged;
  final VoidCallback onShowSelected;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final labels = ref.watch(appStringsProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? AppColors.outline : AppColors.lightOutline)
                  .withValues(alpha: .7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _StepNumber(number: 1),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels.planDetails,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: labels.planName,
                  hintText: labels.defaultPlanName,
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ComposerMetric(
                      icon: Icons.bookmark_added_rounded,
                      label: labels.selectedCount(selectedSurahs.length),
                      // Tapping the count is the obvious way to ask "which
                      // ones?", so it filters the list below to exactly those.
                      onTap: selectedSurahs.isEmpty ? null : onShowSelected,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: reminderTime,
                        );
                        if (picked != null) {
                          onReminderChanged(picked);
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(reminderTime.format(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

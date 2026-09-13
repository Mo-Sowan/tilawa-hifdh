import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/providers/main_tab_provider.dart';

class ReminderBanner extends ConsumerWidget {
  const ReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final plan = ref.watch(activeRevisionPlanProvider);
    if (plan == null) {
      return _ReminderShell(
        color: Theme.of(context).colorScheme.secondary,
        icon: Icons.notification_add_outlined,
        text: strings.noPlanYet,
        trailing: strings.createPlan,
        onTap: () {
          ref.read(mainTabProvider.notifier).state = 1; // 1 is PlanView
        },
      );
    }

    final time =
        DateFormat('h:mm a', strings.currentLanguage.locale.languageCode)
            .format(plan.reminderTime);
    final due = plan.hasSurahs && plan.isDue;
    final color = due ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary;

    return _ReminderShell(
      color: color,
      icon: due ? Icons.notifications_active_rounded : Icons.schedule_rounded,
      text: due ? strings.reminderReady : strings.reminderAt(time),
      trailing: strings.selectedCount(plan.surahNumbers.length),
      onTap: () {
        ref.read(mainTabProvider.notifier).state = 1; // 1 is PlanView
      },
    );
  }
}

class _ReminderShell extends StatelessWidget {
  const _ReminderShell({
    required this.color,
    required this.icon,
    required this.text,
    required this.trailing,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String text;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Text(
            trailing,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      ),
    );
  }
}

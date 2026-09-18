import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/plan_preferences.dart';
import 'package:tilawa/presentation/providers/reciter_profile_provider.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/widgets/celebration_overlay.dart';
import 'package:tilawa/presentation/features/plan/plan_detail_view.dart';
import 'package:tilawa/presentation/features/plan/widgets/plan_composer.dart';
import 'package:tilawa/presentation/features/plan/widgets/surah_picker.dart';
import 'package:tilawa/presentation/features/plan/widgets/existing_plan_card.dart';
import 'package:tilawa/presentation/features/plan/widgets/empty_plan_card.dart';

class PlanView extends ConsumerStatefulWidget {
  const PlanView({super.key});

  @override
  ConsumerState<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends ConsumerState<PlanView> {
  // Left empty on purpose. The field carries a localized hint and, if the
  // reciter never types one, the plan is named in their own language when it
  // is created — an English placeholder was showing up in Arabic plans.
  final TextEditingController _nameController = TextEditingController();
  final Set<int> _selectedSurahs = {};
  bool _defaultsApplied = false;
  bool _isCreating = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);

  /// Set when the reciter asks to see what they have chosen, so the picker can
  /// switch to its "selected" filter from outside.
  int _showSelectedRequest = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final overview = ref.watch(revisionOverviewProvider);
    final profile = ref.watch(reciterProfileProvider);
    if (!_defaultsApplied &&
        profile.valueOrNull != null &&
        overview.valueOrNull != null) {
      _selectedSurahs.addAll(PlanPreferences.defaultSelection(
          profile.valueOrNull!, overview.valueOrNull!));
      _defaultsApplied = true;
    }
    final maxSurahs = PlanPreferences.maxSurahs(profile.valueOrNull?.extent);
    final plans = ref.watch(revisionPlansProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text(
            strings.planRevision,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            strings.planHint,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 18),
          _PlanHowItWorks(strings: strings),
          const SizedBox(height: 24),
          Text(
            strings.activePlans,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          plans.when(
            data: (items) => Column(
              children: [
                if (items.isEmpty)
                  EmptyPlanCard(message: strings.noPlanYet)
                else
                  for (final plan in items) ...[
                    ExistingPlanCard(plan: plan),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Unable to load plans: $error'),
          ),
          const SizedBox(height: 28),
          Text(
            strings.createNewPlan,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          PlanComposer(
            nameController: _nameController,
            selectedSurahs: _selectedSurahs,
            reminderTime: _reminderTime,
            onReminderChanged: (value) => setState(() => _reminderTime = value),
            onShowSelected: () => setState(() => _showSelectedRequest++),
          ),
          const SizedBox(height: 20),
          _PlanStepHeading(
            number: 2,
            title: strings.choosePlanSurahs,
            subtitle: strings.isArabic
                ? '${_selectedSurahs.length} من $maxSurahs مختارة. يمكنك تعديل الاختيار المقترح.'
                : '${_selectedSurahs.length} of $maxSurahs selected. You can change the suggestion.',
          ),
          const SizedBox(height: 12),
          overview.when(
            data: (surahs) => SurahPicker(
              surahs: surahs,
              selected: _selectedSurahs,
              showSelectedRequest: _showSelectedRequest,
              onToggle: (number) {
                _defaultsApplied = true;
                if (!_selectedSurahs.contains(number) &&
                    _selectedSurahs.length >= maxSurahs) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(strings.isArabic
                          ? 'الحد الأقصى لهذه الخطة $maxSurahs سور'
                          : 'This plan can contain up to $maxSurahs surahs.')));
                  return;
                }
                setState(() {
                  if (!_selectedSurahs.add(number)) {
                    _selectedSurahs.remove(number);
                  }
                });
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
          ),
          const SizedBox(height: 20),
          _CreatePlanFooter(
            selectedCount: _selectedSurahs.length,
            title: strings.planReadyToCreate,
            buttonLabel:
                _isCreating ? strings.creatingPlan : strings.createPlan,
            isCreating: _isCreating,
            onCreate:
                _selectedSurahs.isEmpty || _isCreating ? null : _createPlan,
          ),
        ],
      ),
    );
  }

  Future<void> _createPlan() async {
    if (_isCreating) return;
    final strings = ref.read(appStringsProvider);
    final now = DateTime.now();
    var reminder = DateTime(
      now.year,
      now.month,
      now.day,
      _reminderTime.hour,
      _reminderTime.minute,
    );
    if (reminder.isBefore(now)) {
      reminder = reminder.add(const Duration(days: 1));
    }

    if (_selectedSurahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.pickAtLeastOneSurah)),
      );
      return;
    }

    final maximum = PlanPreferences.maxSurahs(
        ref.read(reciterProfileProvider).valueOrNull?.extent);
    if (_selectedSurahs.length > maximum) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(strings.isArabic
              ? 'اختر $maximum سور أو أقل'
              : 'Select $maximum surahs or fewer.')));
      return;
    }

    setState(() => _isCreating = true);
    try {
      await ref.read(revisionPlansProvider.notifier).createPlan(
            name: _nameController.text.trim().isEmpty
                ? strings.defaultPlanName
                : _nameController.text.trim(),
            surahNumbers: _selectedSurahs,
            reminderTime: reminder,
            isActive: true,
          );
      final result = ref.read(revisionPlansProvider);
      if (result.hasError) throw result.error!;
      if (!mounted) return;

      CelebrationOverlay.show(
        context,
        type: CelebrationType.planCreated,
        title: strings.planCreatedTitle,
        subtitle: strings.planCreatedSubtitle,
      );

      // A plan the reciter cannot see is a plan they will not follow, so open
      // it rather than leaving them on the composer wondering what happened.
      final created = result.valueOrNull?.lastOrNull;
      if (created == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlanDetailView(plan: created)),
      );

      if (!mounted) return;
      setState(() {
        _selectedSurahs.clear();
        _nameController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.planCreateFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}

class _PlanHowItWorks extends StatelessWidget {
  const _PlanHowItWorks({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final steps = [
      (Icons.library_add_check_rounded, strings.planStepChoose),
      (Icons.notifications_active_outlined, strings.planStepRemind),
      (Icons.play_circle_outline_rounded, strings.planStepRevise),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.howPlansWork,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(steps[i].$1, size: 19, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${i + 1}. ${steps[i].$2}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (i != steps.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PlanStepHeading extends StatelessWidget {
  const _PlanStepHeading({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CreatePlanFooter extends StatelessWidget {
  const _CreatePlanFooter({
    required this.selectedCount,
    required this.title,
    required this.buttonLabel,
    required this.isCreating,
    required this.onCreate,
  });

  final int selectedCount;
  final String title;
  final String buttonLabel;
  final bool isCreating;
  final Future<void> Function()? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlanStepHeading(number: 3, title: title, subtitle: ''),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_task_rounded),
            label: Text('$buttonLabel · $selectedCount'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ],
      ),
    );
  }
}

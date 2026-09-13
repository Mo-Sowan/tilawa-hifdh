import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/recitation/engine/arabic_normalizer.dart';
import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/domain/entities/plan_preferences.dart';
import 'package:tilawa/presentation/providers/reciter_profile_provider.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/data/quran/surah_catalog.dart';
import 'package:tilawa/presentation/widgets/celebration_overlay.dart';
import 'package:tilawa/presentation/views/plan_detail_view.dart';

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
                  _EmptyPlanCard(message: strings.noPlanYet)
                else
                  for (final plan in items) ...[
                    _ExistingPlanCard(plan: plan),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Unable to load plans: $error'),
          ),
          const SizedBox(height: 22),
          _PlanComposer(
            nameController: _nameController,
            selectedSurahs: _selectedSurahs,
            reminderTime: _reminderTime,
            onReminderChanged: (value) => setState(() => _reminderTime = value),
            onCreate: _createPlan,
            onShowSelected: () => setState(() => _showSelectedRequest++),
          ),
          const SizedBox(height: 8),
          Text(strings.isArabic
              ? 'حتى $maxSurahs سور لكل خطة. يمكنك تعديل الاختيار المقترح.'
              : 'Up to $maxSurahs surahs per plan. You can change the suggested selection.'),
          const SizedBox(height: 18),
          overview.when(
            data: (surahs) => _SurahPicker(
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
        ],
      ),
    );
  }

  Future<void> _createPlan() async {
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

    await ref.read(revisionPlansProvider.notifier).createPlan(
          name: _nameController.text.trim().isEmpty
              ? strings.defaultPlanName
              : _nameController.text.trim(),
          surahNumbers: _selectedSurahs,
          reminderTime: reminder,
          isActive: true,
        );

    if (!mounted) return;

    CelebrationOverlay.show(
      context,
      type: CelebrationType.planCreated,
      title: strings.planCreatedTitle,
      subtitle: strings.planCreatedSubtitle,
    );

    // A plan the reciter cannot see is a plan they will not follow, so open it
    // rather than leaving them on the composer wondering what happened.
    final created = ref.read(revisionPlansProvider).valueOrNull?.lastOrNull;
    if (created == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlanDetailView(plan: created)),
    );

    if (!mounted) return;
    setState(() {
      _selectedSurahs.clear();
      _nameController.clear();
    });
  }
}

class _PlanComposer extends StatelessWidget {
  const _PlanComposer({
    required this.nameController,
    required this.selectedSurahs,
    required this.reminderTime,
    required this.onReminderChanged,
    required this.onCreate,
    required this.onShowSelected,
  });

  final TextEditingController nameController;
  final Set<int> selectedSurahs;
  final TimeOfDay reminderTime;
  final ValueChanged<TimeOfDay> onReminderChanged;
  final Future<void> Function() onCreate;
  final VoidCallback onShowSelected;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final labels = ref.watch(appStringsProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.outline : AppColors.lightOutline,
            ),
          ),
          child: Column(
            children: [
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
                    child: _ComposerMetric(
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: selectedSurahs.isEmpty ? null : onCreate,
                icon: const Icon(Icons.add_task_rounded),
                label: Text(labels.createPlan),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComposerMetric extends StatelessWidget {
  const _ComposerMetric({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primary.withValues(alpha: .24)),
        ),
        child: Row(
          children: [
            Icon(icon, color: primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: primary),
          ],
        ),
      ),
    );
  }
}

class _SurahPicker extends ConsumerStatefulWidget {
  const _SurahPicker({
    required this.surahs,
    required this.selected,
    required this.onToggle,
    required this.showSelectedRequest,
  });

  /// Bumped by the composer when the reciter asks to see what they picked.

  final List<SurahRevision> surahs;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final int showSelectedRequest;

  @override
  ConsumerState<_SurahPicker> createState() => _SurahPickerState();
}

class _SurahPickerState extends ConsumerState<_SurahPicker> {
  String _searchQuery = '';
  String _activeFilter =
      'all'; // 'all', 'juz30', 'weakest', 'strongest', 'unrevised', 'meccan', 'medinan', 'selected'
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isExpanded =
              ref.read(appSettingsProvider).showSurahListExpandedDefault;
        });
      }
    });
  }

  @override
  void didUpdateWidget(_SurahPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSelectedRequest != oldWidget.showSelectedRequest) {
      setState(() {
        _activeFilter = 'selected';
        _searchQuery = '';
        _isExpanded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final surface = Theme.of(context).colorScheme.surface;

    final query = _searchQuery.trim();
    final normalizedQuery = normalizeArabic(query).toLowerCase();

    final filteredSurahs = widget.surahs.where((surah) {
      if (!_matchesSearch(surah, query, normalizedQuery)) return false;

      switch (_activeFilter) {
        case 'juz30':
          return surah.juzNumber == 30;
        case 'weakest':
          return surah.isWeak;
        case 'strongest':
          return surah.isAssessed && surah.mastery >= 0.8;
        case 'unrevised':
          return !surah.isAssessed;
        case 'meccan':
          return _isMeccanSurah(surah.number);
        case 'medinan':
          return !_isMeccanSurah(surah.number);
        case 'selected':
          return widget.selected.contains(surah.number);
        default:
          return true;
      }
    }).toList();

    // Both bands only contain surahs with a history, so ordering by mastery is
    // meaningful here in a way it would not be across the whole list.
    if (_activeFilter == 'weakest') {
      filteredSurahs.sort((a, b) => a.mastery.compareTo(b.mastery));
    } else if (_activeFilter == 'strongest') {
      filteredSurahs.sort((a, b) => b.mastery.compareTo(a.mastery));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
              if (val.isNotEmpty) _isExpanded = true;
            });
          },
          decoration: InputDecoration(
            hintText: strings.searchSurah,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', strings.filterAll),
              const SizedBox(width: 8),
              _buildFilterChip('juz30', strings.filterJuz30),
              const SizedBox(width: 8),
              _buildFilterChip('weakest', strings.filterWeakest),
              const SizedBox(width: 8),
              _buildFilterChip('strongest', strings.filterStrongest),
              const SizedBox(width: 8),
              _buildFilterChip('unrevised', strings.filterUnrevised),
              const SizedBox(width: 8),
              _buildFilterChip('meccan', strings.filterMeccan),
              const SizedBox(width: 8),
              _buildFilterChip('medinan', strings.filterMedinan),
              const SizedBox(width: 8),
              _buildFilterChip('selected',
                  '${strings.filterSelected} (${widget.selected.length})'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        if (!_isExpanded)
          InkWell(
            onTap: () => setState(() => _isExpanded = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                    color: isDark ? AppColors.outline : AppColors.lightOutline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${strings.showSurahList} (${filteredSurahs.length})',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _isExpanded = false),
                icon: const Icon(Icons.expand_less_rounded, size: 18),
                label: Text(strings.hideSurahList,
                    style: const TextStyle(fontSize: 12)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      for (final s in filteredSurahs) {
                        if (!widget.selected.contains(s.number)) {
                          widget.onToggle(s.number);
                        }
                      }
                    },
                    icon: const Icon(Icons.select_all_rounded, size: 18),
                    label: Text(strings.selectAll,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      for (final s in filteredSurahs) {
                        if (widget.selected.contains(s.number)) {
                          widget.onToggle(s.number);
                        }
                      }
                    },
                    icon: const Icon(Icons.deselect_rounded, size: 18),
                    label: Text(strings.deselectAll,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final weakNumbers = widget.surahs
                          .where((s) => s.isWeak)
                          .map((s) => s.number)
                          .toSet();
                      for (final num in weakNumbers) {
                        if (!widget.selected.contains(num)) {
                          widget.onToggle(num);
                        }
                      }
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: Text(strings.selectWeakest,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSurahs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final surah = filteredSurahs[index];
              final isChecked = widget.selected.contains(surah.number);

              final isMecca = _isMeccanSurah(surah.number);
              final typeLabel = strings.isArabic
                  ? (isMecca ? strings.filterMeccan : strings.filterMedinan)
                  : (isMecca ? 'Meccan' : 'Medinan');
              final typeColor = isMecca
                  ? Theme.of(context).colorScheme.secondary
                  : AppColors.blue;
              final accent = surah.isWeak
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary;

              return InkWell(
                onTap: () => widget.onToggle(surah.number),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .06)
                        : surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isChecked
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .5)
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              value: surah.masteryOrNull ?? 0,
                              strokeWidth: 3.5,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                          Text(
                            '${surah.number}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  strings.isArabic
                                      ? surah.arabicName
                                      : surah.englishName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${surah.ayahCount} ${strings.ayat}',
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    typeLabel,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  strings.juzNumbered(surah.juzNumber),
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isChecked
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isChecked
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: isChecked
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _activeFilter == filter;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activeFilter = filter;
            _isExpanded = true;
          });
        }
      },
      selectedColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: .22),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? (isDark ? Colors.white : Colors.black87)
            : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
      ),
    );
  }

  /// Whether a surah answers to what was typed.
  ///
  /// Arabic names carry full vowelling — سُورَةُ ٱلْفَاتِحَة — so a reader typing
  /// الفاتحة matched nothing at all before. Both sides are put through the same
  /// normalization the recogniser uses, which strips the marks and folds the
  /// alif and hamza variants, so the search works the way it is typed.
  ///
  /// Numbers match as a prefix: typing 11 should offer 11, 110 and 111, not
  /// only surah 11.
  bool _matchesSearch(SurahRevision surah, String query, String normalized) {
    if (query.isEmpty) return true;

    final lower = query.toLowerCase();
    if (surah.englishName.toLowerCase().contains(lower)) return true;
    if (normalized.isNotEmpty &&
        normalizeArabic(surah.arabicName).contains(normalized)) {
      return true;
    }
    if (surah.number.toString().startsWith(query)) return true;

    final digits = RegExp(r'\d+').firstMatch(query)?.group(0);
    if (digits != null && surah.juzNumber.toString() == digits) {
      final withoutDigits =
          normalizeArabic(query.replaceAll(digits, '')).trim().toLowerCase();
      if (withoutDigits.isEmpty ||
          'juz'.startsWith(withoutDigits) ||
          normalizeArabic('الجزء').contains(withoutDigits)) {
        return true;
      }
    }
    return false;
  }

  bool _isMeccanSurah(int number) {
    try {
      return SurahCatalog.getPlaceOfRevelation(number) == 'Mecca';
    } catch (e) {
      return true;
    }
  }
}

class _ExistingPlanCard extends ConsumerWidget {
  const _ExistingPlanCard({required this.plan});

  final RevisionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final time =
        DateFormat('h:mm a', strings.currentLanguage.locale.languageCode)
            .format(plan.reminderTime);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlanDetailView(plan: plan),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_note_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${strings.selectedCount(plan.surahNumbers.length)} - ${strings.reminderAt(time)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () {
                ref.read(revisionPlansProvider.notifier).deletePlan(plan.id);
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

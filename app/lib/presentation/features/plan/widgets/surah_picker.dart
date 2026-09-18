import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/recitation/engine/arabic_normalizer.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/data/quran/surah_catalog.dart';

class SurahPicker extends ConsumerStatefulWidget {
  const SurahPicker({
    super.key,
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
  ConsumerState<SurahPicker> createState() => SurahPickerState();
}

class SurahPickerState extends ConsumerState<SurahPicker> {
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
  void didUpdateWidget(SurahPicker oldWidget) {
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
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 2,
                runSpacing: 2,
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

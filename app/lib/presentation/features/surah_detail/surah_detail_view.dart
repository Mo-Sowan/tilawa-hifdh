import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/domain/entities/revision_section.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/main_tab_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/providers/revision_session_provider.dart';
import 'package:tilawa/presentation/widgets/celebration_overlay.dart';
import 'package:tilawa/presentation/features/mushaf/mushaf_reader_view.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/presentation/features/surah_detail/widgets/assessment_feedback.dart';
import 'package:tilawa/presentation/features/surah_detail/widgets/hasanat_card.dart';
import 'package:tilawa/presentation/features/surah_detail/widgets/metric_row.dart';
import 'package:tilawa/presentation/features/surah_detail/widgets/confidence_selector.dart';
import 'package:tilawa/presentation/features/surah_detail/widgets/recitation_summary_card.dart';
import 'package:tilawa/presentation/features/surah_detail/widgets/section_sheet.dart';

class SurahDetailView extends ConsumerStatefulWidget {
  const SurahDetailView({
    required this.surah,
    this.preRecordedDuration,
    this.mushafOpenCount = 0,
    this.versesRecited = 0,
    this.recitedRefs = const [],
    this.recitationConfidence = 0,
    super.key,
  });

  final SurahRevision surah;

  /// Time already spent on the live recitation screen, so the assessment
  /// timer continues rather than restarting.
  final Duration? preRecordedDuration;
  final int mushafOpenCount;

  /// Ayat the offline recogniser matched during the recitation, and its mean
  /// confidence in those matches. Shown as context; the recall estimate stays
  /// the reciter's own judgement.
  final int versesRecited;

  /// Which verses were matched, as `surah:ayah`. Needed to count the letters
  /// actually recited rather than guessing from a verse count.
  final List<String> recitedRefs;

  final double recitationConfidence;

  @override
  ConsumerState<SurahDetailView> createState() => _SurahDetailViewState();
}

class _SurahDetailViewState extends ConsumerState<SurahDetailView> {
  /// Index of the progress tab in [MainView]'s navigation bar.
  static const int _progressTab = 2;

  int _confidence = 5;
  bool _isSaving = false;
  bool _saved = false;
  final Stopwatch _stopwatch = Stopwatch();
  late int _mushafOpenCount;

  /// Which part of the surah was revised, as a stable key. Null when the
  /// reciter did not say, which is the common case and a valid answer.
  String? _section;

  @override
  void initState() {
    super.initState();
    _mushafOpenCount = widget.mushafOpenCount;
    // If a pre-recorded duration exists (from memory recitation), we offset
    // the stopwatch display but still track assessment time separately.
    _stopwatch.start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final plan = ref.watch(activeRevisionPlanProvider);
    final planned = plan?.surahNumbers.contains(widget.surah.number) ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isSaving) return;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                  strings.isArabic ? 'إنهاء المراجعة؟' : 'Leave Revision?'),
              content: Text(
                strings.isArabic
                    ? 'هل أنت متأكد أنك تريد مغادرة المراجعة؟ لن يتم حفظ تقدمك الحالي.'
                    : 'Are you sure you want to leave? Your current progress will not be saved.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.isArabic ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.rose),
                  child: Text(strings.isArabic ? 'مغادرة' : 'Leave'),
                ),
              ],
            );
          },
        );

        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.isArabic
              ? widget.surah.arabicName
              : widget.surah.englishName),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.surah.arabicName,
                      textAlign: TextAlign.center,
                      style: AppTheme.arabicText(
                        size: 44,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.surahInfo(
                          widget.surah.number, widget.surah.ayahCount),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 22),
                    MetricRow(
                      label: strings.mastery,
                      value: widget.surah.revisionCount == 0
                          ? '-'
                          : '${(widget.surah.mastery * 100).round()}%',
                      color: widget.surah.revisionCount == 0
                          ? muted
                          : (widget.surah.mastery < 0.5
                              ? AppColors.rose
                              : (widget.surah.mastery < 0.8
                                  ? AppColors.amber
                                  : AppColors.emerald)),
                    ),
                    if (RevisionSection.describe(
                      widget.surah.lastRevisionSection,
                      isArabic: strings.isArabic,
                      ayahCount: widget.surah.ayahCount,
                    ).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      MetricRow(
                        label: strings.lastRevisedSection,
                        value: RevisionSection.describe(
                          widget.surah.lastRevisionSection,
                          isArabic: strings.isArabic,
                          ayahCount: widget.surah.ayahCount,
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                    const SizedBox(height: 10),
                    MetricRow(
                      label: strings.mistakes,
                      value: widget.surah.revisionCount == 0
                          ? '-'
                          : '${(widget.surah.mistakeRate * 100).round()}%',
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                ),
              ),
              if (widget.preRecordedDuration != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.timer_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 6),
                          Text(
                            strings.isArabic
                                ? 'وقت التسميع'
                                : 'Recitation Time',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDuration(widget.preRecordedDuration!),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                      ),
                      Column(
                        children: [
                          Icon(Icons.menu_book_rounded,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 6),
                          Text(
                            strings.isArabic ? 'فتح المصحف' : 'Mushaf Opened',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.isArabic
                                ? '$_mushafOpenCount ${_mushafOpenCount == 1 ? "مرة" : "مرات"}'
                                : '$_mushafOpenCount ${_mushafOpenCount == 1 ? "time" : "times"}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.versesRecited > 0) ...[
                const SizedBox(height: 18),
                RecitationSummaryCard(
                  versesRecited: widget.versesRecited,
                  confidence: widget.recitationConfidence,
                  isArabic: strings.isArabic,
                ),
              ],
              if (widget.recitedRefs.isNotEmpty) ...[
                const SizedBox(height: 18),
                HasanatCard(refs: widget.recitedRefs),
              ],
              const SizedBox(height: 18),
              Text(
                strings.estimateRecall,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.assessmentUsageExplanation,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: muted,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConfidenceSelector(
                value: _confidence,
                onChanged: (value) {
                  if (!_isSaving && !_saved) {
                    setState(() => _confidence = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              _SectionField(
                surah: widget.surah,
                selected: _section,
                enabled: !_isSaving && !_saved,
                onChanged: (value) => setState(() => _section = value),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('save-assessment'),
                onPressed: _isSaving || _saved
                    ? null
                    : () async {
                        // Lock before the first await: a second tap can arrive before the button rebuilds.
                        if (_isSaving || _saved) return;
                        setState(() => _isSaving = true);
                        try {
                          _stopwatch.stop();

                          // Read persistent previous confidence
                          final previousConfidence = ref.read(
                              lastConfidenceProvider)[widget.surah.number];

                          // Check if completing this Surah finishes the active plan for today
                          bool isPlanCompleted = false;
                          if (planned && plan != null) {
                            final allSurahs = ref
                                    .read(revisionOverviewProvider)
                                    .valueOrNull ??
                                [];
                            final sessions = ref.read(revisionSessionsProvider);
                            final now = DateTime.now();

                            bool allOthersDone = true;
                            for (final num in plan.surahNumbers) {
                              if (num == widget.surah.number) continue;

                              // Checked if revised in current sessions today
                              final hasSessionToday = sessions.any((s) =>
                                  s.surahNumber == num &&
                                  s.timestamp.year == now.year &&
                                  s.timestamp.month == now.month &&
                                  s.timestamp.day == now.day);
                              if (hasSessionToday) continue;

                              // Or if database shows reviewed today
                              final surahObj = allSurahs.firstWhere(
                                (s) => s.number == num,
                                orElse: () => widget.surah,
                              );
                              final lr = surahObj.lastReviewed;
                              final isReviewedToday = lr != null &&
                                  lr.year == now.year &&
                                  lr.month == now.month &&
                                  lr.day == now.day;
                              if (!isReviewedToday) {
                                allOthersDone = false;
                                break;
                              }
                            }
                            if (allOthersDone) {
                              isPlanCompleted = true;
                            }
                          }

                          // Determine feedback text/type
                          CelebrationType celebrationType;
                          String overlayTitle;
                          String overlaySubtitle;

                          if (isPlanCompleted) {
                            celebrationType = CelebrationType.revisionComplete;
                            overlayTitle = strings.planCompletedTitle;
                            overlaySubtitle = strings.planCompletedSubtitle;
                          } else {
                            final feedback = _feedbackForAssessment(
                              previousConfidence: previousConfidence,
                              currentConfidence: _confidence,
                              strings: strings,
                            );
                            celebrationType = feedback.type;
                            overlayTitle = feedback.title;
                            overlaySubtitle = feedback.subtitle;
                          }

                          final sessionDuration = _stopwatch.elapsed +
                              (widget.preRecordedDuration ?? Duration.zero);
                          await ref.read(submitSelfAssessmentProvider).call(
                                widget.surah.number,
                                _confidence,
                                sessionDuration.inSeconds,
                                _section,
                                _mushafOpenCount,
                              );

                          // History represents confirmed writes, not attempted submissions.
                          _saved = true;
                          if (!mounted) return;
                          ref
                              .read(revisionSessionsProvider.notifier)
                              .addSession(
                                surahNumber: widget.surah.number,
                                surahName: strings.isArabic
                                    ? widget.surah.arabicName
                                    : widget.surah.englishName,
                                duration: sessionDuration,
                                confidence: _confidence,
                              );
                          await ref
                              .read(lastConfidenceProvider.notifier)
                              .setConfidence(widget.surah.number, _confidence);
                          if (!mounted) return;

                          // Read before the invalidation, so "was this their first?" is
                          // asked of the state as it stood before this review landed.
                          final wasFirstEver = (ref
                                      .read(progressSummaryProvider)
                                      .valueOrNull
                                      ?.calendar ??
                                  const [])
                              .every((day) => !day.hasActivity);

                          ref.invalidate(revisionOverviewProvider);
                          ref.invalidate(weakestSurahProvider);
                          ref.invalidate(progressSummaryProvider);

                          if (context.mounted) {
                            final overlayState = Overlay.of(context);
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);

                            // The first revision is the one worth showing off: send them
                            // to the calendar so they see the day they started light up.
                            if (wasFirstEver) {
                              ref.read(mainTabProvider.notifier).state =
                                  _progressTab;
                            }

                            CelebrationOverlay.show(
                              context,
                              type: celebrationType,
                              title: overlayTitle,
                              subtitle: overlaySubtitle,
                              overlayState: overlayState,
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                              _saved
                                  ? (strings.isArabic
                                      ? 'تم الحفظ. افتح التقدم لعرض المراجعة.'
                                      : 'Saved. Open Progress to see your review.')
                                  : (strings.isArabic
                                      ? 'تعذر الحفظ. حاول مرة أخرى.'
                                      : 'Could not save. Please try again.'),
                            )));
                          }
                          if (!_saved) _stopwatch.start();
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fact_check_rounded),
                label: Text(_isSaving
                    ? (strings.isArabic ? 'جارٍ الحفظ…' : 'Saving…')
                    : strings.saveEstimate),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isSaving || _saved
                    ? null
                    : () {
                        setState(() {
                          _mushafOpenCount++;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MushafReaderView(
                              initialPage: ref
                                      .read(quranTextIndexProvider)
                                      .valueOrNull
                                      ?.surahMeta(widget.surah.number)
                                      ?.startPage ??
                                  1,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.menu_book_rounded),
                label: Text(strings.readFromMushaf),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  AssessmentFeedback _feedbackForAssessment({
    required int? previousConfidence,
    required int currentConfidence,
    required AppStrings strings,
  }) {
    if (previousConfidence != null && currentConfidence > previousConfidence) {
      return AssessmentFeedback(
        type: CelebrationType.revisionComplete,
        title: strings.beautifulImprovementTitle,
        subtitle: strings.beautifulImprovementSubtitle(
            previousConfidence, currentConfidence),
      );
    }

    if (previousConfidence != null && currentConfidence < previousConfidence) {
      return AssessmentFeedback(
        type: CelebrationType.encouragement,
        title: strings.scoreDropTitle,
        subtitle: strings.scoreDropSubtitle,
      );
    }

    return AssessmentFeedback(
      type: CelebrationType.revisionComplete,
      title: strings.revisionSavedTitle,
      subtitle: previousConfidence == null
          ? strings.firstEstimateSavedSubtitle
          : strings.revisionSavedSubtitle,
    );
  }
}

/// The control that opens the section sheet, showing what is currently chosen.
class _SectionField extends ConsumerWidget {
  const _SectionField({
    required this.surah,
    required this.selected,
    required this.onChanged,
    required this.enabled,
  });

  final SurahRevision surah;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final chosen = RevisionSection.describe(
      selected,
      isArabic: strings.isArabic,
      ayahCount: surah.ayahCount,
    );

    return InkWell(
      onTap: enabled
          ? () async {
              final value = await showSectionSheet(
                context,
                strings: strings,
                ayahCount: surah.ayahCount,
                selected: selected,
              );
              onChanged(value);
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.format_list_numbered_rtl, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    strings.revisedSectionOptional,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    chosen.isEmpty ? strings.chooseSection : chosen,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: chosen.isEmpty
                          ? scheme.onSurface.withValues(alpha: 0.5)
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

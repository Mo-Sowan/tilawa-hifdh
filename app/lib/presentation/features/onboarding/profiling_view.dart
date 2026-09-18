import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/domain/entities/reciter_profile.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/reciter_profile_provider.dart';
import 'package:tilawa/presentation/widgets/octagram_pattern_painter.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/profiling_header.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/profiling_option.dart';
import 'package:tilawa/presentation/features/onboarding/widgets/question_page.dart';

/// Four questions, asked once, that decide what the app offers.
///
/// Each answer is written as it is given rather than at the end, so a flow
/// abandoned halfway still leaves the app better informed than it was. Only
/// the last step marks the questionnaire complete, which is what stops it
/// being asked again.
class ProfilingView extends ConsumerStatefulWidget {
  const ProfilingView({required this.onFinished, super.key});

  /// Called once the reciter is through — or has skipped.
  final VoidCallback onFinished;

  @override
  ConsumerState<ProfilingView> createState() => _ProfilingViewState();
}

class _ProfilingViewState extends ConsumerState<ProfilingView> {
  static const int _stepCount = 4;

  final PageController _controller = PageController();
  int _step = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (_step >= _stepCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await ref.read(reciterProfileProvider.notifier).complete();
    if (!mounted) return;
    widget.onFinished();
  }

  /// A selection is a small commitment; the tap should feel like one.
  void _select(void Function() apply) {
    HapticFeedback.selectionClick();
    apply();
    // Let the tick land before moving on, so the choice is visibly registered.
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _advance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(reciterProfileProvider).valueOrNull ??
        const ReciterProfile();
    final notifier = ref.read(reciterProfileProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: OctagramPatternPainter(
                color: scheme.primary.withValues(alpha: 0.05),
                cell: 96,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                ProfilingHeader(
                  step: _step,
                  stepCount: _stepCount,
                  strings: strings,
                  onSkip: _finish,
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) => setState(() => _step = index),
                    children: [
                      QuestionPage(
                        title: strings.profilingQ1,
                        hint: strings.profilingQ1Hint,
                        options: [
                          for (final extent in MemorisationExtent.values)
                            ProfilingOption(
                              label: _extentLabel(extent, strings),
                              selected: profile.extent == extent,
                              onTap: () => _select(
                                () => notifier.update(
                                  (p) => p.copyWith(extent: extent),
                                ),
                              ),
                            ),
                        ],
                      ),
                      QuestionPage(
                        title: strings.profilingQ2,
                        hint: strings.profilingQ2Hint,
                        options: [
                          for (final value in MemorisationDifficulty.values)
                            ProfilingOption(
                              label: _difficultyLabel(value, strings),
                              selected: profile.difficulty == value,
                              onTap: () => _select(
                                () => notifier.update(
                                  (p) => p.copyWith(difficulty: value),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // The only question that takes more than one answer, so
                      // it does not advance on tap — the reciter says when.
                      QuestionPage(
                        title: strings.profilingQ3,
                        hint: strings.profilingQ3Hint,
                        showContinue: true,
                        onContinue: _advance,
                        continueLabel: strings.profilingNext,
                        options: [
                          for (final value in FrequentlyRecited.values)
                            ProfilingOption(
                              label: _recitedLabel(value, strings),
                              selected:
                                  profile.frequentlyRecited.contains(value),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                final next = {...profile.frequentlyRecited};
                                if (!next.add(value)) next.remove(value);
                                notifier.update(
                                  (p) => p.copyWith(frequentlyRecited: next),
                                );
                              },
                            ),
                        ],
                      ),
                      QuestionPage(
                        title: strings.profilingQ4,
                        hint: strings.profilingQ4Hint,
                        options: [
                          for (final value in RevisionGoal.values)
                            ProfilingOption(
                              label: _goalLabel(value, strings),
                              selected: profile.goal == value,
                              onTap: () => _select(
                                () => notifier.update(
                                  (p) => p.copyWith(goal: value),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _extentLabel(MemorisationExtent value, AppStrings strings) =>
      switch (value) {
        MemorisationExtent.justStarting => strings.extentJustStarting,
        MemorisationExtent.upToFiveJuz => strings.extentFiveJuz,
        MemorisationExtent.halfTheQuran => strings.extentHalf,
        MemorisationExtent.entireQuran => strings.extentWhole,
      };

  static String _difficultyLabel(
    MemorisationDifficulty value,
    AppStrings strings,
  ) =>
      switch (value) {
        MemorisationDifficulty.longSurahs => strings.difficultyLongSurahs,
        MemorisationDifficulty.mutashabihat => strings.difficultyMutashabihat,
        MemorisationDifficulty.stayingConsistent =>
          strings.difficultyConsistency,
        MemorisationDifficulty.motivation => strings.difficultyMotivation,
      };

  static String _recitedLabel(FrequentlyRecited value, AppStrings strings) =>
      switch (value) {
        FrequentlyRecited.alKahf => strings.recitedAlKahf,
        FrequentlyRecited.yaseen => strings.recitedYaseen,
        FrequentlyRecited.alMulk => strings.recitedAlMulk,
        FrequentlyRecited.juzAmma => strings.recitedJuzAmma,
      };

  static String _goalLabel(RevisionGoal value, AppStrings strings) =>
      switch (value) {
        RevisionGoal.buildDailyHabit => strings.goalHabit,
        RevisionGoal.retainMemorised => strings.goalRetain,
        RevisionGoal.memoriseNew => strings.goalMemoriseNew,
        RevisionGoal.prepareForTests => strings.goalTests,
      };
}

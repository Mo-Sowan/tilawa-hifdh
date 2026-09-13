import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/domain/entities/reciter_profile.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/reciter_profile_provider.dart';
import 'package:tilawa/presentation/widgets/octagram_pattern_painter.dart';

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
                _ProfilingHeader(
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
                      _QuestionPage(
                        title: strings.profilingQ1,
                        hint: strings.profilingQ1Hint,
                        options: [
                          for (final extent in MemorisationExtent.values)
                            _Option(
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
                      _QuestionPage(
                        title: strings.profilingQ2,
                        hint: strings.profilingQ2Hint,
                        options: [
                          for (final value in MemorisationDifficulty.values)
                            _Option(
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
                      _QuestionPage(
                        title: strings.profilingQ3,
                        hint: strings.profilingQ3Hint,
                        showContinue: true,
                        onContinue: _advance,
                        continueLabel: strings.profilingNext,
                        options: [
                          for (final value in FrequentlyRecited.values)
                            _Option(
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
                      _QuestionPage(
                        title: strings.profilingQ4,
                        hint: strings.profilingQ4Hint,
                        options: [
                          for (final value in RevisionGoal.values)
                            _Option(
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

/// Progress bar and the way out.
class _ProfilingHeader extends StatelessWidget {
  const _ProfilingHeader({
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

class _Option {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// One question and its answers.
class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.title,
    required this.hint,
    required this.options,
    this.showContinue = false,
    this.onContinue,
    this.continueLabel,
  });

  final String title;
  final String hint;
  final List<_Option> options;
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
            _AnimatedIn(
              delay: Duration(milliseconds: 60 * i),
              child: _OptionCard(option: options[i]),
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option});

  final _Option option;

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

/// Fades and lifts its child in after [delay].
class _AnimatedIn extends StatefulWidget {
  const _AnimatedIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_AnimatedIn> createState() => _AnimatedInState();
}

class _AnimatedInState extends State<_AnimatedIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      offset: _shown ? Offset.zero : const Offset(0, 0.18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 360),
        opacity: _shown ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

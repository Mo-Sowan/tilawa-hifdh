import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/daily_progress_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/widgets/active_revision_card.dart';
import 'package:tilawa/presentation/widgets/reminder_banner.dart';
import 'package:tilawa/presentation/widgets/octagram_pattern_painter.dart';
import 'package:tilawa/presentation/widgets/status_bar.dart';
import 'package:tilawa/presentation/widgets/tarteel_surah_navigator.dart';
import 'package:tilawa/presentation/widgets/responsive_pair.dart';
import 'package:tilawa/recitation/presentation/live_recitation_view.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
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
  Widget build(BuildContext context) {
    final overview = ref.watch(revisionOverviewProvider);
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return SafeArea(
      child: overview.when(
        data: (surahs) => ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppStatusBar(),
                  const SizedBox(height: 14),
                  const ReminderBanner(),
                  const SizedBox(height: 18),
                  ActiveRevisionCard(
                    onStart: () {
                      final target = ref.read(weakestSurahProvider).valueOrNull;
                      if (target == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LiveRecitationView(surah: target),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ResponsivePair(
                      first: _QuranCompletionCard(surahs: surahs),
                      second: const _DailyGoalProgressCard()),
                  const SizedBox(height: 16),
                  const _DailyWisdomCard(),
                  const SizedBox(height: 18),
                  _DueTodayList(surahs: surahs),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.revisionPath,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.revisionPathSubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_isExpanded)
                    InkWell(
                      onTap: () => setState(() => _isExpanded = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${strings.showSurahList} (114)',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _isExpanded = false),
                        icon: const Icon(Icons.expand_less_rounded, size: 18),
                        label: Text(strings.hideSurahList,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    strings.quranDataNotice,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_isExpanded)
              TarteelSurahNavigator(
                surahs: surahs,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onOpenSurah: (surah) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveRecitationView(surah: surah),
                    ),
                  );
                },
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load path: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}

// ─── Quran Completion Percentage Card ────────────────────────────────────────
class _QuranCompletionCard extends ConsumerWidget {
  const _QuranCompletionCard({required this.surahs});
  final List<SurahRevision> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviewed = surahs.where((s) => s.revisionCount > 0).length;
    final total = surahs.length;
    final percent = total == 0 ? 0.0 : reviewed / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0D2818),
                  const Color(0xFF1A3A2A),
                  const Color(0xFF0D2818)
                ]
              : [
                  const Color(0xFFE8F5E9),
                  const Color(0xFFC8E6C9),
                  const Color(0xFFE8F5E9)
                ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(percent * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.quranCompletion,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.surahCount(reviewed, total),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.lightTextMuted,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.ofQuran,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Wisdom Card ──────────────────────────────────────────────────────

/// One saying, with where it came from.
class _Wisdom {
  const _Wisdom({
    required this.arabic,
    required this.english,
    required this.reference,
    required this.isQuran,
  });

  final String arabic;
  final String english;
  final String reference;

  /// Quran or Sunnah, shown as a badge so the two are never conflated.
  final bool isQuran;
}

/// The daily wisdom carousel.
///
/// Wraps in both directions — reaching the last saying and swiping on lands
/// back at the first rather than stopping dead — and can be advanced by tapping
/// the card or the arrow. Auto-rotation is a preference and always yields to a
/// deliberate swipe or tap.
class _DailyWisdomCard extends ConsumerStatefulWidget {
  const _DailyWisdomCard();

  @override
  ConsumerState<_DailyWisdomCard> createState() => _DailyWisdomCardState();
}

class _DailyWisdomCardState extends ConsumerState<_DailyWisdomCard> {
  /// The wrap is faked by starting deep inside a very long page list and
  /// indexing into the sayings with a modulo, so there is no edge to hit in
  /// either direction.
  static const int _virtualPageCount = 100000;
  static const Duration _rotateEvery = Duration(seconds: 8);

  late final PageController _pageController;
  late final int _initialPage;
  Timer? _timer;
  int _page = 0;

  static const List<_Wisdom> _wisdoms = [
    _Wisdom(
      arabic: 'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ',
      english:
          'And We have indeed made the Quran easy to understand and remember.',
      reference: 'القمر ٥٤:١٧',
      isQuran: true,
    ),
    _Wisdom(
      arabic: 'إِنَّا نَحْنُ نَزَّلْنَا الذِّكْرَ وَإِنَّا لَهُ لَحَافِظُونَ',
      english:
          'Indeed, it is We who sent down the Quran and We will be its guardian.',
      reference: 'الحجر ١٥:٩',
      isQuran: true,
    ),
    _Wisdom(
      arabic: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      english: 'The best of you are those who learn the Quran and teach it.',
      reference: 'صحيح البخاري',
      isQuran: false,
    ),
    _Wisdom(
      arabic:
          'اقْرَؤُوا القُرْآنَ فإنَّه يَأْتي يَومَ القِيامَةِ شَفِيعًا لأَصْحابِهِ',
      english:
          'Read the Quran, for it will come as an intercessor for its companions.',
      reference: 'صحيح مسلم',
      isQuran: false,
    ),
    _Wisdom(
      arabic:
          'بَلْ هُوَ آيَاتٌ بَيِّنَاتٌ فِي صُدُورِ الَّذِينَ أُوتُوا الْعِلْمَ',
      english:
          'Rather, it is distinct verses preserved in the breasts of those given knowledge.',
      reference: 'العنكبوت ٢٩:٤٩',
      isQuran: true,
    ),
    _Wisdom(
      arabic:
          'الَّذِينَ آتَيْنَاهُمُ الْكِتَابَ يَتْلُونَهُ حَقَّ تِلاوَتِهِ أُولَئِكَ يُؤْمِنُونَ بِهِ',
      english:
          'Those to whom We have given the Book recite it with its true recital. They believe in it.',
      reference: 'البقرة ٢:١٢١',
      isQuran: true,
    ),
    _Wisdom(
      arabic:
          'إِنَّ الَّذِينَ يَتْلُونَ كِتَابَ اللَّهِ وَأَقَامُوا الصَّلاةَ وَأَنفَقُوا مِمَّا رَزَقْنَاهُمْ سِرًّا وَعَلانِيَةً يَرْجُونَ تِجَارَةً لَّن تَبُورَ',
      english:
          'Those who recite the Book of Allah and establish prayer hope for a transaction that will never fail.',
      reference: 'فاطر ٣٥:٢٩',
      isQuran: true,
    ),
    _Wisdom(
      arabic:
          'مَن قَرَأ حَرْفًا مِن كِتابِ اللَّهِ فَلَهُ بهِ حَسَنَةٌ، والحَسَنَةُ بِعَشْرِ أمثالِها',
      english:
          'Whoever reads a letter from the Book of Allah, he will have a reward, and the reward will be multiplied tenfold.',
      reference: 'الترمذي',
      isQuran: false,
    ),
    _Wisdom(
      arabic:
          'يُقالُ لصاحِبِ القُرآنِ: اقرأْ وارتقِ ورتِّلْ كما كُنتَ تُرتِّلُ في الدُّنيا',
      english:
          'It will be said to the companion of the Quran: Read, ascend, and recite as you used to.',
      reference: 'أبو داود والترمذي',
      isQuran: false,
    ),
    _Wisdom(
      arabic: 'الْمَاهِرُ بِالْقُرْآنِ مَعَ السَّفَرَةِ الْكِرَامِ الْبَرَرَةِ',
      english:
          'The one who is proficient in the Quran will be with the noble righteous scribes.',
      reference: 'صحيح البخاري ومسلم',
      isQuran: false,
    ),
    _Wisdom(
      arabic:
          'تَعَاهَدُوا هذا القُرآنَ، فَوَالَّذي نَفْسُ مُحَمَّدٍ بيَدِهِ لَهُوَ أشَدُّ تَفَلُّتًا مِنَ الإبِلِ في عُقُلِها',
      english:
          "Keep revisiting the Quran, for by the One in whose Hand is Muhammad's soul, it escapes faster than camels from their ropes.",
      reference: 'متفق عليه',
      isQuran: false,
    ),
    _Wisdom(
      arabic:
          'اللَّهُمَّ اجْعَلِ الْقُرْآنَ رَبِيعَ قَلْبِي وَنُورَ صَدْرِي وَجَلَاءَ حُزْنِي وَذَهَابَ هَمِّي',
      english:
          'O Allah, make the Quran the spring of my heart and the light of my chest.',
      reference: 'أحمد',
      isQuran: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Open somewhere new each time the app is launched. The seed is stored on
    // the device and advanced once per launch, so this is genuinely different
    // words rather than the same saying until the date changes.
    final seed = ref.read(appSettingsProvider).wisdomSeed;
    _initialPage = (_virtualPageCount ~/ 2) -
        ((_virtualPageCount ~/ 2) % _wisdoms.length) +
        (seed % _wisdoms.length);
    _page = _initialPage;
    _pageController = PageController(initialPage: _initialPage);
    _restartTimer();
  }

  /// Settings load asynchronously, so the seed can land just after the first
  /// build. Move to it when it does, rather than always opening on the first
  /// saying on a cold start.
  void _applySeed(int seed) {
    if (!mounted || !_pageController.hasClients) return;
    final target = (_virtualPageCount ~/ 2) -
        ((_virtualPageCount ~/ 2) % _wisdoms.length) +
        (seed % _wisdoms.length);
    if (target == _page) return;
    _pageController.jumpToPage(target);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!ref.read(appSettingsProvider).dailyWisdomAutoRotate) return;
    _timer = Timer.periodic(_rotateEvery, (_) => _advance(animate: true));
  }

  void _advance({required bool animate}) {
    if (!mounted || !_pageController.hasClients) return;
    // Always forward by one, so wrapping never animates backwards through the
    // whole list the way `jumpTo(0)` would.
    _pageController.nextPage(
      duration: Duration(milliseconds: animate ? 450 : 1),
      curve: Curves.easeOutCubic,
    );
  }

  /// A deliberate interaction takes priority: the auto-rotation clock restarts
  /// so the card does not move again a moment later.
  void _onUserAdvance() {
    _advance(animate: true);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;

    // Re-arm whenever the preference flips.
    ref.listen(
      appSettingsProvider.select((s) => s.dailyWisdomAutoRotate),
      (_, __) => _restartTimer(),
    );
    ref.listen(
      appSettingsProvider.select((s) => s.wisdomSeed),
      (_, seed) => _applySeed(seed),
    );

    final activeIndex = _page % _wisdoms.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              strings.dailyMotivation,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _onUserAdvance,
              tooltip: strings.wisdomNext,
              visualDensity: VisualDensity.compact,
              // A sparkle, not a reload: this offers another saying rather
              // than fetching the same one again.
              icon: Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _page = index);
              _restartTimer();
            },
            itemBuilder: (context, index) {
              final wisdom = _wisdoms[index % _wisdoms.length];

              return _WisdomPage(
                wisdom: wisdom,
                isArabic: strings.isArabic,
                badge: wisdom.isQuran
                    ? strings.wisdomFromQuran
                    : strings.wisdomFromSunnah,
                controller: _pageController,
                pageIndex: index,
                onTap: _onUserAdvance,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_wisdoms.length, (i) {
            final selected = i == activeIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: selected ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: selected
                    ? scheme.primary
                    : scheme.outline.withValues(alpha: 0.6),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// One card in the wisdom carousel.
/// One card in the wisdom carousel.
///
/// A single deep emerald identity rather than a different gradient per saying:
/// the words are the subject, and rotating the colour made the card read as
/// decoration that happened to contain text.
class _WisdomPage extends StatelessWidget {
  const _WisdomPage({
    required this.wisdom,
    required this.isArabic,
    required this.badge,
    required this.controller,
    required this.pageIndex,
    required this.onTap,
  });

  final _Wisdom wisdom;
  final bool isArabic;
  final String badge;
  final PageController controller;
  final int pageIndex;
  final VoidCallback onTap;

  /// Asymmetric stops: the dark end holds most of the card and the lighter one
  /// lifts a corner, which gives the flat rectangle some direction.
  static const Color _deep = Color(0xFF0F3935);
  static const Color _light = Color(0xFF1E6B5C);

  @override
  Widget build(BuildContext context) {
    // Cards behind the current one sit back slightly, which reads as depth
    // while swiping and makes the wrap feel continuous.
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        var distance = 0.0;
        if (controller.position.haveDimensions) {
          distance = ((controller.page ?? pageIndex.toDouble()) - pageIndex)
              .abs()
              .clamp(0.0, 1.0);
        }
        return Transform.scale(
          scale: 1 - (distance * 0.06),
          child: Opacity(opacity: 1 - (distance * 0.35), child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_deep, _light],
              stops: [0.35, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _deep.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: OctagramPatternPainter(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              // Oversized quote mark, anchored to the reading side.
              PositionedDirectional(
                top: 4,
                start: 12,
                child: Text(
                  '\u201C',
                  style: TextStyle(
                    fontSize: 76,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.amber.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _WisdomBadge(label: badge),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            isArabic ? wisdom.arabic : wisdom.english,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: isArabic
                                ? AppTheme.arabicText(
                                    size: 21,
                                    color: Colors.white,
                                  ).copyWith(fontWeight: FontWeight.w700)
                                : const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.45,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // The source sits where an attribution belongs: last, to
                      // the trailing side, and set apart by being italic.
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          wisdom.reference,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WisdomBadge extends StatelessWidget {
  const _WisdomBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.amber,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Daily Goal Progress Card (Time-based) ──────────────────────────────────
class _DailyGoalProgressCard extends ConsumerWidget {
  const _DailyGoalProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(dailyProgressProvider);

    if (progress.isEmpty) {
      return _GoalShell(
        title: strings.planProgressTitle,
        child: Text(
          strings.planProgressEmpty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      );
    }

    final done = progress.percentComplete;
    final left = progress.percentRemaining;

    return _GoalShell(
      title: progress.isPlanBased
          ? strings.planProgressTitle
          : strings.dailyGoalSetting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The two halves of the same fact, side by side: what is done reads
          // as the achievement, what is left reads as the ask.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$done%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      height: 1,
                    ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  strings
                      .percentCompleted(done)
                      .replaceFirst('$done%', '')
                      .trim(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  strings.percentRemaining(left),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 16,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progress.isPlanBased
                ? strings.planProgress(
                    progress.completedUnits, progress.totalUnits)
                : strings.goalProgress(
                    progress.completedUnits, progress.totalUnits),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// The card the progress figure sits in.
class _GoalShell extends StatelessWidget {
  const _GoalShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── Due Today List (Sorted Weakest → Strongest) ────────────────────────────
class _DueTodayList extends ConsumerWidget {
  const _DueTodayList({required this.surahs});

  final List<SurahRevision> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final dueSurahs = surahs.where((s) => s.isDueToday).toList()
      ..sort((a, b) => a.number.compareTo(b.number)); // ascending order
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.dueSurahs,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: dueSurahs.isEmpty
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .15)
                    : Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: .15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${dueSurahs.length} ${strings.dueTodayCount}',
                style: TextStyle(
                  color: dueSurahs.isEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dueSurahs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.noDueSurahs,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dueSurahs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final surah = dueSurahs[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LiveRecitationView(surah: surah),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 168,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: .3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          strings.isArabic
                              ? surah.arabicName
                              : surah.englishName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.surahInfo(surah.number, surah.ayahCount),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          surah.isAssessed
                              ? strings
                                  .masteryPercent((surah.mastery * 100).round())
                              : strings.masteryUnknown,
                          style: TextStyle(
                            color: surah.isAssessed
                                ? Theme.of(context).colorScheme.error
                                : muted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

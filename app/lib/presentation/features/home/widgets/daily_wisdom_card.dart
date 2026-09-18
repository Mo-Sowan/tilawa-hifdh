import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/home/widgets/wisdom.dart';
import 'package:tilawa/presentation/features/home/widgets/wisdom_page.dart';

/// The daily wisdom carousel.
///
/// Wraps in both directions — reaching the last saying and swiping on lands
/// back at the first rather than stopping dead — and can be advanced by tapping
/// the card or the arrow. Auto-rotation is a preference and always yields to a
/// deliberate swipe or tap.
class DailyWisdomCard extends ConsumerStatefulWidget {
  const DailyWisdomCard({super.key});

  @override
  ConsumerState<DailyWisdomCard> createState() => DailyWisdomCardState();
}

class DailyWisdomCardState extends ConsumerState<DailyWisdomCard> {
  /// The wrap is faked by starting deep inside a very long page list and
  /// indexing into the sayings with a modulo, so there is no edge to hit in
  /// either direction.
  static const int _virtualPageCount = 100000;
  static const Duration _rotateEvery = Duration(seconds: 8);

  late final PageController _pageController;
  late final int _initialPage;
  Timer? _timer;
  int _page = 0;

  static const List<Wisdom> _wisdoms = [
    Wisdom(
      arabic: 'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ',
      english:
          'And We have indeed made the Quran easy to understand and remember.',
      reference: 'القمر ٥٤:١٧',
      isQuran: true,
    ),
    Wisdom(
      arabic: 'إِنَّا نَحْنُ نَزَّلْنَا الذِّكْرَ وَإِنَّا لَهُ لَحَافِظُونَ',
      english:
          'Indeed, it is We who sent down the Quran and We will be its guardian.',
      reference: 'الحجر ١٥:٩',
      isQuran: true,
    ),
    Wisdom(
      arabic: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      english: 'The best of you are those who learn the Quran and teach it.',
      reference: 'صحيح البخاري',
      isQuran: false,
    ),
    Wisdom(
      arabic:
          'اقْرَؤُوا القُرْآنَ فإنَّه يَأْتي يَومَ القِيامَةِ شَفِيعًا لأَصْحابِهِ',
      english:
          'Read the Quran, for it will come as an intercessor for its companions.',
      reference: 'صحيح مسلم',
      isQuran: false,
    ),
    Wisdom(
      arabic:
          'بَلْ هُوَ آيَاتٌ بَيِّنَاتٌ فِي صُدُورِ الَّذِينَ أُوتُوا الْعِلْمَ',
      english:
          'Rather, it is distinct verses preserved in the breasts of those given knowledge.',
      reference: 'العنكبوت ٢٩:٤٩',
      isQuran: true,
    ),
    Wisdom(
      arabic:
          'الَّذِينَ آتَيْنَاهُمُ الْكِتَابَ يَتْلُونَهُ حَقَّ تِلاوَتِهِ أُولَئِكَ يُؤْمِنُونَ بِهِ',
      english:
          'Those to whom We have given the Book recite it with its true recital. They believe in it.',
      reference: 'البقرة ٢:١٢١',
      isQuran: true,
    ),
    Wisdom(
      arabic:
          'إِنَّ الَّذِينَ يَتْلُونَ كِتَابَ اللَّهِ وَأَقَامُوا الصَّلاةَ وَأَنفَقُوا مِمَّا رَزَقْنَاهُمْ سِرًّا وَعَلانِيَةً يَرْجُونَ تِجَارَةً لَّن تَبُورَ',
      english:
          'Those who recite the Book of Allah and establish prayer hope for a transaction that will never fail.',
      reference: 'فاطر ٣٥:٢٩',
      isQuran: true,
    ),
    Wisdom(
      arabic:
          'مَن قَرَأ حَرْفًا مِن كِتابِ اللَّهِ فَلَهُ بهِ حَسَنَةٌ، والحَسَنَةُ بِعَشْرِ أمثالِها',
      english:
          'Whoever reads a letter from the Book of Allah, he will have a reward, and the reward will be multiplied tenfold.',
      reference: 'الترمذي',
      isQuran: false,
    ),
    Wisdom(
      arabic:
          'يُقالُ لصاحِبِ القُرآنِ: اقرأْ وارتقِ ورتِّلْ كما كُنتَ تُرتِّلُ في الدُّنيا',
      english:
          'It will be said to the companion of the Quran: Read, ascend, and recite as you used to.',
      reference: 'أبو داود والترمذي',
      isQuran: false,
    ),
    Wisdom(
      arabic: 'الْمَاهِرُ بِالْقُرْآنِ مَعَ السَّفَرَةِ الْكِرَامِ الْبَرَرَةِ',
      english:
          'The one who is proficient in the Quran will be with the noble righteous scribes.',
      reference: 'صحيح البخاري ومسلم',
      isQuran: false,
    ),
    Wisdom(
      arabic:
          'تَعَاهَدُوا هذا القُرآنَ، فَوَالَّذي نَفْسُ مُحَمَّدٍ بيَدِهِ لَهُوَ أشَدُّ تَفَلُّتًا مِنَ الإبِلِ في عُقُلِها',
      english:
          "Keep revisiting the Quran, for by the One in whose Hand is Muhammad's soul, it escapes faster than camels from their ropes.",
      reference: 'متفق عليه',
      isQuran: false,
    ),
    Wisdom(
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

              return WisdomPage(
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/data/quran/quran_text_index.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/recitation/presentation/recitation_providers.dart';
import 'package:tilawa/recitation/presentation/widgets/ayah_block.dart';
import 'package:tilawa/recitation/presentation/widgets/position_bar.dart';
import 'package:tilawa/recitation/presentation/widgets/surah_heading.dart';
import 'package:tilawa/recitation/presentation/widgets/text_page_message.dart';

/// The surah's text, laid out as the Mushaf lays it out, one page at a time.
///
/// This is the memorisation surface, not a reader. Every word sits under its
/// own cover, uncovering as the recogniser hears it said, so the page fills in
/// behind the reciter and shows at a glance where they stalled.
///
/// Pages are real Mushaf pages, taken from the page number the corpus carries
/// for every ayah. Page 208 here is page 208 in the reciter's own copy, which
/// is the whole point — a hafiz navigates by remembered page, and a paginated
/// surface that invented its own page breaks would fight that memory rather
/// than support it. Turning is horizontal, right to left, the way the book
/// opens. A page whose content does not fit the screen scrolls inside itself,
/// so a swipe always means "turn the page" and never "scroll a bit".
///
/// Covers are drawn at the exact size of the word underneath, so uncovering
/// never reflows the text: what is revealed lands where the cover was.
class MemoryText extends ConsumerStatefulWidget {
  const MemoryText({
    super.key,
    required this.surah,
    required this.session,
    required this.revealed,
    required this.onRevealConsumed,
  });

  final SurahRevision surah;
  final RecitationSessionState session;

  /// Whether the eye has been pressed for the page on screen.
  final bool revealed;

  /// Called when the reciter turns away from the page they revealed, so the
  /// next page starts covered again. Revealing is meant to be a deliberate act
  /// per page, not a switch that turns the test off for the rest of the surah.
  final VoidCallback onRevealConsumed;

  @override
  ConsumerState<MemoryText> createState() => MemoryTextState();
}

class MemoryTextState extends ConsumerState<MemoryText> {
  /// Quran text is set at a fixed size. The size preference in settings scales
  /// the interface; the Mushaf is not interface, and letting it shrink would
  /// change where the page breaks fall and break the correspondence with the
  /// printed page that the pagination exists to preserve.
  static const double quranFontSize = 24;

  PageController? _controller;

  /// Individual words the reciter has tapped to peek at, keyed `ayah:word`.
  final Set<String> _peekedWords = {};

  /// Whole ayahs uncovered by tapping their marker.
  final Set<int> _peekedAyahs = {};

  /// Pages, in Mushaf order, as they were last built.
  List<int> _pages = const [];

  int _pageIndex = 0;
  int? _lastFollowedAyah;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Follows the recogniser across a page boundary.
  void _followRecogniser(Map<int, List<QuranAyah>> byPage) {
    final current = widget.session.current;
    if (current == null ||
        current.surah != widget.surah.number ||
        current.ayah == _lastFollowedAyah) {
      return;
    }
    _lastFollowedAyah = current.ayah;

    final page = _pages.indexWhere(
      (number) => byPage[number]!.any((ayah) => ayah.ayah == current.ayah),
    );
    if (page < 0 || page == _pageIndex) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller?.animateToPage(
        page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Turns [delta] pages. Used by the arrows, which are the one way of
  /// moving through the Mushaf whose meaning cannot be misread — a gesture
  /// depends on which way round the reader expects a book to work, an arrow
  /// pointing at the next page does not.
  void _turnBy(int delta) {
    final target = _pageIndex + delta;
    if (target < 0 || target >= _pages.length) return;
    _controller?.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    final wasRevealed = widget.revealed;
    setState(() => _pageIndex = index);
    if (wasRevealed) widget.onRevealConsumed();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final ayahsAsync = ref.watch(quranSurahProvider(widget.surah.number));
    final checkedBasmala =
        ref.watch(quranSurahProvider(1)).valueOrNull?.firstOrNull?.textUthmani;

    return ayahsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => TextPageMessage(message: '$error'),
      data: (ayahs) {
        if (ayahs.isEmpty) {
          return TextPageMessage(message: strings.surahTextUnavailable);
        }

        // Group by the printed page. A surah spans one page or a hundred; the
        // data decides, not the screen.
        final byPage = <int, List<QuranAyah>>{};
        for (final ayah in ayahs) {
          byPage.putIfAbsent(ayah.page, () => []).add(ayah);
        }
        _pages = byPage.keys.toList()..sort();
        _controller ??= PageController(initialPage: _pageIndex);
        _followRecogniser(byPage);

        // Ayahs already committed this session are uncovered in full.
        final recited = <int>{
          for (final verse in widget.session.covered)
            if (verse.surah == widget.surah.number) verse.ayah,
        };
        final current = widget.session.current;

        return Column(
          children: [
            Expanded(
              // Quran pages use the Mushaf's RTL turning order even when the
              // surrounding interface is English. This also keeps this view
              // and the full Mushaf reader on exactly the same gesture.
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: PageView.builder(
                  controller: _controller,
                  // Clamping removes the rubber-band overscroll, so dragging
                  // backwards from the first page does nothing at all rather
                  // than appearing to move.
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    final pageAyahs = byPage[page]!;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                      children: [
                        if (pageAyahs.first.ayah == 1)
                          SurahHeading(
                            name: pageAyahs.first.surahName,
                            ayahCount: ayahs.length,
                            // Al-Fatiha prints the basmala as its first ayah and
                            // At-Tawba has none, so neither needs one added.
                            basmala: widget.surah.number != 1 &&
                                    widget.surah.number != 9
                                ? checkedBasmala
                                : null,
                            hint:
                                widget.revealed ? null : strings.tapWordToPeek,
                            fontSize: quranFontSize,
                          ),
                        for (final ayah in pageAyahs)
                          AyahBlock(
                            ayah: ayah,
                            fontSize: quranFontSize,
                            isCurrent: current?.surah == ayah.surah &&
                                current?.ayah == ayah.ayah,
                            wordIndex: widget.session.wordIndex,
                            totalWords: widget.session.totalWords,
                            revealAll:
                                (widget.revealed && index == _pageIndex) ||
                                    recited.contains(ayah.ayah) ||
                                    _peekedAyahs.contains(ayah.ayah),
                            peekedWords: _peekedWords,
                            onPeekWord: (wordIndex) => setState(
                              () => _peekedWords.add('${ayah.ayah}:$wordIndex'),
                            ),
                            onPeekAyah: () =>
                                setState(() => _peekedAyahs.add(ayah.ayah)),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            _PageTurnBar(
              page: _pages.isEmpty ? 0 : _pages[_pageIndex],
              index: _pageIndex,
              count: _pages.length,
              strings: strings,
              onTurn: _turnBy,
            ),
            PositionBar(session: widget.session, strings: strings),
          ],
        );
      },
    );
  }
}

/// Which page of the Mushaf is open, and how far through the surah it is.
class _PageTurnBar extends StatelessWidget {
  const _PageTurnBar({
    required this.page,
    required this.index,
    required this.count,
    required this.strings,
    required this.onTurn,
  });

  final int page;
  final int index;
  final int count;
  final AppStrings strings;

  /// Called with -1 or 1 to step a page.
  final ValueChanged<int> onTurn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Laid out by meaning, not by screen side: under RTL the leading
          // arrow sits on the right, which is where "back" belongs in a book
          // that opens that way.
          IconButton(
            onPressed: index > 0 ? () => onTurn(-1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: strings.previousPage,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            strings.pageOf(page, index + 1, count),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (count > 1) ...[
            const SizedBox(width: 10),
            // Dots read as "there is more this way", which a page number alone
            // does not on a surface you have to discover is swipeable.
            for (var i = 0; i < count && i < 12; i++)
              Container(
                width: i == index ? 14 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == index
                      ? AppColors.amber
                      : scheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
          ],
          IconButton(
            onPressed: index < count - 1 ? () => onTurn(1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: strings.nextPage,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

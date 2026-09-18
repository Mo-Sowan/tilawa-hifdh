import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/recitation/presentation/recitation_providers.dart';
import 'package:tilawa/recitation/presentation/widgets/ayah_block.dart';
import 'package:tilawa/recitation/presentation/widgets/position_bar.dart';
import 'package:tilawa/recitation/presentation/widgets/surah_heading.dart';
import 'package:tilawa/recitation/presentation/widgets/text_page_message.dart';

/// The surah's text, with every word covered until it is earned.
///
/// This is the memorisation surface, not a reader. The whole surah scrolls
/// continuously — no Mushaf page framing, no paging — and each word sits under
/// its own cover. A word uncovers when the recogniser hears the reciter say
/// it, so the page fills in behind them as they go and they can see at a
/// glance how far they got and where they stalled. A word can also be tapped
/// to peek at it, and the eye in the title bar uncovers everything at once.
///
/// Covers are drawn at the exact size of the word underneath, so uncovering
/// never reflows the text: what is revealed lands where the cover was.
class MemoryText extends ConsumerStatefulWidget {
  const MemoryText({super.key, 
    required this.surah,
    required this.session,
    required this.revealAll,
    required this.fontSize,
  });

  final SurahRevision surah;
  final RecitationSessionState session;
  final bool revealAll;
  final double fontSize;

  @override
  ConsumerState<MemoryText> createState() => MemoryTextState();
}

class MemoryTextState extends ConsumerState<MemoryText> {
  final ScrollController _controller = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  /// Individual words the reciter has tapped to peek at, keyed `ayah:word`.
  final Set<String> _peekedWords = {};

  /// Whole ayahs uncovered by tapping their marker.
  final Set<int> _peekedAyahs = {};

  int? _lastFollowedAyah;

  @override
  void didUpdateWidget(MemoryText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.session.current;
    if (current == null ||
        current.surah != widget.surah.number ||
        current.ayah == _lastFollowedAyah) {
      return;
    }
    // The recogniser moved on; bring the new ayah into view.
    _lastFollowedAyah = current.ayah;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollTo(current.ayah));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollTo(int ayah) {
    final context = _ayahKeys[ayah]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.25,
    );
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

        // Ayahs already committed this session are uncovered in full.
        final recited = <int>{
          for (final verse in widget.session.covered)
            if (verse.surah == widget.surah.number) verse.ayah,
        };
        final current = widget.session.current;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _controller,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: ayahs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SurahHeading(
                      name: ayahs.first.surahName,
                      ayahCount: ayahs.length,
                      // Al-Fatiha prints the basmala as its first ayah and
                      // At-Tawba has none, so neither needs one added.
                      basmala:
                          widget.surah.number != 1 && widget.surah.number != 9
                              ? checkedBasmala
                              : null,
                      hint: widget.revealAll ? null : strings.tapWordToPeek,
                      fontSize: widget.fontSize,
                    );
                  }

                  final ayah = ayahs[index - 1];
                  return AyahBlock(
                    key: _ayahKeys.putIfAbsent(ayah.ayah, GlobalKey.new),
                    ayah: ayah,
                    fontSize: widget.fontSize,
                    isCurrent: current?.surah == ayah.surah &&
                        current?.ayah == ayah.ayah,
                    wordIndex: widget.session.wordIndex,
                    totalWords: widget.session.totalWords,
                    revealAll: widget.revealAll ||
                        recited.contains(ayah.ayah) ||
                        _peekedAyahs.contains(ayah.ayah),
                    peekedWords: _peekedWords,
                    onPeekWord: (wordIndex) => setState(
                      () => _peekedWords.add('${ayah.ayah}:$wordIndex'),
                    ),
                    onPeekAyah: () =>
                        setState(() => _peekedAyahs.add(ayah.ayah)),
                  );
                },
              ),
            ),
            PositionBar(session: widget.session, strings: strings),
          ],
        );
      },
    );
  }
}

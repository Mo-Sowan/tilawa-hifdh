import 'package:flutter/material.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/data/quran/quran_text_index.dart';
import 'package:tilawa/recitation/engine/arabic_normalizer.dart';
import 'package:tilawa/recitation/presentation/widgets/masked_word.dart';

/// One ayah, word by word, so each word can be covered on its own.
///
/// The Uthmani text also carries standalone pause and hizb marks, which are
/// printed in the Mushaf but are not words anyone recites. They are never
/// covered, and — as in the recogniser, which works from the phoneme text and
/// so never sees them — they are not counted when working out how far into the
/// ayah the reciter has got.
class AyahBlock extends StatelessWidget {
  const AyahBlock({
    required this.ayah,
    required this.fontSize,
    required this.isCurrent,
    required this.wordIndex,
    required this.totalWords,
    required this.revealAll,
    required this.peekedWords,
    required this.onPeekWord,
    required this.onPeekAyah,
    super.key,
  });

  final QuranAyah ayah;
  final double fontSize;

  /// Whether the recogniser believes this is the ayah being recited.
  final bool isCurrent;

  /// How far into the ayah the recogniser has got, and out of how many words,
  /// both counted the recogniser's way.
  final int wordIndex;
  final int totalWords;

  final bool revealAll;
  final Set<String> peekedWords;
  final ValueChanged<int> onPeekWord;
  final VoidCallback onPeekAyah;

  static const List<String> _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  /// The Mushaf's end-of-ayah medallion: U+06DD, which Amiri Quran draws as
  /// the ornament, with the number set inside it in Arabic-Indic digits.
  static String _ayahMarker(int value) =>
      '۝${value.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join()}';

  /// A token is a word if anything survives the normalization the recogniser
  /// applies; a lone pause mark normalizes away to nothing.
  static bool _isWord(String token) => normalizeArabic(token).isNotEmpty;

  /// How many of this ayah's printed words are uncovered.
  ///
  /// The two counts agree for all but a couple of hundred verses, where the
  /// recogniser's text splits a token this one does not; there the position is
  /// scaled across rather than trusting an index that means something slightly
  /// different in each.
  int _wordsReached(int printedWords) {
    if (!isCurrent || printedWords == 0) return 0;
    if (totalWords == 0 || totalWords == printedWords) return wordIndex;
    return (wordIndex * printedWords / totalWords)
        .round()
        .clamp(0, printedWords);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = splitWords(ayah.textUthmani);
    final reached = _wordsReached(tokens.where(_isWord).length);
    final style = AppTheme.quranText(size: fontSize, color: scheme.onSurface);

    var ordinal = 0;
    final words = <Widget>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (!_isWord(token)) {
        words.add(
          Text(
            token,
            textDirection: TextDirection.rtl,
            style: style.copyWith(color: scheme.primary.withValues(alpha: 0.6)),
          ),
        );
        continue;
      }
      final spoken = ordinal < reached;
      words.add(
        MaskedWord(
          word: token,
          style: style,
          visible:
              revealAll || spoken || peekedWords.contains('${ayah.ayah}:$i'),
          isSpoken: spoken,
          onPeek: () => onPeekWord(i),
        ),
      );
      ordinal++;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? scheme.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        // Covers are as tall as the line box, so wrapped runs need room of
        // their own or the slabs of one run sit on top of the next.
        runSpacing: 8,
        children: [
          ...words,
          GestureDetector(
            onTap: onPeekAyah,
            child: Text(
              _ayahMarker(ayah.ayah),
              textDirection: TextDirection.rtl,
              style: style.copyWith(color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

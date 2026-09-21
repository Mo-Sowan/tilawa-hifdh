import 'package:flutter/material.dart';

/// One word under a cover the size of the word.
///
/// The word is always laid out; hiding it only makes its glyphs transparent
/// and paints a slab over the space they occupy. That is what keeps the line
/// breaks identical whether the text is covered or not.
class MaskedWord extends StatelessWidget {
  const MaskedWord({super.key, 
    required this.word,
    required this.style,
    required this.visible,
    required this.isSpoken,
    required this.onPeek,
  });

  final String word;
  final TextStyle style;
  final bool visible;

  /// Uncovered because the recogniser heard it, rather than by a tap.
  final bool isSpoken;

  final VoidCallback onPeek;

  static const Duration _fade = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverColor = scheme.onSurface.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: visible ? null : onPeek,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _fade,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: visible ? Colors.transparent : coverColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: AnimatedDefaultTextStyle(
          duration: _fade,
          curve: Curves.easeOut,
          style: style.copyWith(
            color: visible
                ? (isSpoken ? scheme.primary : style.color)
                : Colors.transparent,
          ),
          child: Text(word, textDirection: TextDirection.rtl),
        ),
      ),
    );
  }
}

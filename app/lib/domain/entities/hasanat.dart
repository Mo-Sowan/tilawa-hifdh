/// Reward counted for what was recited, on the reckoning of the hadith that
/// one letter of the Book is a good deed, and a good deed is tenfold.
///
/// The count is of *letters*, which in Arabic script means the consonantal
/// skeleton only. Everything laid over it is excluded, and the distinction
/// matters because Uthmani text is dense with marks that are not letters:
///
/// * **Tashkeel** — fatha, damma, kasra, sukun, shadda, the tanween, and the
///   superscript alif (U+0670) — are vowel marks, not letters.
/// * **Recitation marks** — the waqf signs (U+06D6-U+06ED), the hizb sign
///   (U+06DE) and the end-of-ayah sign (U+06DD) — are editorial notation.
/// * **Tatweel** (U+0640) is a typographic stretch with no sound at all.
/// * **Spaces, digits and punctuation** are not letters either.
///
/// Hamza on a seat is one letter, as it is written: أ إ آ ؤ ئ each count once,
/// and a bare ء counts once. Alif wasla (ٱ) is written and so counts.
///
/// This is an arithmetic convenience for encouragement, not a fatwa: scholars
/// differ on the details, and reward is not something an app can measure.
class Hasanat {
  const Hasanat._();

  /// Good deeds credited per letter.
  static const int perLetter = 10;

  /// Whether [rune] is a written Arabic letter.
  ///
  /// The ranges are listed rather than derived so that what counts is visible
  /// and reviewable, instead of hiding behind a regex class whose membership
  /// nobody can check.
  static bool isArabicLetter(int rune) {
    // Hamza, alif and the rest of the basic alphabet. The gap at 0x063B-0x0640
    // is unassigned plus tatweel, and 0x064B-0x065F is the tashkeel.
    if (rune >= 0x0621 && rune <= 0x063A) return true; // ء ... غ
    if (rune >= 0x0641 && rune <= 0x064A) return true; // ف ... ي

    // Dotless beh and qaf, which Uthmani orthography uses.
    if (rune >= 0x066E && rune <= 0x066F) return true; // ٮ ٯ

    // 0x0670 is deliberately not here: the superscript alef is a vowel mark
    // written above the line, not a letter on it, despite Unicode naming it
    // ARABIC LETTER SUPERSCRIPT ALEF. Counting it added a letter to every
    // word spelled with a dagger alif, ٱلرَّحْمَٰنِ among them.
    if (rune >= 0x0671 && rune <= 0x06D3) return true; // ٱ ... ۓ

    return false;
  }

  /// The letters of [text], with everything that is not a letter removed.
  static String letters(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (isArabicLetter(rune)) buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  /// How many written letters [text] contains.
  static int countLetters(String text) {
    var count = 0;
    for (final rune in text.runes) {
      if (isArabicLetter(rune)) count++;
    }
    return count;
  }

  /// How many letters a whole session came to.
  static int countLettersIn(Iterable<String> texts) =>
      texts.fold<int>(0, (sum, text) => sum + countLetters(text));

  /// Reward for [text].
  static int forText(String text) => countLetters(text) * perLetter;

  /// Reward for everything recited in a session.
  static int forTexts(Iterable<String> texts) =>
      countLettersIn(texts) * perLetter;
}

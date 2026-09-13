import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/domain/entities/hasanat.dart';

void main() {
  group('counting letters', () {
    test('counts the written letters of an undecorated phrase', () {
      // بسم الله الرحمن الرحيم — 19 letters, the count this phrase is known by.
      expect(Hasanat.countLetters('بسم الله الرحمن الرحيم'), 19);
    });

    test('tashkeel does not add to the count', () {
      const plain = 'بسم الله الرحمن الرحيم';
      const vowelled = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

      // The vowelled form writes alif wasla where the plain one writes alif,
      // so both are 19 letters even though one carries far more code points.
      expect(vowelled.runes.length, greaterThan(plain.runes.length));
      expect(Hasanat.countLetters(vowelled), Hasanat.countLetters(plain));
    });

    test('spaces, digits and punctuation are not letters', () {
      expect(Hasanat.countLetters('  \n\t'), 0);
      expect(Hasanat.countLetters('١٢٣٤٥'), 0);
      expect(Hasanat.countLetters('۝٣'), 0);
      expect(Hasanat.countLetters('abc123 .,!'), 0);
    });

    test('recitation marks are not letters', () {
      // Waqf signs, the hizb sign and the end-of-ayah sign.
      for (final mark in ['ۖ', 'ۛ', '۝', '۞', '۩']) {
        expect(Hasanat.countLetters(mark), 0, reason: mark.codeUnits.toString());
      }
    });

    test('tatweel stretches the word without adding a letter', () {
      expect(Hasanat.countLetters('الرحمـــن'), Hasanat.countLetters('الرحمن'));
    });

    test('hamza on a seat counts once, as it is written', () {
      expect(Hasanat.countLetters('أ'), 1);
      expect(Hasanat.countLetters('إ'), 1);
      expect(Hasanat.countLetters('آ'), 1);
      expect(Hasanat.countLetters('ؤ'), 1);
      expect(Hasanat.countLetters('ئ'), 1);
      expect(Hasanat.countLetters('ء'), 1);
      expect(Hasanat.countLetters('ٱ'), 1);
    });

    test('letters() returns the skeleton it counted', () {
      expect(Hasanat.letters('بِسْمِ ٱللَّهِ'), 'بسمٱلله');
    });
  });

  group('reward', () {
    test('is ten a letter', () {
      expect(Hasanat.perLetter, 10);
      expect(Hasanat.forText('بسم الله الرحمن الرحيم'), 190);
    });

    test('adds up across everything recited', () {
      const verses = ['بسم الله الرحمن الرحيم', 'الحمد لله رب العالمين'];
      expect(
        Hasanat.countLettersIn(verses),
        Hasanat.countLetters(verses[0]) + Hasanat.countLetters(verses[1]),
      );
      expect(Hasanat.forTexts(verses), Hasanat.countLettersIn(verses) * 10);
    });

    test('an empty session earns nothing', () {
      expect(Hasanat.forTexts(const []), 0);
      expect(Hasanat.forText(''), 0);
    });
  });

  group('against the bundled corpus', () {
    test('every verse counts at least one letter, and marks never inflate it',
        () {
      final file = File('assets/quran/quran_display.json');
      if (!file.existsSync()) {
        markTestSkipped('quran_display.json is not present');
        return;
      }

      final document =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final verses = (document['verses'] as List).cast<List<dynamic>>();

      for (final row in verses) {
        final uthmani = row[5] as String;
        final letters = Hasanat.countLetters(uthmani);
        expect(letters, greaterThan(0), reason: '${row[0]}:${row[1]}');
        // The skeleton can never be longer than the text it came from.
        expect(letters, lessThanOrEqualTo(uthmani.runes.length));
      }
    });
  });
}

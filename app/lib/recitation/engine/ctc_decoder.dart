import 'dart:typed_data';

import 'package:tilawa/recitation/engine/arabic_normalizer.dart';

/// Greedy CTC decode of one inference pass.
class CtcDecodeResult {
  const CtcDecodeResult({required this.text, required this.tokenIds});

  final String text;
  final List<int> tokenIds;
}

/// SentencePiece word-boundary marker used by the model's BPE vocabulary.
const String wordPrefix = '\u2581';

/// Greedy decoder for the model's 1025-token Arabic BPE vocabulary.
class CtcDecoder {
  CtcDecoder(Map<String, dynamic> vocabJson, {int? blankId}) {
    var maxId = 0;
    vocabJson.forEach((id, token) {
      final numericId = int.parse(id);
      _vocab[numericId] = token as String;
      if (numericId > maxId) maxId = numericId;
    });
    _blankId = blankId ?? maxId;
  }

  final Map<int, String> _vocab = {};
  late final int _blankId;

  int get blankId => _blankId;

  /// Argmax per frame, then collapse repeats and drop blanks.
  CtcDecodeResult decode(Float32List logProbs, int timeSteps, int vocabSize) {
    final tokenIds = <int>[];
    var previous = -1;

    for (var t = 0; t < timeSteps; t++) {
      final offset = t * vocabSize;
      var maxIndex = 0;
      var maxValue = logProbs[offset];
      for (var v = 1; v < vocabSize; v++) {
        final value = logProbs[offset + v];
        if (value > maxValue) {
          maxValue = value;
          maxIndex = v;
        }
      }
      if (maxIndex != previous && maxIndex != _blankId) {
        tokenIds.add(maxIndex);
      }
      previous = maxIndex;
    }

    return CtcDecodeResult(text: tokenIdsToText(tokenIds), tokenIds: tokenIds);
  }

  /// Detokenizes ids into normalized Arabic text.
  String tokenIdsToText(List<int> tokenIds) {
    final buffer = StringBuffer();
    for (final id in tokenIds) {
      if (id == _blankId) continue;
      final token = _vocab[id];
      if (token == null || token.isEmpty) continue;
      if (token == '<unk>' || token == '<blank>') continue;
      buffer.write(token);
    }
    return normalizeArabic(buffer.toString().replaceAll(wordPrefix, ' ')).trim();
  }

  /// Raw vocabulary tokens, boundary markers preserved.
  List<String> tokenIdsToRawTokens(List<int> tokenIds) {
    final tokens = <String>[];
    for (final id in tokenIds) {
      if (id == _blankId) continue;
      final token = _vocab[id];
      if (token == null || token.isEmpty || token == '<unk>') continue;
      tokens.add(token);
    }
    return tokens;
  }

  /// Token offsets at which each word ends — the prefix lengths used for
  /// word-level acoustic progress during tracking.
  List<int> tokenIdsToWordEnds(List<int> tokenIds) {
    final tokens = tokenIdsToRawTokens(tokenIds);
    final ends = <int>[];
    var inWord = false;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == wordPrefix || token.startsWith(wordPrefix)) {
        if (inWord) ends.add(i);
        inWord = token != wordPrefix;
        continue;
      }
      inWord = true;
    }
    if (inWord) ends.add(tokens.length);

    final deduped = <int>[];
    for (var i = 0; i < ends.length; i++) {
      if (i == 0 || ends[i] > ends[i - 1]) deduped.add(ends[i]);
    }
    return deduped;
  }
}

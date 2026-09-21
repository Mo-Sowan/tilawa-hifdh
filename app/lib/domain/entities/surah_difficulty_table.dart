// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Produced by tools/build_surah_difficulty.py from the checked-in corpus.
// Change the generator and re-run it; edits here are lost on the next run.

/// Which difficulty tier each surah falls in, measured from the text.
///
/// Tier 0 holds longest and tier 4 fades fastest; [SurahDifficulty.tierCoefficients]
/// maps a tier to the multiplier that divides the half-life. The comment on
/// each row is the evidence: total words, mean words per ayah, and the share of
/// five-word runs that occur more than once in the Quran.
class SurahDifficultyTable {
  const SurahDifficultyTable._();

  static const Map<int, int> tierBySurah = {
    1: 0, // 29 words, 4.1 per ayah, 0% repeated
    2: 4, // 6120 words, 21.4 per ayah, 12% repeated
    3: 4, // 3485 words, 17.4 per ayah, 10% repeated
    4: 4, // 3751 words, 21.3 per ayah, 8% repeated
    5: 4, // 2808 words, 23.4 per ayah, 11% repeated
    6: 4, // 3054 words, 18.5 per ayah, 10% repeated
    7: 4, // 3324 words, 16.1 per ayah, 12% repeated
    8: 2, // 1237 words, 16.5 per ayah, 7% repeated
    9: 3, // 2498 words, 19.4 per ayah, 5% repeated
    10: 4, // 1837 words, 16.9 per ayah, 13% repeated
    11: 4, // 1921 words, 15.6 per ayah, 14% repeated
    12: 2, // 1781 words, 16.0 per ayah, 6% repeated
    13: 4, // 857 words, 19.9 per ayah, 13% repeated
    14: 3, // 834 words, 16.0 per ayah, 10% repeated
    15: 2, // 659 words, 6.7 per ayah, 20% repeated
    16: 4, // 1848 words, 14.4 per ayah, 12% repeated
    17: 3, // 1560 words, 14.1 per ayah, 8% repeated
    18: 2, // 1583 words, 14.4 per ayah, 6% repeated
    19: 2, // 965 words, 9.8 per ayah, 8% repeated
    20: 3, // 1339 words, 9.9 per ayah, 10% repeated
    21: 2, // 1173 words, 10.5 per ayah, 6% repeated
    22: 3, // 1278 words, 16.4 per ayah, 11% repeated
    23: 3, // 1054 words, 8.9 per ayah, 14% repeated
    24: 3, // 1320 words, 20.6 per ayah, 6% repeated
    25: 2, // 897 words, 11.6 per ayah, 6% repeated
    26: 4, // 1322 words, 5.8 per ayah, 27% repeated
    27: 3, // 1155 words, 12.4 per ayah, 13% repeated
    28: 3, // 1434 words, 16.3 per ayah, 9% repeated
    29: 3, // 980 words, 14.2 per ayah, 14% repeated
    30: 3, // 821 words, 13.7 per ayah, 18% repeated
    31: 3, // 550 words, 16.2 per ayah, 24% repeated
    32: 2, // 376 words, 12.5 per ayah, 17% repeated
    33: 2, // 1291 words, 17.7 per ayah, 6% repeated
    34: 3, // 887 words, 16.4 per ayah, 11% repeated
    35: 3, // 779 words, 17.3 per ayah, 15% repeated
    36: 2, // 729 words, 8.8 per ayah, 8% repeated
    37: 2, // 865 words, 4.8 per ayah, 7% repeated
    38: 2, // 737 words, 8.4 per ayah, 9% repeated
    39: 3, // 1176 words, 15.7 per ayah, 13% repeated
    40: 3, // 1223 words, 14.4 per ayah, 13% repeated
    41: 3, // 798 words, 14.8 per ayah, 12% repeated
    42: 2, // 864 words, 16.3 per ayah, 9% repeated
    43: 2, // 834 words, 9.4 per ayah, 8% repeated
    44: 2, // 350 words, 5.9 per ayah, 8% repeated
    45: 2, // 492 words, 13.3 per ayah, 15% repeated
    46: 4, // 647 words, 18.5 per ayah, 19% repeated
    47: 2, // 543 words, 14.3 per ayah, 10% repeated
    48: 3, // 564 words, 19.4 per ayah, 11% repeated
    49: 2, // 351 words, 19.5 per ayah, 4% repeated
    50: 2, // 377 words, 8.4 per ayah, 9% repeated
    51: 2, // 364 words, 6.1 per ayah, 9% repeated
    52: 2, // 316 words, 6.4 per ayah, 7% repeated
    53: 2, // 364 words, 5.9 per ayah, 17% repeated
    54: 2, // 346 words, 6.3 per ayah, 9% repeated
    55: 1, // 355 words, 4.6 per ayah, 8% repeated
    56: 1, // 383 words, 4.0 per ayah, 7% repeated
    57: 3, // 578 words, 19.9 per ayah, 16% repeated
    58: 2, // 476 words, 21.6 per ayah, 8% repeated
    59: 3, // 449 words, 18.7 per ayah, 13% repeated
    60: 2, // 352 words, 27.1 per ayah, 5% repeated
    61: 2, // 225 words, 16.1 per ayah, 22% repeated
    62: 2, // 179 words, 16.3 per ayah, 31% repeated
    63: 2, // 184 words, 16.7 per ayah, 6% repeated
    64: 2, // 245 words, 13.6 per ayah, 16% repeated
    65: 2, // 291 words, 24.2 per ayah, 7% repeated
    66: 2, // 253 words, 21.1 per ayah, 6% repeated
    67: 2, // 337 words, 11.2 per ayah, 6% repeated
    68: 2, // 304 words, 5.8 per ayah, 16% repeated
    69: 1, // 262 words, 5.0 per ayah, 3% repeated
    70: 2, // 221 words, 5.0 per ayah, 24% repeated
    71: 1, // 230 words, 8.2 per ayah, 3% repeated
    72: 1, // 289 words, 10.3 per ayah, 3% repeated
    73: 2, // 203 words, 10.2 per ayah, 10% repeated
    74: 1, // 259 words, 4.6 per ayah, 5% repeated
    75: 1, // 168 words, 4.2 per ayah, 12% repeated
    76: 2, // 247 words, 8.0 per ayah, 9% repeated
    77: 1, // 185 words, 3.7 per ayah, 10% repeated
    78: 1, // 177 words, 4.4 per ayah, 9% repeated
    79: 1, // 183 words, 4.0 per ayah, 7% repeated
    80: 0, // 137 words, 3.3 per ayah, 0% repeated
    81: 2, // 108 words, 3.7 per ayah, 31% repeated
    82: 1, // 84 words, 4.4 per ayah, 12% repeated
    83: 1, // 173 words, 4.8 per ayah, 10% repeated
    84: 2, // 111 words, 4.4 per ayah, 38% repeated
    85: 2, // 113 words, 5.1 per ayah, 30% repeated
    86: 1, // 65 words, 3.8 per ayah, 14% repeated
    87: 1, // 76 words, 4.0 per ayah, 17% repeated
    88: 1, // 96 words, 3.7 per ayah, 10% repeated
    89: 0, // 141 words, 4.7 per ayah, 3% repeated
    90: 1, // 86 words, 4.3 per ayah, 12% repeated
    91: 0, // 58 words, 3.9 per ayah, 0% repeated
    92: 0, // 75 words, 3.6 per ayah, 0% repeated
    93: 0, // 44 words, 4.0 per ayah, 0% repeated
    94: 1, // 31 words, 3.9 per ayah, 25% repeated
    95: 1, // 38 words, 4.8 per ayah, 22% repeated
    96: 0, // 76 words, 4.0 per ayah, 0% repeated
    97: 0, // 34 words, 6.8 per ayah, 7% repeated
    98: 2, // 98 words, 12.2 per ayah, 30% repeated
    99: 1, // 40 words, 5.0 per ayah, 10% repeated
    100: 0, // 44 words, 4.0 per ayah, 0% repeated
    101: 0, // 40 words, 3.6 per ayah, 0% repeated
    102: 0, // 32 words, 4.0 per ayah, 0% repeated
    103: 1, // 18 words, 6.0 per ayah, 17% repeated
    104: 1, // 37 words, 4.1 per ayah, 25% repeated
    105: 1, // 27 words, 5.4 per ayah, 25% repeated
    106: 0, // 21 words, 5.2 per ayah, 0% repeated
    107: 1, // 29 words, 4.1 per ayah, 17% repeated
    108: 1, // 14 words, 4.7 per ayah, 33% repeated
    109: 2, // 30 words, 5.0 per ayah, 50% repeated
    110: 0, // 23 words, 7.7 per ayah, 9% repeated
    111: 0, // 27 words, 5.4 per ayah, 0% repeated
    112: 1, // 19 words, 4.8 per ayah, 20% repeated
    113: 2, // 27 words, 5.4 per ayah, 43% repeated
    114: 1, // 24 words, 4.0 per ayah, 60% repeated
  };
}

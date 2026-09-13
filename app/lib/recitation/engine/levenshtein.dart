import 'dart:typed_data';

/// Levenshtein edit distance, single-row DP so memory is O(min(m, n)).
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Keep the shorter string on the DP row.
  if (a.length > b.length) {
    final swap = a;
    a = b;
    b = swap;
  }

  final m = a.length;
  final n = b.length;
  var prev = Uint16List(m + 1);
  var curr = Uint16List(m + 1);

  for (var i = 0; i <= m; i++) {
    prev[i] = i;
  }

  for (var j = 1; j <= n; j++) {
    curr[0] = j;
    final bj = b.codeUnitAt(j - 1);
    for (var i = 1; i <= m; i++) {
      final cost = a.codeUnitAt(i - 1) == bj ? 0 : 1;
      var best = prev[i] + 1;
      final insertion = curr[i - 1] + 1;
      if (insertion < best) best = insertion;
      final substitution = prev[i - 1] + cost;
      if (substitution < best) best = substitution;
      curr[i] = best;
    }
    final swap = prev;
    prev = curr;
    curr = swap;
  }

  return prev[m];
}

/// Normalized similarity in `[0, 1]`.
///
/// Matches python-Levenshtein's `ratio()`:
/// `(len(a) + len(b) - distance) / (len(a) + len(b))`.
double similarityRatio(String a, String b) {
  final lengthSum = a.length + b.length;
  if (lengthSum == 0) return 1.0;
  return (lengthSum - editDistance(a, b)) / lengthSum;
}

/// Minimum edit distance aligning all of [query] against any substring of
/// [reference]. Gaps at both ends of [reference] are free.
int semiGlobalDistance(String query, String reference) {
  if (query.isEmpty) return 0;
  if (reference.isEmpty) return query.length;

  final m = query.length;
  final n = reference.length;
  var prev = Uint16List(m + 1);
  var curr = Uint16List(m + 1);
  for (var i = 0; i <= m; i++) {
    prev[i] = i;
  }
  var best = prev[m];

  for (var j = 1; j <= n; j++) {
    curr[0] = 0; // free to start anywhere in the reference
    final rj = reference.codeUnitAt(j - 1);
    for (var i = 1; i <= m; i++) {
      final cost = query.codeUnitAt(i - 1) == rj ? 0 : 1;
      var value = prev[i] + 1;
      final insertion = curr[i - 1] + 1;
      if (insertion < value) value = insertion;
      final substitution = prev[i - 1] + cost;
      if (substitution < value) value = substitution;
      curr[i] = value;
    }
    if (curr[m] < best) best = curr[m]; // free to end anywhere
    final swap = prev;
    prev = curr;
    curr = swap;
  }
  return best;
}

/// How much of [query] the [reference] explains, in `[0, 1]`.
/// `1.0` means [query] occurs verbatim inside [reference].
double fragmentScore(String query, String reference) {
  if (query.isEmpty) return 1.0;
  final score = 1 - semiGlobalDistance(query, reference) / query.length;
  return score < 0 ? 0 : score;
}

/// Best [similarityRatio] between [short] and any window of [long] of the same
/// length. Arguments are swapped automatically when [short] is the longer one.
double partialRatio(String short, String long) {
  if (short.isEmpty || long.isEmpty) return 0.0;
  if (short.length > long.length) {
    final swap = short;
    short = long;
    long = swap;
  }
  final window = short.length;
  var best = 0.0;
  final limit = long.length - window;
  for (var i = 0; i <= (limit < 0 ? 0 : limit); i++) {
    final score = similarityRatio(short, long.substring(i, i + window));
    if (score > best) {
      best = score;
      if (best == 1.0) break;
    }
  }
  return best;
}

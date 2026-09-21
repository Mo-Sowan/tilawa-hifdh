import 'dart:math' as math;
import 'dart:typed_data';

/// Raw acoustic output of one inference pass: a `[timeSteps, vocabSize]`
/// log-probability matrix flattened row-major.
class AcousticEvidence {
  const AcousticEvidence({
    required this.logProbs,
    required this.timeSteps,
    required this.vocabSize,
    required this.blankId,
  });

  final Float32List logProbs;
  final int timeSteps;
  final int vocabSize;
  final int blankId;
}

/// A token sequence to be scored against [AcousticEvidence], carrying an
/// arbitrary payload.
class CtcCandidate<T> {
  const CtcCandidate({required this.ids, required this.meta, this.priorScore = 0});

  final List<int> ids;
  final T meta;
  final double priorScore;
}

class ScoredCtcCandidate<T> {
  const ScoredCtcCandidate({
    required this.ids,
    required this.meta,
    required this.priorScore,
    required this.acousticScore,
    required this.feasible,
    required this.minFrames,
  });

  final List<int> ids;
  final T meta;
  final double priorScore;

  /// Negative mean log-likelihood: **lower is better**.
  final double acousticScore;
  final bool feasible;
  final int minFrames;
}

const double _impossibleScore = 1e9;

double _logAddExp(double a, double b) {
  if (a == double.negativeInfinity) return b;
  if (b == double.negativeInfinity) return a;
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return hi + math.log(1 + math.exp(lo - hi));
}

/// Frames a CTC alignment needs at minimum for [ids] (blank-separated).
int minFramesRequired(List<int> ids) => ids.length * 2 + 1;

/// CTC forward score of [ids] under [evidence].
///
/// Returns the negative mean log-likelihood per target token, so lower is a
/// better fit. Returns [_impossibleScore] when the sequence cannot be aligned.
double scoreCtcSequence(AcousticEvidence evidence, List<int> ids) {
  final targetLength = ids.length;
  if (targetLength == 0) return _impossibleScore;
  if (minFramesRequired(ids) > evidence.timeSteps) return _impossibleScore;

  final logProbs = evidence.logProbs;
  final vocabSize = evidence.vocabSize;
  final blankId = evidence.blankId;

  final stateCount = targetLength * 2 + 1;
  final states = Int32List(stateCount);
  for (var s = 0; s < stateCount; s++) {
    states[s] = s.isEven ? blankId : ids[(s - 1) >> 1];
  }

  var prev = Float64List(stateCount);
  var curr = Float64List(stateCount);
  prev.fillRange(0, stateCount, double.negativeInfinity);
  curr.fillRange(0, stateCount, double.negativeInfinity);

  prev[0] = logProbs[blankId];
  if (stateCount > 1) {
    prev[1] = logProbs[states[1]];
  }

  for (var t = 1; t < evidence.timeSteps; t++) {
    curr.fillRange(0, stateCount, double.negativeInfinity);
    final frameOffset = t * vocabSize;

    for (var s = 0; s < stateCount; s++) {
      var total = prev[s];
      if (s > 0) {
        total = _logAddExp(total, prev[s - 1]);
      }
      if (s > 1 && states[s] != blankId && states[s] != states[s - 2]) {
        total = _logAddExp(total, prev[s - 2]);
      }
      if (total != double.negativeInfinity) {
        curr[s] = total + logProbs[frameOffset + states[s]];
      }
    }

    final swap = prev;
    prev = curr;
    curr = swap;
  }

  var finalScore = prev[stateCount - 1];
  if (stateCount > 1) {
    finalScore = _logAddExp(finalScore, prev[stateCount - 2]);
  }
  if (finalScore.isNaN || finalScore.isInfinite) return _impossibleScore;

  return -finalScore / targetLength;
}

/// Scores every candidate and sorts best (lowest acoustic score) first,
/// breaking ties on the higher prior.
List<ScoredCtcCandidate<T>> scoreCtcCandidates<T>(
  AcousticEvidence evidence,
  List<CtcCandidate<T>> candidates,
) {
  final scored = candidates.map((candidate) {
    final acousticScore = scoreCtcSequence(evidence, candidate.ids);
    return ScoredCtcCandidate<T>(
      ids: candidate.ids,
      meta: candidate.meta,
      priorScore: candidate.priorScore,
      acousticScore: acousticScore,
      feasible: acousticScore.isFinite && acousticScore < _impossibleScore,
      minFrames: minFramesRequired(candidate.ids),
    );
  }).toList();

  scored.sort((a, b) {
    if (a.acousticScore != b.acousticScore) {
      return a.acousticScore.compareTo(b.acousticScore);
    }
    return b.priorScore.compareTo(a.priorScore);
  });
  return scored;
}

/// Picks the longest prefix whose acoustic score is still within [tolerance]
/// of the best one — the recitation has reached at least that far.
ScoredCtcCandidate<T>? chooseLongestStablePrefix<T>(
  List<ScoredCtcCandidate<T>> scored, {
  double tolerance = 0.12,
}) {
  if (scored.isEmpty) return null;
  final feasible = scored.where((entry) => entry.feasible).toList();
  if (feasible.isEmpty) return null;

  final bestScore = feasible.first.acousticScore;
  var best = feasible.first;
  for (final candidate in feasible) {
    if (candidate.acousticScore > bestScore + tolerance) break;
    if (candidate.ids.length >= best.ids.length) best = candidate;
  }
  return best;
}

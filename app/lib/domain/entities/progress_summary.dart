import 'package:tilawa/domain/entities/activity_day.dart';

class ProgressSummary {
  const ProgressSummary({
    required this.totalXp,
    required this.streak,
    required this.score,
    required this.plannedSurahs,
    required this.reviewedToday,
    required this.calendar,
    required this.masteryBuckets,
  });

  final int totalXp;
  final int streak;
  final int score;
  final int plannedSurahs;
  final int reviewedToday;
  final List<ActivityDay> calendar;
  final List<MasteryBucket> masteryBuckets;
}

class MasteryBucket {
  const MasteryBucket({
    required this.label,
    required this.count,
    required this.ratio,
  });

  final String label;
  final int count;
  final double ratio;
}

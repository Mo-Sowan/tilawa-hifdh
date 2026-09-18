import 'package:tilawa/presentation/widgets/celebration_overlay.dart';

class AssessmentFeedback {
  const AssessmentFeedback({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final CelebrationType type;
  final String title;
  final String subtitle;
}

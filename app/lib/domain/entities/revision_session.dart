class RevisionSession {
  const RevisionSession({
    required this.surahNumber,
    required this.surahName,
    required this.duration,
    required this.confidence,
    required this.timestamp,
  });

  final int surahNumber;
  final String surahName;
  final Duration duration;
  final int confidence;
  final DateTime timestamp;
}

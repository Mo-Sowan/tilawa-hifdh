class RevisionPlan {
  const RevisionPlan({
    required this.id,
    required this.name,
    this.surahNumbers = const <int>{},
    required this.reminderTime,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final Set<int> surahNumbers;
  final DateTime reminderTime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSurahs => surahNumbers.isNotEmpty;
  bool get isDue => DateTime.now().isAfter(reminderTime);

  RevisionPlan copyWith({
    String? id,
    String? name,
    Set<int>? surahNumbers,
    DateTime? reminderTime,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RevisionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      surahNumbers: surahNumbers ?? this.surahNumbers,
      reminderTime: reminderTime ?? this.reminderTime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

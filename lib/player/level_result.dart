class LevelResult {
  const LevelResult({
    required this.earnedXp,
    required this.previousTotalXp,
    required this.newTotalXp,
    required this.previousLevel,
    required this.newLevel,
    required this.previousTitle,
    required this.newTitle,
  });

  final int earnedXp;

  final int previousTotalXp;
  final int newTotalXp;

  final int previousLevel;
  final int newLevel;

  final String previousTitle;
  final String newTitle;

  bool get hasLevelUp {
    return newLevel > previousLevel;
  }

  int get levelsGained {
    return newLevel - previousLevel;
  }

  bool get hasTitleChanged {
    return previousTitle != newTitle;
  }

  @override
  String toString() {
    return 'LevelResult('
        'earnedXp: $earnedXp, '
        'previousTotalXp: $previousTotalXp, '
        'newTotalXp: $newTotalXp, '
        'previousLevel: $previousLevel, '
        'newLevel: $newLevel, '
        'previousTitle: $previousTitle, '
        'newTitle: $newTitle'
        ')';
  }
}
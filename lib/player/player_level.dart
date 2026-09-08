class PlayerLevel {
  const PlayerLevel({
    required this.level,
    required this.majorLevel,
    required this.tier,
    required this.title,
    required this.requiredTotalXp,
  });

  /// Palier interne compris entre 1 et 48.
  final int level;

  /// Grand niveau compris entre 1 et 12.
  final int majorLevel;

  /// Palier du grand niveau, compris entre 1 et 4.
  final int tier;

  final String title;

  /// XP totale minimale nécessaire pour atteindre ce palier.
  final int requiredTotalXp;

  String get tierLabel => PlayerLevelCatalog.tierLabel(tier);

  String get displayTitle => '$title $tierLabel';

  bool get startsMajorLevel => tier == 1;

  bool get isValid {
    return level >= PlayerLevelCatalog.minimumLevel &&
        level <= PlayerLevelCatalog.maximumLevel &&
        majorLevel >= 1 &&
        majorLevel <= PlayerLevelCatalog.majorLevelCount &&
        tier >= 1 &&
        tier <= PlayerLevelCatalog.tiersPerMajorLevel &&
        title.trim().isNotEmpty &&
        requiredTotalXp >= 0;
  }

  @override
  String toString() {
    return 'PlayerLevel('
        'level: $level, '
        'majorLevel: $majorLevel, '
        'tier: $tier, '
        'title: $title, '
        'requiredTotalXp: $requiredTotalXp'
        ')';
  }
}

class PlayerLevelCatalog {
  const PlayerLevelCatalog._();

  static const int minimumLevel = 1;
  static const int majorLevelCount = 12;
  static const int tiersPerMajorLevel = 4;
  static const int maximumLevel = majorLevelCount * tiersPerMajorLevel;

  static const List<String> majorTitles = <String>[
    'Premiers pas',
    'Curieux du monde',
    'Éclaireur',
    'Explorateur',
    'Voyageur',
    'Aventurier',
    'Guide du monde',
    'Navigateur',
    'Géographe',
    'Cartographe',
    'Grand cartographe',
    'Maître du monde',
  ];

  /// Début de chaque grand niveau, suivi de la borne d'équilibrage finale.
  /// Les quatre paliers sont répartis uniformément dans chaque intervalle.
  static const List<int> majorLevelXpBoundaries = <int>[
    0,
    400,
    1200,
    2500,
    4500,
    7500,
    11500,
    16500,
    23000,
    31500,
    42000,
    55000,
    70000,
  ];

  static PlayerLevel forLevel(int level) {
    final int normalizedLevel = level.clamp(minimumLevel, maximumLevel);
    final int majorLevel = majorLevelForLevel(normalizedLevel);
    final int tier = tierForLevel(normalizedLevel);

    return PlayerLevel(
      level: normalizedLevel,
      majorLevel: majorLevel,
      tier: tier,
      title: titleForMajorLevel(majorLevel),
      requiredTotalXp: requiredTotalXpForLevel(normalizedLevel),
    );
  }

  static int majorLevelForLevel(int level) {
    final int normalizedLevel = level.clamp(minimumLevel, maximumLevel);
    return ((normalizedLevel - 1) ~/ tiersPerMajorLevel) + 1;
  }

  static int tierForLevel(int level) {
    final int normalizedLevel = level.clamp(minimumLevel, maximumLevel);
    return ((normalizedLevel - 1) % tiersPerMajorLevel) + 1;
  }

  static int firstInternalLevelForMajorLevel(int majorLevel) {
    final int normalizedMajorLevel = majorLevel.clamp(1, majorLevelCount);
    return (normalizedMajorLevel - 1) * tiersPerMajorLevel + 1;
  }

  static String titleForLevel(int level) {
    return titleForMajorLevel(majorLevelForLevel(level));
  }

  static String titleForMajorLevel(int majorLevel) {
    final int normalizedMajorLevel = majorLevel.clamp(1, majorLevelCount);
    return majorTitles[normalizedMajorLevel - 1];
  }

  static String displayTitleForLevel(int level) {
    return forLevel(level).displayTitle;
  }

  static String tierLabel(int tier) {
    switch (tier.clamp(1, tiersPerMajorLevel)) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
      default:
        return 'IV';
    }
  }

  static int requiredTotalXpForLevel(int level) {
    final int normalizedLevel = level.clamp(minimumLevel, maximumLevel);
    final int majorIndex = (normalizedLevel - 1) ~/ tiersPerMajorLevel;
    final int tierIndex = (normalizedLevel - 1) % tiersPerMajorLevel;
    final int startXp = majorLevelXpBoundaries[majorIndex];
    final int endXp = majorLevelXpBoundaries[majorIndex + 1];
    final int intervalXp = endXp - startXp;

    return startXp + (intervalXp * tierIndex ~/ tiersPerMajorLevel);
  }

  static int xpRequiredForNextLevel(int currentLevel) {
    final int normalizedLevel = currentLevel.clamp(
      minimumLevel,
      maximumLevel,
    );

    if (normalizedLevel >= maximumLevel) {
      return 0;
    }

    return requiredTotalXpForLevel(normalizedLevel + 1) -
        requiredTotalXpForLevel(normalizedLevel);
  }

  static int levelForTotalXp(int totalXp) {
    final int normalizedXp = totalXp < 0 ? 0 : totalXp;
    int level = minimumLevel;

    while (level < maximumLevel &&
        normalizedXp >= requiredTotalXpForLevel(level + 1)) {
      level++;
    }

    return level;
  }

  static int xpIntoCurrentLevel(int totalXp) {
    final int normalizedXp = totalXp < 0 ? 0 : totalXp;
    final int level = levelForTotalXp(normalizedXp);
    return normalizedXp - requiredTotalXpForLevel(level);
  }

  static int xpNeededForNextLevel(int totalXp) {
    final int normalizedXp = totalXp < 0 ? 0 : totalXp;
    final int level = levelForTotalXp(normalizedXp);

    if (level >= maximumLevel) {
      return 0;
    }

    return requiredTotalXpForLevel(level + 1) - normalizedXp;
  }

  static int currentLevelXpTarget(int totalXp) {
    final int level = levelForTotalXp(totalXp);

    if (level >= maximumLevel) {
      return 0;
    }

    return xpRequiredForNextLevel(level);
  }

  static double progressToNextLevel(int totalXp) {
    final int target = currentLevelXpTarget(totalXp);

    if (target <= 0) {
      return 1;
    }

    final int current = xpIntoCurrentLevel(totalXp);
    return (current / target).clamp(0, 1);
  }
}

class PlayerLevel {
  const PlayerLevel({
    required this.level,
    required this.title,
    required this.requiredTotalXp,
  });

  final int level;
  final String title;

  /// XP totale minimale nécessaire pour atteindre ce niveau.
  final int requiredTotalXp;

  bool get isValid {
    return level >= 1 && title.trim().isNotEmpty && requiredTotalXp >= 0;
  }

  @override
  String toString() {
    return 'PlayerLevel('
        'level: $level, '
        'title: $title, '
        'requiredTotalXp: $requiredTotalXp'
        ')';
  }
}

class PlayerLevelCatalog {
  const PlayerLevelCatalog._();

  static const int minimumLevel = 1;
  static const int maximumLevel = 100;

  static PlayerLevel forLevel(int level) {
    final int normalizedLevel = level.clamp(minimumLevel, maximumLevel);

    return PlayerLevel(
      level: normalizedLevel,
      title: titleForLevel(normalizedLevel),
      requiredTotalXp: requiredTotalXpForLevel(normalizedLevel),
    );
  }

  static String titleForLevel(int level) {
    if (level >= 100) {
      return 'Maître du Monde';
    }

    if (level >= 90) {
      return 'Légende du globe';
    }

    if (level >= 75) {
      return 'Grand Cartographe';
    }

    if (level >= 60) {
      return 'Expert du monde';
    }

    if (level >= 50) {
      return 'Cartographe';
    }

    if (level >= 40) {
      return 'Géographe';
    }

    if (level >= 30) {
      return 'Globe-trotteur';
    }

    if (level >= 20) {
      return 'Aventurier';
    }

    if (level >= 10) {
      return 'Explorateur';
    }

    if (level >= 5) {
      return 'Voyageur';
    }

    return 'Touriste';
  }

  static int requiredTotalXpForLevel(int level) {
    final int normalizedLevel = level.clamp(minimumLevel, maximumLevel);

    if (normalizedLevel <= 1) {
      return 0;
    }

    /*
     * Courbe progressive :
     *
     * XP niveau suivant =
     * 80 + niveau précédent × 35
     *
     * Les premiers niveaux sont rapides,
     * puis la progression devient plus exigeante.
     */
    int totalXp = 0;

    for (int currentLevel = 1; currentLevel < normalizedLevel; currentLevel++) {
      totalXp += xpRequiredForNextLevel(currentLevel);
    }

    return totalXp;
  }

  static int xpRequiredForNextLevel(int currentLevel) {
    final int normalizedLevel = currentLevel.clamp(minimumLevel, maximumLevel);

    if (normalizedLevel >= maximumLevel) {
      return 0;
    }

    return 80 + normalizedLevel * 35;
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
    final int level = levelForTotalXp(totalXp);

    final int levelStartXp = requiredTotalXpForLevel(level);

    return totalXp - levelStartXp;
  }

  static int xpNeededForNextLevel(int totalXp) {
    final int level = levelForTotalXp(totalXp);

    if (level >= maximumLevel) {
      return 0;
    }

    final int nextLevelXp = requiredTotalXpForLevel(level + 1);

    return nextLevelXp - totalXp;
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

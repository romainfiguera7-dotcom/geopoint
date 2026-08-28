enum PassportKnowledgeTheme {
  location('location'),
  capital('capital'),
  flag('flag'),
  silhouette('silhouette'),
  cities('cities'),
  currency('currency'),
  languages('languages');

  const PassportKnowledgeTheme(this.id);

  final String id;

  static PassportKnowledgeTheme? fromId(
    String value,
  ) {
    final String normalized = value.trim().toLowerCase();

    for (final PassportKnowledgeTheme theme in values) {
      if (theme.id == normalized) {
        return theme;
      }
    }

    return null;
  }
}

enum PassportLearningState {
  undiscovered,
  discovered,
  learning,
  mastered,
}

enum PassportDiscoverySource {
  game('game'),
  atlas('atlas'),
  expedition('expedition'),
  challenge('challenge'),
  migration('migration'),
  unknown('unknown');

  const PassportDiscoverySource(this.id);

  final String id;

  static PassportDiscoverySource fromId(
    String value,
  ) {
    final String normalized = value.trim().toLowerCase();

    for (final PassportDiscoverySource source in values) {
      if (source.id == normalized) {
        return source;
      }
    }

    return PassportDiscoverySource.unknown;
  }
}

enum PassportCountryStampStage {
  locked,
  discovered,
  learned,
  mastered,
}

class PassportProgressRules {
  PassportProgressRules._();

  static const int minimumMasteryLevel = 0;
  static const int learnedMasteryLevel = 3;
  static const int masteredMasteryLevel = 5;
  static const int minimumLearningAttempts = 2;

  static PassportKnowledgeTheme? themeForGameMode(String modeId) {
    switch (modeId.trim().toLowerCase()) {
      case 'find_country':
        return PassportKnowledgeTheme.location;
      case 'find_capital':
        return PassportKnowledgeTheme.capital;
      case 'find_flag':
        return PassportKnowledgeTheme.flag;
      case 'ultimate':
      case 'find_silhouette':
        return PassportKnowledgeTheme.silhouette;
      default:
        return null;
    }
  }

  static int normalizeMasteryLevel(int value) {
    return value.clamp(
      minimumMasteryLevel,
      masteredMasteryLevel,
    );
  }

  static PassportLearningState learningState({
    required bool hasBeenDiscovered,
    required int totalAttempts,
    required int masteryLevel,
  }) {
    final int normalizedMastery = normalizeMasteryLevel(
      masteryLevel,
    );

    if (normalizedMastery >= masteredMasteryLevel) {
      return PassportLearningState.mastered;
    }

    if (totalAttempts >= minimumLearningAttempts) {
      return PassportLearningState.learning;
    }

    if (hasBeenDiscovered) {
      return PassportLearningState.discovered;
    }

    return PassportLearningState.undiscovered;
  }

  static int masteryLevelAfterAnswer({
    required int currentMasteryLevel,
    required int updatedStreak,
    required bool isCorrect,
  }) {
    final int normalizedCurrent = normalizeMasteryLevel(
      currentMasteryLevel,
    );

    if (!isCorrect) {
      return normalizeMasteryLevel(normalizedCurrent - 1);
    }

    final int requiredStreak;

    switch (normalizedCurrent) {
      case 0:
        requiredStreak = 1;
      case 1:
      case 2:
        requiredStreak = 2;
      case 3:
      case 4:
        requiredStreak = 3;
      default:
        return masteredMasteryLevel;
    }

    if (updatedStreak < requiredStreak) {
      return normalizedCurrent;
    }

    return normalizeMasteryLevel(normalizedCurrent + 1);
  }

  static DateTime nextReviewAt({
    required int masteryLevel,
    required bool isCorrect,
    required DateTime answeredAt,
  }) {
    if (!isCorrect) {
      return answeredAt.add(const Duration(hours: 6));
    }

    final Duration delay;

    switch (normalizeMasteryLevel(masteryLevel)) {
      case 0:
      case 1:
        delay = const Duration(days: 1);
      case 2:
        delay = const Duration(days: 3);
      case 3:
        delay = const Duration(days: 7);
      case 4:
        delay = const Duration(days: 21);
      case 5:
        delay = const Duration(days: 45);
      default:
        delay = const Duration(days: 1);
    }

    return answeredAt.add(delay);
  }

  static bool shouldUnlockCountryStamp({
    required bool isCorrect,
  }) {
    return isCorrect;
  }

  static PassportCountryStampStage countryStampStage({
    required DateTime? unlockedAt,
    required int locationMasteryLevel,
  }) {
    if (unlockedAt == null) {
      return PassportCountryStampStage.locked;
    }

    final int normalizedMastery = normalizeMasteryLevel(
      locationMasteryLevel,
    );

    if (normalizedMastery >= masteredMasteryLevel) {
      return PassportCountryStampStage.mastered;
    }

    if (normalizedMastery >= learnedMasteryLevel) {
      return PassportCountryStampStage.learned;
    }

    return PassportCountryStampStage.discovered;
  }
}

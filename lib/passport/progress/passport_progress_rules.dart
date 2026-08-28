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

    if (totalAttempts > 0) {
      return PassportLearningState.learning;
    }

    if (hasBeenDiscovered) {
      return PassportLearningState.discovered;
    }

    return PassportLearningState.undiscovered;
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

enum PassportCollectionCategory {
  emblem('emblems', 'Emblèmes'),
  title('titles', 'Titres'),
  avatar('avatar', 'Objets d’avatar'),
  passportFrame('frames', 'Cadres'),
  passportBackground('backgrounds', 'Arrière-plans'),
  event('events', 'Événements');

  const PassportCollectionCategory(this.id, this.label);

  final String id;
  final String label;
}

enum PassportCollectionRarity {
  common('Commun'),
  uncommon('Peu commun'),
  rare('Rare'),
  epic('Épique'),
  legendary('Légendaire');

  const PassportCollectionRarity(this.label);

  final String label;
}

enum PassportCollectionUnlockRule {
  always,
  playerLevel,
  discoveredEntities,
  masteredEntities,
  countryStamps,
  visitedEntities,
  gamesPlayed,
  questionsPlayed,
  expeditionStars,
  completedExpeditionLevels,
  license,
  eventOnly,
}

class PassportCollectionSnapshot {
  const PassportCollectionSnapshot({
    required this.playerLevel,
    required this.discoveredEntities,
    required this.masteredEntities,
    required this.countryStamps,
    required this.visitedEntities,
    required this.gamesPlayed,
    required this.questionsPlayed,
    required this.expeditionStars,
    required this.completedExpeditionLevels,
    required this.currentLicenseId,
    this.explicitlyUnlockedItemIds = const <String>{},
  });

  final int playerLevel;
  final int discoveredEntities;
  final int masteredEntities;
  final int countryStamps;
  final int visitedEntities;
  final int gamesPlayed;
  final int questionsPlayed;
  final int expeditionStars;
  final int completedExpeditionLevels;
  final int currentLicenseId;
  final Set<String> explicitlyUnlockedItemIds;
}

class PassportCollectionItem {
  const PassportCollectionItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.obtainMethod,
    required this.iconKey,
    required this.rarity,
    required this.unlockRule,
    required this.unlockThreshold,
    this.isSecret = false,
  });

  final String id;
  final PassportCollectionCategory category;
  final String name;
  final String description;
  final String obtainMethod;
  final String iconKey;
  final PassportCollectionRarity rarity;
  final PassportCollectionUnlockRule unlockRule;
  final int unlockThreshold;
  final bool isSecret;

  bool isOwnedBy(PassportCollectionSnapshot snapshot) {
    if (snapshot.explicitlyUnlockedItemIds.contains(id)) {
      return true;
    }

    switch (unlockRule) {
      case PassportCollectionUnlockRule.always:
        return true;
      case PassportCollectionUnlockRule.playerLevel:
        return snapshot.playerLevel >= unlockThreshold;
      case PassportCollectionUnlockRule.discoveredEntities:
        return snapshot.discoveredEntities >= unlockThreshold;
      case PassportCollectionUnlockRule.masteredEntities:
        return snapshot.masteredEntities >= unlockThreshold;
      case PassportCollectionUnlockRule.countryStamps:
        return snapshot.countryStamps >= unlockThreshold;
      case PassportCollectionUnlockRule.visitedEntities:
        return snapshot.visitedEntities >= unlockThreshold;
      case PassportCollectionUnlockRule.gamesPlayed:
        return snapshot.gamesPlayed >= unlockThreshold;
      case PassportCollectionUnlockRule.questionsPlayed:
        return snapshot.questionsPlayed >= unlockThreshold;
      case PassportCollectionUnlockRule.expeditionStars:
        return snapshot.expeditionStars >= unlockThreshold;
      case PassportCollectionUnlockRule.completedExpeditionLevels:
        return snapshot.completedExpeditionLevels >= unlockThreshold;
      case PassportCollectionUnlockRule.license:
        return snapshot.currentLicenseId >= unlockThreshold;
      case PassportCollectionUnlockRule.eventOnly:
        return false;
    }
  }

  int progressValue(PassportCollectionSnapshot snapshot) {
    switch (unlockRule) {
      case PassportCollectionUnlockRule.always:
        return unlockThreshold;
      case PassportCollectionUnlockRule.playerLevel:
        return snapshot.playerLevel;
      case PassportCollectionUnlockRule.discoveredEntities:
        return snapshot.discoveredEntities;
      case PassportCollectionUnlockRule.masteredEntities:
        return snapshot.masteredEntities;
      case PassportCollectionUnlockRule.countryStamps:
        return snapshot.countryStamps;
      case PassportCollectionUnlockRule.visitedEntities:
        return snapshot.visitedEntities;
      case PassportCollectionUnlockRule.gamesPlayed:
        return snapshot.gamesPlayed;
      case PassportCollectionUnlockRule.questionsPlayed:
        return snapshot.questionsPlayed;
      case PassportCollectionUnlockRule.expeditionStars:
        return snapshot.expeditionStars;
      case PassportCollectionUnlockRule.completedExpeditionLevels:
        return snapshot.completedExpeditionLevels;
      case PassportCollectionUnlockRule.license:
        return snapshot.currentLicenseId;
      case PassportCollectionUnlockRule.eventOnly:
        return 0;
    }
  }

  double progress(PassportCollectionSnapshot snapshot) {
    if (isOwnedBy(snapshot)) {
      return 1;
    }
    if (unlockThreshold <= 0 || unlockRule == PassportCollectionUnlockRule.eventOnly) {
      return 0;
    }
    return (progressValue(snapshot) / unlockThreshold).clamp(0, 1);
  }
}

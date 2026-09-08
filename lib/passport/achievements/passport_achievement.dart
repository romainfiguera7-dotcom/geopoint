enum PassportAchievementCategory {
  discovery('Découverte'),
  mastery('Maîtrise'),
  regularity('Régularité'),
  precision('Précision'),
  exploration('Exploration'),
  culture('Culture'),
  personalTravel('Voyage personnel');

  const PassportAchievementCategory(this.label);

  final String label;
}

enum PassportAchievementMetric {
  discoveredEntities,
  masteredEntities,
  masteredContinents,
  playDays,
  bestAnswerStreak,
  placementsUnder10Km,
  placementsUnder50Km,
  completedExpeditionLevels,
  expeditionStars,
  capitalCorrectAnswers,
  flagCorrectAnswers,
  silhouetteCorrectAnswers,
  cityCorrectAnswers,
  currencyCorrectAnswers,
  languageCorrectAnswers,
  visitedEntities,
  wishlistedEntities,
}

class PassportAchievementTier {
  const PassportAchievementTier({
    required this.id,
    required this.target,
    required this.rewardLabel,
    this.rewardItemId,
    this.isMajor = false,
  });

  final String id;
  final int target;
  final String rewardLabel;
  final String? rewardItemId;
  final bool isMajor;
}

class PassportAchievement {
  const PassportAchievement({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.metric,
    required this.unitLabel,
    required this.tiers,
    this.isPersonalOnly = false,
  });

  final String id;
  final PassportAchievementCategory category;
  final String name;
  final String description;
  final String iconKey;
  final PassportAchievementMetric metric;
  final String unitLabel;
  final List<PassportAchievementTier> tiers;

  /// Les accomplissements de voyage sont purement personnels et ne doivent
  /// jamais modifier le score, l'XP ou un classement.
  final bool isPersonalOnly;

  int valueFor(PassportAchievementSnapshot snapshot) {
    return snapshot.valueFor(metric);
  }

  int completedTierCount(PassportAchievementSnapshot snapshot) {
    final int value = valueFor(snapshot);
    return tiers.where((PassportAchievementTier tier) {
      return value >= tier.target;
    }).length;
  }

  PassportAchievementTier? nextTier(PassportAchievementSnapshot snapshot) {
    final int value = valueFor(snapshot);
    for (final PassportAchievementTier tier in tiers) {
      if (value < tier.target) {
        return tier;
      }
    }
    return null;
  }

  double progressToNextTier(PassportAchievementSnapshot snapshot) {
    final int value = valueFor(snapshot);
    final PassportAchievementTier? next = nextTier(snapshot);
    if (next == null) {
      return 1;
    }

    int previousTarget = 0;
    for (final PassportAchievementTier tier in tiers) {
      if (tier.id == next.id) {
        break;
      }
      previousTarget = tier.target;
    }

    final int range = next.target - previousTarget;
    if (range <= 0) {
      return 1;
    }
    return ((value - previousTarget) / range).clamp(0, 1).toDouble();
  }
}

class PassportAchievementSnapshot {
  const PassportAchievementSnapshot(this.values);

  final Map<PassportAchievementMetric, int> values;

  int valueFor(PassportAchievementMetric metric) {
    final int value = values[metric] ?? 0;
    return value < 0 ? 0 : value;
  }
}

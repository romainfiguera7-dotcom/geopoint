import 'player_xp_ledger.dart';

class LevelResult {
  const LevelResult({
    required this.requestedXp,
    required this.earnedXp,
    required this.grantOutcome,
    required this.updatedXpLedger,
    required this.grantedRewards,
    required this.previousTotalXp,
    required this.newTotalXp,
    required this.previousLevel,
    required this.newLevel,
    required this.previousMajorLevel,
    required this.newMajorLevel,
    required this.previousTier,
    required this.newTier,
    required this.previousTitle,
    required this.newTitle,
  });

  /// XP calculée avant les protections anti-doublon.
  final int requestedXp;

  /// XP réellement accordée au joueur.
  final int earnedXp;

  final PlayerXpGrantOutcome grantOutcome;
  final PlayerXpLedger updatedXpLedger;
  final List<PlayerXpGrantRecord> grantedRewards;

  final int previousTotalXp;
  final int newTotalXp;

  /// Paliers internes compris entre 1 et 48.
  final int previousLevel;
  final int newLevel;

  /// Grands niveaux compris entre 1 et 12.
  final int previousMajorLevel;
  final int newMajorLevel;

  final int previousTier;
  final int newTier;

  final String previousTitle;
  final String newTitle;

  bool get wasDuplicate =>
      grantOutcome == PlayerXpGrantOutcome.rejectedDuplicate;

  int awardedXpFor(PlayerXpSource source) {
    return grantedRewards
        .where((PlayerXpGrantRecord reward) => reward.source == source)
        .fold<int>(0, (int total, PlayerXpGrantRecord reward) {
      return total + reward.awardedXp;
    });
  }

  int rewardCountFor(PlayerXpSource source) {
    return grantedRewards
        .where((PlayerXpGrantRecord reward) => reward.source == source)
        .length;
  }

  List<PlayerXpRewardSummary> get rewardBreakdown {
    const List<PlayerXpSource> displayOrder = <PlayerXpSource>[
      PlayerXpSource.gameCompleted,
      PlayerXpSource.firstSuccessOfDay,
      PlayerXpSource.countryDiscovered,
      PlayerXpSource.countryMastered,
      PlayerXpSource.expeditionMissionCompleted,
      PlayerXpSource.expeditionExamCompleted,
      PlayerXpSource.achievementCompleted,
    ];
    final List<PlayerXpRewardSummary> result = <PlayerXpRewardSummary>[];

    for (final PlayerXpSource source in displayOrder) {
      final int count = rewardCountFor(source);
      final int xp = awardedXpFor(source);
      if (count > 0 && xp > 0) {
        result.add(PlayerXpRewardSummary(source: source, count: count, xp: xp));
      }
    }

    return List<PlayerXpRewardSummary>.unmodifiable(result);
  }

  bool get hasLevelUp => newLevel > previousLevel;

  bool get hasMajorLevelUp => newMajorLevel > previousMajorLevel;

  int get levelsGained => newLevel - previousLevel;

  int get majorLevelsGained => newMajorLevel - previousMajorLevel;

  bool get hasTitleChanged => previousTitle != newTitle;

  LevelResult followedBy(LevelResult next) {
    return LevelResult(
      requestedXp: requestedXp + next.requestedXp,
      earnedXp: earnedXp + next.earnedXp,
      grantOutcome: grantOutcome,
      updatedXpLedger: next.updatedXpLedger,
      grantedRewards: List<PlayerXpGrantRecord>.unmodifiable(
        <PlayerXpGrantRecord>[...grantedRewards, ...next.grantedRewards],
      ),
      previousTotalXp: previousTotalXp,
      newTotalXp: next.newTotalXp,
      previousLevel: previousLevel,
      newLevel: next.newLevel,
      previousMajorLevel: previousMajorLevel,
      newMajorLevel: next.newMajorLevel,
      previousTier: previousTier,
      newTier: next.newTier,
      previousTitle: previousTitle,
      newTitle: next.newTitle,
    );
  }

  @override
  String toString() {
    return 'LevelResult('
        'requestedXp: $requestedXp, '
        'earnedXp: $earnedXp, '
        'grantOutcome: $grantOutcome, '
        'grantedRewards: ${grantedRewards.length}, '
        'previousTotalXp: $previousTotalXp, '
        'newTotalXp: $newTotalXp, '
        'previousLevel: $previousLevel, '
        'newLevel: $newLevel, '
        'previousMajorLevel: $previousMajorLevel, '
        'newMajorLevel: $newMajorLevel, '
        'previousTier: $previousTier, '
        'newTier: $newTier, '
        'previousTitle: $previousTitle, '
        'newTitle: $newTitle'
        ')';
  }
}

class PlayerXpRewardSummary {
  const PlayerXpRewardSummary({
    required this.source,
    required this.count,
    required this.xp,
  });

  final PlayerXpSource source;
  final int count;
  final int xp;

  String get label {
    switch (source) {
      case PlayerXpSource.countryDiscovered:
        return count == 1
            ? 'Nouveau pays découvert'
            : '$count pays découverts';
      case PlayerXpSource.countryMastered:
        return count == 1
            ? 'Nouveau pays maîtrisé'
            : '$count pays maîtrisés';
      case PlayerXpSource.achievementCompleted:
        return count == 1
            ? 'Accomplissement validé'
            : '$count accomplissements validés';
      default:
        return source.label;
    }
  }
}

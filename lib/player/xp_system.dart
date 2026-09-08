import 'level_result.dart';
import 'player_level.dart';
import 'player_profile.dart';
import 'player_xp_ledger.dart';

class XpSystem {
  const XpSystem();

  static const int baseGameXp = 15;
  static const int correctAnswerXp = 3;
  static const int perfectGameBonus = 10;
  static const int precisionBonus = 5;
  static const int firstSuccessOfDayXp = 20;
  static const int countryDiscoveredXp = 5;
  static const int countryMasteredXp = 40;
  static const int expeditionMissionXp = 40;
  static const int expeditionExamXp = 100;
  static const int achievementTierXp = 25;
  static const int majorAchievementTierXp = 75;

  static const String achievementXpBaselineGrantId =
      'achievement-xp-baseline:v1';

  static const int ultimateBaseGameXp = 25;
  static const int ultimateCorrectAnswerXp = 3;
  static const int ultimatePerfectGameBonus = 20;

  LevelResult applyGameResult({
    required PlayerProfile profile,
    required String grantId,
    required DateTime completedAt,
    required int correctAnswers,
    required int totalQuestions,
    required double averageDistanceKm,
    String difficultyId = 'discovery',
    Iterable<String> newlyDiscoveredCountryIds = const <String>[],
    Iterable<String> newlyMasteredCountryIds = const <String>[],
  }) {
    final int baseXp = baseGameXp + correctAnswers * correctAnswerXp;
    int bonusXp = difficultyBonusFor(difficultyId);

    if (totalQuestions > 0 && correctAnswers == totalQuestions) {
      bonusXp += perfectGameBonus;
    }

    if (correctAnswers > 0 && averageDistanceKm <= 50) {
      bonusXp += precisionBonus;
    }

    PlayerXpLedger updatedLedger = profile.xpLedger;
    final List<PlayerXpGrantDecision> decisions = <PlayerXpGrantDecision>[];

    void applyReward(PlayerXpGrantRequest request) {
      final PlayerXpGrantDecision decision = updatedLedger.apply(request);
      decisions.add(decision);
      updatedLedger = decision.updatedLedger;
    }

    applyReward(
      PlayerXpGrantRequest(
        grantId: grantId,
        source: PlayerXpSource.gameCompleted,
        baseXp: baseXp,
        bonusXp: bonusXp,
        occurredAt: completedAt,
      ),
    );

    if (correctAnswers > 0) {
      applyReward(
        PlayerXpGrantRequest(
          grantId: firstSuccessGrantId(completedAt),
          source: PlayerXpSource.firstSuccessOfDay,
          baseXp: firstSuccessOfDayXp,
          occurredAt: completedAt,
        ),
      );
    }

    for (final String countryId in _normalizedCountryIds(
      newlyDiscoveredCountryIds,
    )) {
      applyReward(
        PlayerXpGrantRequest(
          grantId: 'country-discovered:$countryId',
          source: PlayerXpSource.countryDiscovered,
          baseXp: countryDiscoveredXp,
          occurredAt: completedAt,
        ),
      );
    }

    for (final String countryId in _normalizedCountryIds(
      newlyMasteredCountryIds,
    )) {
      applyReward(
        PlayerXpGrantRequest(
          grantId: 'country-mastered:$countryId',
          source: PlayerXpSource.countryMastered,
          baseXp: countryMasteredXp,
          occurredAt: completedAt,
        ),
      );
    }

    return _buildLevelResult(
      profile: profile,
      decisions: decisions,
      updatedLedger: updatedLedger,
    );
  }

  LevelResult applyUltimateGameResult({
    required PlayerProfile profile,
    required String grantId,
    required DateTime completedAt,
    required int correctAnswers,
    required int totalQuestions,
    required String difficultyId,
  }) {
    final int baseXp =
        ultimateBaseGameXp + correctAnswers * ultimateCorrectAnswerXp;
    int bonusXp = difficultyBonusFor(difficultyId);

    if (totalQuestions > 0 && correctAnswers == totalQuestions) {
      bonusXp += ultimatePerfectGameBonus;
    }

    final PlayerXpGrantDecision decision = profile.xpLedger.apply(
      PlayerXpGrantRequest(
        grantId: grantId,
        source: PlayerXpSource.gameCompleted,
        baseXp: baseXp,
        bonusXp: bonusXp,
        occurredAt: completedAt,
      ),
    );

    return _buildLevelResult(
      profile: profile,
      decisions: <PlayerXpGrantDecision>[decision],
      updatedLedger: decision.updatedLedger,
    );
  }

  LevelResult applyExpeditionMissionCompletion({
    required PlayerProfile profile,
    required String expeditionId,
    required String missionId,
    required DateTime completedAt,
    bool isExam = false,
  }) {
    final String normalizedExpeditionId = expeditionId.trim().toLowerCase();
    final String normalizedMissionId = missionId.trim().toLowerCase();
    if (normalizedExpeditionId.isEmpty || normalizedMissionId.isEmpty) {
      throw ArgumentError(
        'L’expédition et la mission doivent posséder un identifiant.',
      );
    }
    final PlayerXpSource source = isExam
        ? PlayerXpSource.expeditionExamCompleted
        : PlayerXpSource.expeditionMissionCompleted;
    final String kind = isExam ? 'exam' : 'mission';
    final PlayerXpGrantDecision decision = profile.xpLedger.apply(
      PlayerXpGrantRequest(
        grantId:
            'expedition-$kind:$normalizedExpeditionId:$normalizedMissionId',
        source: source,
        baseXp: isExam ? expeditionExamXp : expeditionMissionXp,
        occurredAt: completedAt,
      ),
    );

    return _buildLevelResult(
      profile: profile,
      decisions: <PlayerXpGrantDecision>[decision],
      updatedLedger: decision.updatedLedger,
    );
  }

  bool hasAchievementXpBaseline(PlayerProfile profile) {
    return profile.xpLedger.containsGrant(achievementXpBaselineGrantId);
  }

  PlayerXpLedger establishAchievementXpBaseline({
    required PlayerProfile profile,
    required Iterable<String> completedTierIds,
  }) {
    if (hasAchievementXpBaseline(profile)) {
      return profile.xpLedger;
    }

    return profile.xpLedger.withPermanentGrantIds(<String>{
      achievementXpBaselineGrantId,
      for (final String tierId in _normalizedAchievementTierIds(
        completedTierIds,
      ))
        'achievement:$tierId',
    });
  }

  LevelResult applyAchievementCompletions({
    required PlayerProfile profile,
    required Iterable<String> completedTierIds,
    required Iterable<String> majorTierIds,
    required DateTime completedAt,
  }) {
    final Set<String> normalizedMajorTierIds =
        _normalizedAchievementTierIds(majorTierIds);
    final Set<String> normalizedTierIds = _normalizedAchievementTierIds(
      <String>[...completedTierIds, ...normalizedMajorTierIds],
    );
    if (normalizedTierIds.isEmpty) {
      throw ArgumentError(
        'Au moins un palier d’accomplissement doit être fourni.',
      );
    }

    PlayerXpLedger updatedLedger = profile.xpLedger;
    final List<PlayerXpGrantDecision> decisions = <PlayerXpGrantDecision>[];
    for (final String tierId in normalizedTierIds) {
      final bool isMajor = normalizedMajorTierIds.contains(tierId);
      final PlayerXpGrantDecision decision = updatedLedger.apply(
        PlayerXpGrantRequest(
          grantId: 'achievement:$tierId',
          source: PlayerXpSource.achievementCompleted,
          baseXp: isMajor ? majorAchievementTierXp : achievementTierXp,
          occurredAt: completedAt,
        ),
      );
      decisions.add(decision);
      updatedLedger = decision.updatedLedger;
    }

    return _buildLevelResult(
      profile: profile,
      decisions: decisions,
      updatedLedger: updatedLedger,
    );
  }

  static String firstSuccessGrantId(DateTime completedAt) {
    final DateTime local = completedAt.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return 'first-success-of-day:${local.year}-$month-$day';
  }

  static int difficultyBonusFor(String difficultyId) {
    switch (difficultyId.trim().toLowerCase()) {
      case 'easy':
        return 5;
      case 'intermediate':
        return 10;
      case 'hard':
        return 15;
      case 'expert':
        return 20;
      case 'discovery':
      default:
        return 0;
    }
  }

  static Set<String> _normalizedAchievementTierIds(
    Iterable<String> tierIds,
  ) {
    return tierIds
        .map((String tierId) => tierId.trim().toLowerCase())
        .where((String tierId) => tierId.isNotEmpty)
        .toSet();
  }

  LevelResult _buildLevelResult({
    required PlayerProfile profile,
    required List<PlayerXpGrantDecision> decisions,
    required PlayerXpLedger updatedLedger,
  }) {
    final int requestedXp = decisions.fold<int>(
      0,
      (int total, PlayerXpGrantDecision decision) =>
          total + decision.requestedXp,
    );
    final int earnedXp = decisions.fold<int>(
      0,
      (int total, PlayerXpGrantDecision decision) =>
          total + decision.awardedXp,
    );
    final List<PlayerXpGrantRecord> grantedRewards = decisions
        .map((PlayerXpGrantDecision decision) => decision.record)
        .whereType<PlayerXpGrantRecord>()
        .toList(growable: false);
    final int previousXp = profile.totalXp;
    final int newXp = previousXp + earnedXp;
    final int previousLevel = profile.currentLevel;
    final int newLevel = PlayerLevelCatalog.levelForTotalXp(newXp);
    final PlayerLevel previousPlayerLevel = PlayerLevelCatalog.forLevel(
      previousLevel,
    );
    final PlayerLevel newPlayerLevel = PlayerLevelCatalog.forLevel(newLevel);

    return LevelResult(
      requestedXp: requestedXp,
      earnedXp: earnedXp,
      grantOutcome: decisions.first.outcome,
      updatedXpLedger: updatedLedger,
      grantedRewards: List<PlayerXpGrantRecord>.unmodifiable(grantedRewards),
      previousTotalXp: previousXp,
      newTotalXp: newXp,
      previousLevel: previousLevel,
      newLevel: newLevel,
      previousMajorLevel: previousPlayerLevel.majorLevel,
      newMajorLevel: newPlayerLevel.majorLevel,
      previousTier: previousPlayerLevel.tier,
      newTier: newPlayerLevel.tier,
      previousTitle: previousPlayerLevel.title,
      newTitle: newPlayerLevel.title,
    );
  }

  static List<String> _normalizedCountryIds(Iterable<String> values) {
    final Set<String> result = values
        .map((String value) => value.trim().toUpperCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final List<String> sorted = result.toList()..sort();
    return sorted;
  }
}

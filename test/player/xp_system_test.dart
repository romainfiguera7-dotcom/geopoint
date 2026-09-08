import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/level_result.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/player/player_xp_ledger.dart';
import 'package:geopoint/player/xp_system.dart';

void main() {
  const XpSystem system = XpSystem();
  final DateTime completedAt = DateTime.utc(2026, 9, 2, 12);

  test('distingue un petit palier d’un grand niveau', () {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 1),
    ).copyWith(totalXp: 90);
    final LevelResult result = system.applyGameResult(
      profile: profile,
      grantId: 'game-tier-up',
      completedAt: completedAt,
      correctAnswers: 0,
      totalQuestions: 0,
      averageDistanceKm: 1000,
    );

    expect(result.hasLevelUp, isTrue);
    expect(result.hasMajorLevelUp, isFalse);
    expect(result.previousTier, 1);
    expect(result.newTier, 2);
    expect(result.previousTitle, 'Premiers pas');
    expect(result.newTitle, 'Premiers pas');
  });

  test('détecte le passage vers un nouveau grand niveau', () {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 1),
    ).copyWith(totalXp: 380);
    final LevelResult result = system.applyGameResult(
      profile: profile,
      grantId: 'game-major-level-up',
      completedAt: completedAt,
      correctAnswers: 1,
      totalQuestions: 1,
      averageDistanceKm: 10,
    );

    expect(result.hasMajorLevelUp, isTrue);
    expect(result.previousMajorLevel, 1);
    expect(result.newMajorLevel, 2);
    expect(result.previousTitle, 'Premiers pas');
    expect(result.newTitle, 'Curieux du monde');
  });

  test('accorde tout le gain même après plusieurs parties le même jour', () {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: completedAt,
    ).applyXpGrant(
      PlayerXpGrantRequest(
        grantId: 'game-before-session',
        source: PlayerXpSource.gameCompleted,
        baseXp: 190,
        occurredAt: completedAt,
      ),
    ).profile;
    final LevelResult result = system.applyGameResult(
      profile: profile,
      grantId: 'game-after-session',
      completedAt: completedAt,
      correctAnswers: 0,
      totalQuestions: 0,
      averageDistanceKm: 1000,
    );

    expect(result.requestedXp, 15);
    expect(result.earnedXp, 15);
    expect(result.grantOutcome, PlayerXpGrantOutcome.granted);
    expect(result.newTotalXp, 205);
  });

  test('un identifiant de session déjà utilisé ne redonne aucune XP', () {
    final PlayerProfile profile = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult first = system.applyGameResult(
      profile: profile,
      grantId: 'same-game',
      completedAt: completedAt,
      correctAnswers: 0,
      totalQuestions: 0,
      averageDistanceKm: 1000,
    );
    final PlayerProfile afterFirst = profile.copyWith(
      totalXp: first.newTotalXp,
      xpLedger: first.updatedXpLedger,
    );
    final LevelResult duplicate = system.applyGameResult(
      profile: afterFirst,
      grantId: 'same-game',
      completedAt: completedAt,
      correctAnswers: 0,
      totalQuestions: 0,
      averageDistanceKm: 1000,
    );

    expect(first.earnedXp, 15);
    expect(duplicate.earnedXp, 0);
    expect(duplicate.wasDuplicate, isTrue);
    expect(duplicate.newTotalXp, first.newTotalXp);
  });

  test('une partie experte parfaite accorde le barème complet', () {
    final PlayerProfile profile = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult result = system.applyGameResult(
      profile: profile,
      grantId: 'expert-perfect-game',
      completedAt: completedAt,
      correctAnswers: 10,
      totalQuestions: 10,
      averageDistanceKm: 10,
      difficultyId: 'expert',
    );

    expect(result.requestedXp, 100);
    expect(result.earnedXp, 100);
    expect(result.awardedXpFor(PlayerXpSource.gameCompleted), 80);
    expect(result.awardedXpFor(PlayerXpSource.firstSuccessOfDay), 20);
  });

  test('la première réussite est accordée une seule fois par jour local', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult first = system.applyGameResult(
      profile: before,
      grantId: 'daily-success-first-game',
      completedAt: completedAt,
      correctAnswers: 1,
      totalQuestions: 2,
      averageDistanceKm: 100,
    );
    final PlayerProfile afterFirst = before.copyWith(
      totalXp: first.newTotalXp,
      xpLedger: first.updatedXpLedger,
    );
    final LevelResult second = system.applyGameResult(
      profile: afterFirst,
      grantId: 'daily-success-second-game',
      completedAt: completedAt.add(const Duration(hours: 1)),
      correctAnswers: 1,
      totalQuestions: 2,
      averageDistanceKm: 100,
    );
    final PlayerProfile afterSecond = afterFirst.copyWith(
      totalXp: second.newTotalXp,
      xpLedger: second.updatedXpLedger,
    );
    final LevelResult nextDay = system.applyGameResult(
      profile: afterSecond,
      grantId: 'daily-success-next-day',
      completedAt: completedAt.add(const Duration(days: 1)),
      correctAnswers: 1,
      totalQuestions: 2,
      averageDistanceKm: 100,
    );

    expect(first.awardedXpFor(PlayerXpSource.firstSuccessOfDay), 20);
    expect(second.awardedXpFor(PlayerXpSource.firstSuccessOfDay), 0);
    expect(nextDay.awardedXpFor(PlayerXpSource.firstSuccessOfDay), 20);
    expect(
      first.updatedXpLedger.permanentGrantIds,
      contains(XpSystem.firstSuccessGrantId(completedAt)),
    );
  });

  test('récompense une seule fois chaque découverte et chaque maîtrise', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult first = system.applyGameResult(
      profile: before,
      grantId: 'country-rewards-first-game',
      completedAt: completedAt,
      correctAnswers: 0,
      totalQuestions: 2,
      averageDistanceKm: 1000,
      newlyDiscoveredCountryIds: const <String>['FRA', 'DEU', 'FRA'],
      newlyMasteredCountryIds: const <String>['FRA'],
    );
    final PlayerProfile afterFirst = before.copyWith(
      totalXp: first.newTotalXp,
      xpLedger: first.updatedXpLedger,
    );
    final LevelResult repeated = system.applyGameResult(
      profile: afterFirst,
      grantId: 'country-rewards-second-game',
      completedAt: completedAt.add(const Duration(hours: 1)),
      correctAnswers: 0,
      totalQuestions: 2,
      averageDistanceKm: 1000,
      newlyDiscoveredCountryIds: const <String>['FRA', 'DEU'],
      newlyMasteredCountryIds: const <String>['FRA'],
    );

    expect(first.awardedXpFor(PlayerXpSource.gameCompleted), 15);
    expect(first.awardedXpFor(PlayerXpSource.countryDiscovered), 10);
    expect(first.rewardCountFor(PlayerXpSource.countryDiscovered), 2);
    expect(first.awardedXpFor(PlayerXpSource.countryMastered), 40);
    expect(first.earnedXp, 65);
    expect(repeated.awardedXpFor(PlayerXpSource.countryDiscovered), 0);
    expect(repeated.awardedXpFor(PlayerXpSource.countryMastered), 0);
    expect(repeated.earnedXp, 15);
  });

  test('récompense uniquement la première validation d’une mission', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult game = system.applyGameResult(
      profile: before,
      grantId: 'expedition-game',
      completedAt: completedAt,
      correctAnswers: 0,
      totalQuestions: 5,
      averageDistanceKm: 1000,
    );
    final PlayerProfile afterGame = before.copyWith(
      totalXp: game.newTotalXp,
      xpLedger: game.updatedXpLedger,
    );
    final LevelResult mission = system.applyExpeditionMissionCompletion(
      profile: afterGame,
      expeditionId: 'europe',
      missionId: 'europe_01_discovery',
      completedAt: completedAt,
    );
    final LevelResult combined = game.followedBy(mission);
    final PlayerProfile afterMission = afterGame.copyWith(
      totalXp: mission.newTotalXp,
      xpLedger: mission.updatedXpLedger,
    );
    final LevelResult duplicate = system.applyExpeditionMissionCompletion(
      profile: afterMission,
      expeditionId: 'europe',
      missionId: 'europe_01_discovery',
      completedAt: completedAt.add(const Duration(days: 1)),
    );

    expect(mission.earnedXp, 40);
    expect(
      mission.awardedXpFor(PlayerXpSource.expeditionMissionCompleted),
      40,
    );
    expect(combined.earnedXp, 55);
    expect(combined.grantedRewards, hasLength(2));
    expect(duplicate.earnedXp, 0);
    expect(duplicate.wasDuplicate, isTrue);
  });

  test('un examen d’expédition validé accorde 100 XP une seule fois', () {
    final PlayerProfile profile = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult result = system.applyExpeditionMissionCompletion(
      profile: profile,
      expeditionId: 'world',
      missionId: 'world_exam',
      completedAt: completedAt,
      isExam: true,
    );

    expect(result.earnedXp, 100);
    expect(
      result.awardedXpFor(PlayerXpSource.expeditionExamCompleted),
      100,
    );
  });

  test('la référence initiale neutralise les anciens accomplissements', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: completedAt);
    final updatedLedger = system.establishAchievementXpBaseline(
      profile: before,
      completedTierIds: const <String>[
        'world_discovery_10',
        'country_mastery_1',
      ],
    );
    final PlayerProfile afterBaseline = before.copyWith(
      xpLedger: updatedLedger,
    );
    final unchangedLedger = system.establishAchievementXpBaseline(
      profile: afterBaseline,
      completedTierIds: const <String>['world_discovery_50'],
    );
    final LevelResult oldTiers = system.applyAchievementCompletions(
      profile: afterBaseline,
      completedTierIds: const <String>[
        'world_discovery_10',
        'country_mastery_1',
      ],
      majorTierIds: const <String>[],
      completedAt: completedAt,
    );

    expect(before.totalXp, 0);
    expect(system.hasAchievementXpBaseline(afterBaseline), isTrue);
    expect(
      unchangedLedger.containsGrant('achievement:world_discovery_50'),
      isFalse,
    );
    expect(oldTiers.earnedXp, 0);
    expect(oldTiers.grantedRewards, isEmpty);
  });

  test('récompense une seule fois les paliers normaux et majeurs', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult first = system.applyAchievementCompletions(
      profile: before,
      completedTierIds: const <String>[
        'world_discovery_10',
        'world_discovery_50',
      ],
      majorTierIds: const <String>['world_discovery_50'],
      completedAt: completedAt,
    );
    final PlayerProfile after = before.copyWith(
      totalXp: first.newTotalXp,
      xpLedger: first.updatedXpLedger,
    );
    final LevelResult duplicate = system.applyAchievementCompletions(
      profile: after,
      completedTierIds: const <String>[
        'world_discovery_10',
        'world_discovery_50',
      ],
      majorTierIds: const <String>['world_discovery_50'],
      completedAt: completedAt.add(const Duration(days: 1)),
    );

    expect(first.earnedXp, 100);
    expect(first.rewardCountFor(PlayerXpSource.achievementCompleted), 2);
    expect(
      first.awardedXpFor(PlayerXpSource.achievementCompleted),
      100,
    );
    expect(first.rewardBreakdown.single.label, '2 accomplissements validés');
    expect(duplicate.earnedXp, 0);
    expect(duplicate.grantedRewards, isEmpty);
  });

  test('le profil sauvegarde ensemble l’XP, le registre et les statistiques', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: completedAt);
    final LevelResult result = system.applyGameResult(
      profile: before,
      grantId: 'saved-game',
      completedAt: completedAt,
      correctAnswers: 1,
      totalQuestions: 2,
      averageDistanceKm: 100,
      difficultyId: 'easy',
    );
    final PlayerProfile after = before.registerGameResult(
      earnedXp: result.earnedXp,
      updatedXpLedger: result.updatedXpLedger,
      gameScore: 100,
      gameCorrectAnswers: 1,
      gameTotalAnswers: 2,
      gameDistanceInKilometers: 200,
      gameElapsedSeconds: 20,
      playedAt: completedAt,
    );

    expect(after.totalXp, result.earnedXp);
    expect(after.gamesPlayed, 1);
    expect(after.totalAnswers, 2);
    expect(after.xpLedger.containsGrant('saved-game'), isTrue);
  });
}

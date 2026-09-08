import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/player_level.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/player/player_xp_debug_tools.dart';
import 'package:geopoint/player/player_xp_ledger.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 4);

  PlayerProfile profileWithXp(int totalXp) {
    return PlayerProfile.initial(createdAt: now).copyWith(totalXp: totalXp);
  }

  test('ajoute une quantité précise sans dépasser le niveau maximal', () {
    final PlayerProfile updated = PlayerXpDebugTools.apply(
      profile: profileWithXp(32),
      action: PlayerXpDebugAction.addXp,
      amount: 68,
    );

    expect(updated.totalXp, 100);
    expect(updated.displayLevelTitle, 'Premiers pas II');

    final PlayerProfile clamped = PlayerXpDebugTools.apply(
      profile: updated,
      action: PlayerXpDebugAction.addXp,
      amount: 1000000,
    );
    expect(clamped.totalXp, PlayerXpDebugTools.maximumTotalXp);
    expect(clamped.currentLevel, PlayerLevelCatalog.maximumLevel);
  });

  test('refuse une quantité d’XP nulle ou négative', () {
    expect(
      () => PlayerXpDebugTools.apply(
        profile: profileWithXp(32),
        action: PlayerXpDebugAction.addXp,
      ),
      throwsArgumentError,
    );
  });

  test('place le profil à un XP du prochain palier', () {
    final PlayerProfile updated = PlayerXpDebugTools.apply(
      profile: profileWithXp(32),
      action: PlayerXpDebugAction.prepareNextTier,
    );

    expect(updated.totalXp, 99);
    expect(updated.xpRemainingForNextLevel, 1);
    expect(updated.currentLevel, 1);
  });

  test('prépare exactement le prochain grand niveau', () {
    final PlayerProfile firstMajor = PlayerXpDebugTools.apply(
      profile: profileWithXp(32),
      action: PlayerXpDebugAction.prepareNextMajorLevel,
    );
    final PlayerProfile secondMajor = PlayerXpDebugTools.apply(
      profile: profileWithXp(400),
      action: PlayerXpDebugAction.prepareNextMajorLevel,
    );

    expect(firstMajor.totalXp, 399);
    expect(firstMajor.displayLevelTitle, 'Premiers pas IV');
    expect(secondMajor.totalXp, 1199);
    expect(secondMajor.displayLevelTitle, 'Curieux du monde IV');
  });

  test('atteint précisément Maître du monde IV', () {
    final PlayerProfile updated = PlayerXpDebugTools.apply(
      profile: profileWithXp(32),
      action: PlayerXpDebugAction.reachMaximumLevel,
    );

    expect(updated.totalXp, 66250);
    expect(updated.currentLevel, 48);
    expect(updated.displayLevelTitle, 'Maître du monde IV');
    expect(updated.isMaximumLevel, isTrue);
  });

  test('la remise à zéro conserve toutes les statistiques du profil', () {
    final PlayerProfile source = profileWithXp(2500).copyWith(
      xpLedger: const PlayerXpLedger(
        permanentGrantIds: <String>{'country:FRA'},
        recentGrantIds: <String>['game:1'],
      ),
      gamesPlayed: 189,
      correctAnswers: 420,
      totalAnswers: 800,
      totalScore: 12345,
      totalDistanceInKilometers: 6789,
      totalElapsedSeconds: 9876,
    );

    final PlayerProfile reset = PlayerXpDebugTools.apply(
      profile: source,
      action: PlayerXpDebugAction.resetXp,
    );

    expect(reset.totalXp, 0);
    expect(reset.xpLedger.permanentGrantIds, isEmpty);
    expect(reset.xpLedger.recentGrantIds, isEmpty);
    expect(reset.gamesPlayed, source.gamesPlayed);
    expect(reset.correctAnswers, source.correctAnswers);
    expect(reset.totalAnswers, source.totalAnswers);
    expect(reset.totalScore, source.totalScore);
    expect(
      reset.totalDistanceInKilometers,
      source.totalDistanceInKilometers,
    );
    expect(reset.totalElapsedSeconds, source.totalElapsedSeconds);
    expect(reset.detailedStatistics, same(source.detailedStatistics));
  });

  test('les préparations ne dépassent pas le niveau maximal', () {
    final PlayerProfile maximum = profileWithXp(
      PlayerXpDebugTools.maximumTotalXp,
    );

    expect(
      PlayerXpDebugTools.apply(
        profile: maximum,
        action: PlayerXpDebugAction.prepareNextTier,
      ),
      same(maximum),
    );
    expect(
      PlayerXpDebugTools.apply(
        profile: maximum,
        action: PlayerXpDebugAction.prepareNextMajorLevel,
      ),
      same(maximum),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/progression/passport_major_level_up.dart';
import 'package:geopoint/player/player_level.dart';
import 'package:geopoint/player/player_profile.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 4);

  test('crée la célébration uniquement au changement de grand niveau', () {
    final PlayerProfile initial = PlayerProfile.initial(createdAt: now);
    final PlayerProfile smallTier = initial.copyWith(totalXp: 100);
    final PlayerProfile majorLevel = initial.copyWith(totalXp: 400);

    expect(
      PassportMajorLevelUp.between(
        beforeProfile: initial,
        afterProfile: smallTier,
      ),
      isNull,
    );

    final PassportMajorLevelUp? transition = PassportMajorLevelUp.between(
      beforeProfile: initial.copyWith(totalXp: 300),
      afterProfile: majorLevel,
    );

    expect(transition, isNotNull);
    expect(transition!.previousLevel.displayTitle, 'Premiers pas IV');
    expect(transition.newLevel.displayTitle, 'Curieux du monde I');
    expect(transition.rewards, hasLength(2));
    expect(transition.nextObjective, '200 XP avant Curieux du monde II');
  });

  test('un saut conserve toutes les récompenses intermédiaires', () {
    final PlayerProfile before =
        PlayerProfile.initial(createdAt: now).copyWith(totalXp: 300);
    final PlayerProfile after =
        PlayerProfile.initial(createdAt: now).copyWith(totalXp: 1200);

    final PassportMajorLevelUp transition = PassportMajorLevelUp.between(
      beforeProfile: before,
      afterProfile: after,
    )!;

    expect(transition.newLevel.displayTitle, 'Éclaireur I');
    expect(
      transition.rewards.map((item) => item.unlockThreshold),
      containsAll(<int>[5, 6, 7, 8, 9]),
    );
  });

  test('le dernier grand niveau annonce encore le prochain palier', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: now).copyWith(
      totalXp: PlayerLevelCatalog.requiredTotalXpForLevel(44),
    );
    final PlayerProfile after = PlayerProfile.initial(createdAt: now).copyWith(
      totalXp: PlayerLevelCatalog.requiredTotalXpForLevel(45),
    );

    final PassportMajorLevelUp transition = PassportMajorLevelUp.between(
      beforeProfile: before,
      afterProfile: after,
    )!;

    expect(transition.newLevel.displayTitle, 'Maître du monde I');
    expect(transition.nextGoal.isMaximumLevel, isFalse);
    expect(transition.nextObjective, contains('Maître du monde II'));
  });
}

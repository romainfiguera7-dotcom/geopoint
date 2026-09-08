import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/collections/passport_collection_item.dart';
import 'package:geopoint/passport/progression/passport_level_goal.dart';
import 'package:geopoint/player/player_level.dart';
import 'package:geopoint/player/player_profile.dart';

void main() {
  test('le prochain objectif initial affiche son palier et son cadre', () {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 4),
    );
    final PassportLevelGoal goal = PassportLevelGoal.forProfile(profile);

    expect(goal.currentLevel.level, 1);
    expect(goal.nextLevel?.level, 2);
    expect(goal.nextLevelLabel, 'Premiers pas II');
    expect(goal.xpRemaining, 100);
    expect(goal.rewardSummary, 'Cadre du départ');
    expect(
      goal.rewards.single.category,
      PassportCollectionCategory.passportFrame,
    );
  });

  test('le passage de grand niveau annonce toutes ses récompenses', () {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 4),
    ).copyWith(totalXp: 300);
    final PassportLevelGoal goal = PassportLevelGoal.forProfile(profile);

    expect(goal.currentLevel.displayTitle, 'Premiers pas IV');
    expect(goal.nextLevelLabel, 'Curieux du monde I');
    expect(goal.xpRemaining, 100);
    expect(goal.rewards, hasLength(2));
    expect(goal.rewardCategoryLabel, '2 RÉCOMPENSES');
    expect(goal.rewardSummary, 'Curieux du monde + 1 autre');
  });

  test('le niveau maximum n’invente aucun prochain objectif', () {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 4),
    ).copyWith(
      totalXp: PlayerLevelCatalog.requiredTotalXpForLevel(
        PlayerLevelCatalog.maximumLevel,
      ),
    );
    final PassportLevelGoal goal = PassportLevelGoal.forProfile(profile);

    expect(goal.isMaximumLevel, isTrue);
    expect(goal.nextLevel, isNull);
    expect(goal.xpRemaining, 0);
    expect(goal.progress, 1);
    expect(goal.rewards, isEmpty);
  });
}

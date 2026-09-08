import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/achievements/passport_achievement.dart';
import 'package:geopoint/passport/achievements/passport_achievement_catalog.dart';
import 'package:geopoint/passport/collections/passport_collection_catalog.dart';
import 'package:geopoint/passport/collections/passport_collection_item.dart';

void main() {
  const PassportAchievementSnapshot snapshot = PassportAchievementSnapshot(
    <PassportAchievementMetric, int>{
      PassportAchievementMetric.discoveredEntities: 249,
      PassportAchievementMetric.masteredEntities: 39,
      PassportAchievementMetric.visitedEntities: 23,
      PassportAchievementMetric.wishlistedEntities: 3,
    },
  );

  test('le catalogue ne contient aucun identifiant dupliqué', () {
    final List<PassportAchievement> achievements =
        PassportAchievementCatalog.achievements;
    final List<PassportAchievementTier> tiers =
        PassportAchievementCatalog.allTiers().toList(growable: false);

    expect(
      achievements.map((PassportAchievement item) => item.id).toSet().length,
      achievements.length,
    );
    expect(
      tiers.map((PassportAchievementTier tier) => tier.id).toSet().length,
      tiers.length,
    );
  });

  test('la progression existante valide les bons paliers', () {
    final PassportAchievement discovery =
        PassportAchievementCatalog.achievements.firstWhere(
      (PassportAchievement item) => item.id == 'world_discovery',
    );
    final PassportAchievement mastery =
        PassportAchievementCatalog.achievements.firstWhere(
      (PassportAchievement item) => item.id == 'country_mastery',
    );
    final PassportAchievement visited =
        PassportAchievementCatalog.achievements.firstWhere(
      (PassportAchievement item) => item.id == 'personal_visited',
    );

    expect(discovery.completedTierCount(snapshot), 4);
    expect(discovery.nextTier(snapshot)?.target, 258);
    expect(mastery.completedTierCount(snapshot), 3);
    expect(visited.completedTierCount(snapshot), 2);
  });

  test('la barre recommence au palier précédent', () {
    final PassportAchievement discovery =
        PassportAchievementCatalog.achievements.firstWhere(
      (PassportAchievement item) => item.id == 'world_discovery',
    );

    expect(
      discovery.progressToNextTier(snapshot),
      closeTo((249 - 200) / (258 - 200), 0.0001),
    );
  });

  test('le voyage personnel reste sans avantage compétitif', () {
    final List<PassportAchievement> personal =
        PassportAchievementCatalog.forCategory(
      PassportAchievementCategory.personalTravel,
    );

    expect(personal, isNotEmpty);
    expect(personal.every((PassportAchievement item) => item.isPersonalOnly),
        isTrue);
    expect(
      PassportAchievementCatalog.achievementForTierId('personal_visited_5')
          ?.isPersonalOnly,
      isTrue,
    );
    expect(
      PassportAchievementCatalog.tierById('WORLD_DISCOVERY_50')?.isMajor,
      isTrue,
    );
  });

  test('chaque récompense de collection référencée existe', () {
    final Set<String> collectionIds = PassportCollectionCatalog.items
        .map((PassportCollectionItem item) => item.id)
        .toSet();
    final Iterable<String> rewardIds = PassportAchievementCatalog.allTiers()
        .map((PassportAchievementTier tier) => tier.rewardItemId)
        .whereType<String>();

    expect(rewardIds.every(collectionIds.contains), isTrue);
  });
}

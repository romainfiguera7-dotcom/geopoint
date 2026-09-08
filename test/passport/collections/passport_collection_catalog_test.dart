import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/collections/passport_collection_catalog.dart';
import 'package:geopoint/passport/collections/passport_collection_item.dart';
import 'package:geopoint/passport/progress/passport_progress_v2.dart';
import 'package:geopoint/player/player_level.dart';

void main() {
  const PassportCollectionSnapshot advancedSnapshot =
      PassportCollectionSnapshot(
    playerLevel: 30,
    discoveredEntities: 249,
    masteredEntities: 39,
    countryStamps: 196,
    visitedEntities: 23,
    gamesPlayed: 180,
    questionsPlayed: 1527,
    expeditionStars: 0,
    completedExpeditionLevels: 0,
    currentLicenseId: 5,
  );

  test('le catalogue ne contient aucun identifiant dupliqué', () {
    final Set<String> ids = PassportCollectionCatalog.items
        .map((PassportCollectionItem item) => item.id)
        .toSet();

    expect(ids.length, PassportCollectionCatalog.items.length);
  });

  test('les récompenses existantes sont déduites sans perdre la progression', () {
    expect(
      PassportCollectionCatalog.ownedCount(
        advancedSnapshot,
        category: PassportCollectionCategory.emblem,
      ),
      5,
    );
    expect(
      PassportCollectionCatalog.ownedCount(
        advancedSnapshot,
        category: PassportCollectionCategory.title,
      ),
      8,
    );
    expect(
      PassportCollectionCatalog.ownedCount(
        advancedSnapshot,
        category: PassportCollectionCategory.avatar,
      ),
      11,
    );
    expect(
      PassportCollectionCatalog.ownedCount(
        advancedSnapshot,
        category: PassportCollectionCategory.passportFrame,
      ),
      8,
    );
    expect(
      PassportCollectionCatalog.ownedCount(
        advancedSnapshot,
        category: PassportCollectionCategory.passportBackground,
      ),
      7,
    );
    expect(
      PassportCollectionCatalog.ownedCount(
        advancedSnapshot,
        category: PassportCollectionCategory.event,
      ),
      1,
    );
  });

  test('chacun des 48 paliers possède une récompense visuelle', () {
    for (int level = PlayerLevelCatalog.minimumLevel;
        level <= PlayerLevelCatalog.maximumLevel;
        level++) {
      final List<PassportCollectionItem> rewards =
          PassportCollectionCatalog.levelRewardsForLevel(level);
      final int tier = PlayerLevelCatalog.tierForLevel(level);

      expect(rewards, isNotEmpty, reason: 'Aucune récompense au niveau $level');
      if (tier == 1) {
        expect(
          rewards.any((PassportCollectionItem item) {
            return item.category == PassportCollectionCategory.title;
          }),
          isTrue,
        );
      } else if (tier == 2) {
        expect(
          rewards.any((PassportCollectionItem item) {
            return item.category == PassportCollectionCategory.passportFrame;
          }),
          isTrue,
        );
      } else if (tier == 3) {
        expect(
          rewards.any((PassportCollectionItem item) {
            return item.category ==
                PassportCollectionCategory.passportBackground;
          }),
          isTrue,
        );
      } else {
        expect(
          rewards.any((PassportCollectionItem item) {
            return item.category == PassportCollectionCategory.avatar;
          }),
          isTrue,
        );
      }
    }
  });

  test('un saut de plusieurs niveaux restitue toutes les récompenses', () {
    final List<PassportCollectionItem> rewards =
        PassportCollectionCatalog.levelRewardsUnlockedBetween(
      previousLevel: 1,
      newLevel: 5,
    );
    final Set<int> thresholds = rewards
        .map((PassportCollectionItem item) => item.unlockThreshold)
        .toSet();

    expect(thresholds, <int>{2, 3, 4, 5});
    expect(
      rewards.any((PassportCollectionItem item) {
        return item.name == 'Curieux du monde';
      }),
      isTrue,
    );
  });

  test('une récompense secrète reste verrouillée tant que sa règle échoue', () {
    final PassportCollectionItem secret = PassportCollectionCatalog.items
        .firstWhere((PassportCollectionItem item) {
      return item.id == 'emblem_world_complete';
    });

    expect(secret.isSecret, isTrue);
    expect(secret.isOwnedBy(advancedSnapshot), isFalse);
    expect(secret.progress(advancedSnapshot), closeTo(196 / 258, 0.001));
  });

  test('un événement peut débloquer explicitement une récompense', () {
    final PassportCollectionItem event = PassportCollectionCatalog.items
        .firstWhere((PassportCollectionItem item) {
      return item.id == 'event_world_challenge';
    });
    const PassportCollectionSnapshot unlockedSnapshot =
        PassportCollectionSnapshot(
      playerLevel: 1,
      discoveredEntities: 0,
      masteredEntities: 0,
      countryStamps: 0,
      visitedEntities: 0,
      gamesPlayed: 0,
      questionsPlayed: 0,
      expeditionStars: 0,
      completedExpeditionLevels: 0,
      currentLicenseId: 1,
      explicitlyUnlockedItemIds: <String>{'event_world_challenge'},
    );

    expect(event.isOwnedBy(advancedSnapshot), isFalse);
    expect(event.isOwnedBy(unlockedSnapshot), isTrue);
  });

  test('les déblocages explicites survivent à la sauvegarde', () {
    final PassportProgressV2 progress = PassportProgressV2.initial(
      createdAt: DateTime(2026, 8, 29),
    ).unlockCollectionItem(
      'event_world_challenge',
      unlockedAt: DateTime(2026, 8, 30),
    );
    final PassportProgressV2 restored =
        PassportProgressV2.fromJson(progress.toJson());

    expect(
      restored.unlockedCollectionItemIds,
      contains('event_world_challenge'),
    );
    expect(restored.schemaVersion, PassportProgressV2.currentSchemaVersion);
  });
}

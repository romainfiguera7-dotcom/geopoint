import '../../geo_engine/geo_country.dart';
import '../../player/player_profile.dart';
import '../achievements/passport_achievement.dart';
import '../achievements/passport_achievement_catalog.dart';
import '../achievements/passport_achievement_progress.dart';
import '../collections/passport_collection_catalog.dart';
import '../collections/passport_collection_item.dart';
import '../progress/passport_entity_progress.dart';
import '../progress/passport_progress_v2.dart';

enum PassportProgressNotificationType {
  stamp,
  mastery,
  level,
  title,
  collection,
  achievement,
}

class PassportProgressNotification {
  const PassportProgressNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
  });

  final String id;
  final PassportProgressNotificationType type;
  final String title;
  final String detail;
}

class PassportProgressNotificationBatch {
  const PassportProgressNotificationBatch._(this.items);

  final List<PassportProgressNotification> items;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  factory PassportProgressNotificationBatch.fromItems(
    Iterable<PassportProgressNotification> source,
  ) {
    final Map<String, PassportProgressNotification> unique =
        <String, PassportProgressNotification>{};
    for (final PassportProgressNotification item in source) {
      unique.putIfAbsent(item.id, () => item);
    }
    return PassportProgressNotificationBatch._(
      List<PassportProgressNotification>.unmodifiable(unique.values),
    );
  }
}

class PassportProgressNotificationBuilder {
  PassportProgressNotificationBuilder._();

  static PassportProgressNotificationBatch build({
    required PassportProgressV2 beforeProgress,
    required PassportProgressV2 afterProgress,
    required PlayerProfile beforeProfile,
    required PlayerProfile afterProfile,
    required PassportCollectionSnapshot beforeCollections,
    required PassportCollectionSnapshot afterCollections,
    required PassportAchievementProgress beforeAchievements,
    required PassportAchievementProgress afterAchievements,
    required Iterable<GeoCountry> countries,
  }) {
    final Map<String, String> countryNames = <String, String>{
      for (final GeoCountry country in countries)
        country.id.trim().toUpperCase(): country.name,
    };
    final List<PassportProgressNotification> notifications =
        <PassportProgressNotification>[];

    for (final PassportEntityProgress entity in afterProgress.entities.values) {
      final PassportEntityProgress before =
          beforeProgress.progressFor(entity.entityId);
      final String countryName = countryNames[entity.entityId] ?? entity.entityId;

      if (before.stampUnlockedAt == null && entity.stampUnlockedAt != null) {
        notifications.add(
          PassportProgressNotification(
            id: 'stamp:${entity.entityId}',
            type: PassportProgressNotificationType.stamp,
            title: 'Nouveau tampon',
            detail: countryName,
          ),
        );
      }
      if (!before.isMastered && entity.isMastered) {
        notifications.add(
          PassportProgressNotification(
            id: 'mastery:${entity.entityId}',
            type: PassportProgressNotificationType.mastery,
            title: 'Pays maîtrisé',
            detail: countryName,
          ),
        );
      }
    }

    final Set<String> levelRewardIds = PassportCollectionCatalog
        .levelRewardsUnlockedBetween(
          previousLevel: beforeProfile.currentLevel,
          newLevel: afterProfile.currentLevel,
        )
        .map((PassportCollectionItem item) => item.id)
        .toSet();
    for (final PassportCollectionItem item
        in PassportCollectionCatalog.items) {
      // Les récompenses de niveau sont présentées par la célébration dédiée
      // aux grands niveaux. Un petit palier n'ouvre jamais un écran forcé.
      if (levelRewardIds.contains(item.id)) {
        continue;
      }
      if (!item.isOwnedBy(beforeCollections) && item.isOwnedBy(afterCollections)) {
        notifications.add(
          PassportProgressNotification(
            id: 'collection:${item.id}',
            type: item.category == PassportCollectionCategory.title
                ? PassportProgressNotificationType.title
                : PassportProgressNotificationType.collection,
            title: _collectionTitle(item.category),
            detail: item.name,
          ),
        );
      }
    }

    final Set<String> newAchievementTierIds = afterAchievements
        .newlyCompletedTierIdsComparedWith(beforeAchievements);
    for (final PassportAchievement achievement
        in PassportAchievementCatalog.achievements) {
      for (final PassportAchievementTier tier in achievement.tiers) {
        if (!newAchievementTierIds.contains(tier.id.toLowerCase())) {
          continue;
        }
        notifications.add(
          PassportProgressNotification(
            id: 'achievement:${tier.id}',
            type: PassportProgressNotificationType.achievement,
            title: 'Accomplissement terminé',
            detail: '${achievement.name} · palier ${tier.target}',
          ),
        );
      }
    }

    return PassportProgressNotificationBatch.fromItems(notifications);
  }

  static String _collectionTitle(PassportCollectionCategory category) {
    switch (category) {
      case PassportCollectionCategory.emblem:
        return 'Emblème débloqué';
      case PassportCollectionCategory.title:
        return 'Titre débloqué';
      case PassportCollectionCategory.avatar:
        return 'Objet débloqué';
      case PassportCollectionCategory.passportFrame:
        return 'Cadre débloqué';
      case PassportCollectionCategory.passportBackground:
        return 'Arrière-plan débloqué';
      case PassportCollectionCategory.event:
        return 'Récompense débloquée';
    }
  }
}

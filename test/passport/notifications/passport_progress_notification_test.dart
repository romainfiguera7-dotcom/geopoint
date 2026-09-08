import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/passport/achievements/passport_achievement.dart';
import 'package:geopoint/passport/achievements/passport_achievement_progress.dart';
import 'package:geopoint/passport/collections/passport_collection_item.dart';
import 'package:geopoint/passport/notifications/passport_progress_notification.dart';
import 'package:geopoint/passport/progress/passport_entity_progress.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';
import 'package:geopoint/passport/progress/passport_progress_v2.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 29);
  final GeoCountry france = GeoCountry(
    id: 'FRA',
    isoA2: 'FR',
    name: 'France',
    continent: 'Europe',
    polygons: const <List<LatLng>>[],
  );

  test('regroupe les nouveautés hors récompenses de niveau', () {
    final PassportProgressV2 beforeProgress =
        PassportProgressV2.initial(createdAt: now);
    final PassportEntityProgress masteredFrance =
        PassportEntityProgress.initial('FRA').registerAnswer(
      theme: PassportKnowledgeTheme.location,
      isCorrect: true,
      masteryLevelAfterAnswer: 5,
      source: PassportDiscoverySource.game,
      answeredAt: now,
    );
    final PassportProgressV2 afterProgress = beforeProgress.replaceEntity(
      masteredFrance,
      updatedAt: now,
    );
    final PlayerProfile beforeProfile = PlayerProfile.initial(createdAt: now);
    final PlayerProfile afterProfile = beforeProfile.copyWith(totalXp: 670);
    final PassportAchievementProgress beforeAchievements =
        PassportAchievementProgress.initial(createdAt: now);
    final PassportAchievementProgress afterAchievements =
        beforeAchievements.synchronize(
      snapshot: const PassportAchievementSnapshot(
        <PassportAchievementMetric, int>{
          PassportAchievementMetric.masteredEntities: 1,
        },
      ),
      synchronizedAt: now,
    );
    final PassportProgressNotificationBatch batch =
        PassportProgressNotificationBuilder.build(
      beforeProgress: beforeProgress,
      afterProgress: afterProgress,
      beforeProfile: beforeProfile,
      afterProfile: afterProfile,
      beforeCollections: _collections(
        profile: beforeProfile,
        progress: beforeProgress,
      ),
      afterCollections: _collections(
        profile: afterProfile,
        progress: afterProgress,
      ),
      beforeAchievements: beforeAchievements,
      afterAchievements: afterAchievements,
      countries: <GeoCountry>[france],
    );
    final Set<PassportProgressNotificationType> types = batch.items
        .map((PassportProgressNotification item) => item.type)
        .toSet();

    expect(types, contains(PassportProgressNotificationType.stamp));
    expect(types, contains(PassportProgressNotificationType.mastery));
    expect(types, isNot(contains(PassportProgressNotificationType.level)));
    expect(types, isNot(contains(PassportProgressNotificationType.title)));
    expect(types, contains(PassportProgressNotificationType.collection));
    expect(types, contains(PassportProgressNotificationType.achievement));
    expect(
      batch.items.any((PassportProgressNotification item) {
        return item.title == 'Cadre débloqué';
      }),
      isFalse,
    );
    expect(
      batch.items.any((PassportProgressNotification item) {
        return item.title == 'Arrière-plan débloqué';
      }),
      isFalse,
    );
    expect(
      batch.items.any((PassportProgressNotification item) {
        return item.type == PassportProgressNotificationType.collection &&
            item.detail == 'Premier tampon';
      }),
      isTrue,
    );
    expect(
      batch.items.where((PassportProgressNotification item) {
        return item.type == PassportProgressNotificationType.stamp;
      }).single.detail,
      'France',
    );
  });

  test('un petit palier XP ne crée aucun écran forcé', () {
    final PassportProgressV2 progress =
        PassportProgressV2.initial(createdAt: now);
    final PlayerProfile beforeProfile = PlayerProfile.initial(createdAt: now);
    final PlayerProfile afterProfile = beforeProfile.copyWith(totalXp: 100);
    final PassportAchievementProgress achievements =
        PassportAchievementProgress.initial(createdAt: now);

    final PassportProgressNotificationBatch batch =
        PassportProgressNotificationBuilder.build(
      beforeProgress: progress,
      afterProgress: progress,
      beforeProfile: beforeProfile,
      afterProfile: afterProfile,
      beforeCollections: _collections(
        profile: beforeProfile,
        progress: progress,
      ),
      afterCollections: _collections(
        profile: afterProfile,
        progress: progress,
      ),
      beforeAchievements: achievements,
      afterAchievements: achievements,
      countries: <GeoCountry>[france],
    );

    expect(batch.isEmpty, isTrue);
  });

  test('ne crée aucune fenêtre quand rien ne change', () {
    final PassportProgressV2 progress =
        PassportProgressV2.initial(createdAt: now);
    final PlayerProfile profile = PlayerProfile.initial(createdAt: now);
    final PassportAchievementProgress achievements =
        PassportAchievementProgress.initial(createdAt: now);
    final PassportCollectionSnapshot collections = _collections(
      profile: profile,
      progress: progress,
    );

    final PassportProgressNotificationBatch batch =
        PassportProgressNotificationBuilder.build(
      beforeProgress: progress,
      afterProgress: progress,
      beforeProfile: profile,
      afterProfile: profile,
      beforeCollections: collections,
      afterCollections: collections,
      beforeAchievements: achievements,
      afterAchievements: achievements,
      countries: <GeoCountry>[france],
    );

    expect(batch.isEmpty, isTrue);
  });
}

PassportCollectionSnapshot _collections({
  required PlayerProfile profile,
  required PassportProgressV2 progress,
}) {
  return PassportCollectionSnapshot(
    playerLevel: profile.currentLevel,
    discoveredEntities: progress.discoveredEntityCount,
    masteredEntities: progress.masteredEntityCount,
    countryStamps: progress.unlockedCountryStampCount,
    visitedEntities: progress.visitedEntityCount,
    gamesPlayed: profile.gamesPlayed,
    questionsPlayed: profile.totalAnswers,
    expeditionStars: 0,
    completedExpeditionLevels: 0,
    currentLicenseId: 1,
    explicitlyUnlockedItemIds: progress.unlockedCollectionItemIds,
  );
}

import '../../features/atlas/atlas_personal_progress.dart';
import '../../geo_engine/geo_entity_id.dart';
import '../../geobrain/country_mastery.dart';
import '../../geobrain/geobrain_profile.dart';
import '../../geobrain/geobrain_theme.dart';
import '../../geobrain/theme_mastery.dart';
import '../../game/passport/player_passport.dart';
import '../../player/player_profile.dart';
import 'passport_entity_progress.dart';
import 'passport_progress_rules.dart';
import 'passport_progress_v2.dart';

class PassportProgressMigrator {
  PassportProgressMigrator._();

  static PassportProgressV2 fromLegacy({
    required PlayerPassport passport,
    required PlayerProfile playerProfile,
    required GeoBrainProfile geoBrainProfile,
    required AtlasPersonalProgress atlasProgress,
    bool mergeLegacyGeoBrainPersonalLists = true,
    DateTime? migratedAt,
  }) {
    final DateTime migrationDate = migratedAt ?? DateTime.now();
    final Set<String> entityIds = <String>{
      ...geoBrainProfile.countries.keys.map(GeoEntityId.normalize),
      ...atlasProgress.visitedCountryIds.map(GeoEntityId.normalize),
      ...atlasProgress.wishlistCountryIds.map(GeoEntityId.normalize),
      ...atlasProgress.favoriteCountryIds.map(GeoEntityId.normalize),
    }..removeWhere((String entityId) => entityId.isEmpty);
    final Map<String, PassportEntityProgress> entities =
        <String, PassportEntityProgress>{};

    for (final String entityId in entityIds) {
      final CountryMastery? mastery = geoBrainProfile.countries[entityId];
      final bool isVisited = atlasProgress.visitedCountryIds.contains(entityId) ||
          (mergeLegacyGeoBrainPersonalLists &&
              (mastery?.isVisited ?? false));
      final bool isWishlisted = !isVisited &&
          (atlasProgress.wishlistCountryIds.contains(entityId) ||
              (mergeLegacyGeoBrainPersonalLists &&
                  (mastery?.isWishlisted ?? false)));
      final bool hasBeenSeen = mastery?.hasBeenSeen ?? false;
      final DateTime? discoveredAt = hasBeenSeen
          ? mastery?.lastReviewedAt ?? migrationDate
          : null;
      final DateTime? stampUnlockedAt = (mastery?.correctAnswers ?? 0) > 0
          ? mastery?.lastReviewedAt ?? migrationDate
          : null;
      final Map<PassportKnowledgeTheme, PassportThemeProgress> themes =
          <PassportKnowledgeTheme, PassportThemeProgress>{};

      if (mastery != null && mastery.hasBeenSeen) {
        if (mastery.themeMasteries.isEmpty) {
          themes[PassportKnowledgeTheme.location] = PassportThemeProgress(
            masteryLevel: mastery.masteryLevel,
            correctAnswers: mastery.correctAnswers,
            wrongAnswers: mastery.wrongAnswers,
            totalAttempts: mastery.totalAttempts,
            firstSeenAt: discoveredAt,
            lastAnsweredAt: mastery.lastReviewedAt,
            currentStreak: mastery.currentStreak,
            bestStreak: mastery.bestStreak,
            nextReviewAt: mastery.nextReviewAt,
          );
        } else {
          for (final MapEntry<GeoBrainTheme, ThemeMastery> entry
              in mastery.themeMasteries.entries) {
            if (!entry.value.hasBeenSeen) {
              continue;
            }
            final PassportKnowledgeTheme? passportTheme =
                PassportKnowledgeTheme.fromId(entry.key.id);
            if (passportTheme == null) {
              continue;
            }
            final ThemeMastery themeMastery = entry.value;
            themes[passportTheme] = PassportThemeProgress(
              masteryLevel: (themeMastery.score / 20).round().clamp(
                    PassportProgressRules.minimumMasteryLevel,
                    PassportProgressRules.masteredMasteryLevel,
                  ),
              correctAnswers: themeMastery.correctAnswers,
              wrongAnswers: themeMastery.wrongAnswers,
              totalAttempts: themeMastery.totalAttempts,
              firstSeenAt: themeMastery.firstLearnedAt ?? discoveredAt,
              lastAnsweredAt: themeMastery.lastReviewedAt,
              currentStreak: themeMastery.currentStreak,
              bestStreak: themeMastery.bestStreak,
              nextReviewAt: themeMastery.nextReviewAt,
            );
          }
        }
      }

      entities[entityId] = PassportEntityProgress.migrated(
        entityId: entityId,
        discoveredAt: discoveredAt,
        themes: themes,
        isVisited: isVisited,
        isWishlisted: isWishlisted,
        isFavorite: atlasProgress.favoriteCountryIds.contains(entityId),
        stampUnlockedAt: stampUnlockedAt,
      );
    }

    return PassportProgressV2(
      schemaVersion: PassportProgressV2.currentSchemaVersion,
      licenseProgress: passport,
      playerProfile: playerProfile,
      entities: Map<String, PassportEntityProgress>.unmodifiable(entities),
      migratedFromSchemaVersions: <String, int>{
        'playerPassport': passport.schemaVersion,
        'playerProfile': playerProfile.schemaVersion,
        'geoBrainProfile': geoBrainProfile.schemaVersion,
        'atlasPersonalProgress': 1,
      },
      createdAt: _earliestDate(<DateTime>[
        passport.createdAt,
        playerProfile.createdAt,
        geoBrainProfile.createdAt,
      ]),
      updatedAt: migrationDate,
    );
  }

  static PassportProgressV2 refreshExisting({
    required PassportProgressV2 existingProgress,
    required PlayerPassport passport,
    required PlayerProfile playerProfile,
    required GeoBrainProfile geoBrainProfile,
    required AtlasPersonalProgress atlasProgress,
    DateTime? synchronizedAt,
  }) {
    final DateTime synchronizationDate = synchronizedAt ?? DateTime.now();
    final PassportProgressV2 legacySnapshot = fromLegacy(
      passport: passport,
      playerProfile: playerProfile,
      geoBrainProfile: geoBrainProfile,
      atlasProgress: atlasProgress,
      mergeLegacyGeoBrainPersonalLists: false,
      migratedAt: synchronizationDate,
    );
    final Set<String> visitedIds = atlasProgress.visitedCountryIds
        .map(GeoEntityId.normalize)
        .where((String entityId) => entityId.isNotEmpty)
        .toSet();
    final Set<String> wishlistIds = atlasProgress.wishlistCountryIds
        .map(GeoEntityId.normalize)
        .where((String entityId) => entityId.isNotEmpty)
        .toSet();
    final Set<String> favoriteIds = atlasProgress.favoriteCountryIds
        .map(GeoEntityId.normalize)
        .where((String entityId) => entityId.isNotEmpty)
        .toSet();
    final Set<String> entityIds = <String>{
      ...existingProgress.entities.keys,
      ...legacySnapshot.entities.keys,
      ...visitedIds,
      ...wishlistIds,
      ...favoriteIds,
    };
    final Map<String, PassportEntityProgress> entities =
        <String, PassportEntityProgress>{};

    for (final String entityId in entityIds) {
      final PassportEntityProgress? existingEntity =
          existingProgress.entities[entityId];
      final PassportEntityProgress? legacyEntity =
          legacySnapshot.entities[entityId];
      PassportEntityProgress mergedEntity = existingEntity ??
          legacyEntity ??
          PassportEntityProgress.initial(entityId);

      if (existingEntity != null && legacyEntity != null) {
        mergedEntity = existingEntity.mergeLegacyKnowledge(legacyEntity);
      }

      entities[entityId] = mergedEntity.setPersonalStates(
        visited: visitedIds.contains(entityId),
        wishlisted: wishlistIds.contains(entityId),
        favorite: favoriteIds.contains(entityId),
      );
    }

    return PassportProgressV2(
      schemaVersion: PassportProgressV2.currentSchemaVersion,
      licenseProgress: passport,
      playerProfile: playerProfile,
      entities: Map<String, PassportEntityProgress>.unmodifiable(entities),
      unlockedCollectionItemIds: existingProgress.unlockedCollectionItemIds,
      completedAchievementTierDates:
          existingProgress.completedAchievementTierDates,
      migratedFromSchemaVersions: <String, int>{
        ...existingProgress.migratedFromSchemaVersions,
        ...legacySnapshot.migratedFromSchemaVersions,
      },
      createdAt: existingProgress.createdAt,
      updatedAt: synchronizationDate,
    );
  }

  static DateTime _earliestDate(List<DateTime> dates) {
    DateTime earliest = dates.first;

    for (final DateTime date in dates.skip(1)) {
      if (date.isBefore(earliest)) {
        earliest = date;
      }
    }

    return earliest;
  }
}

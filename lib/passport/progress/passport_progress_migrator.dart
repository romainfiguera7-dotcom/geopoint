import '../../features/atlas/atlas_personal_progress.dart';
import '../../geo_engine/geo_entity_id.dart';
import '../../geobrain/country_mastery.dart';
import '../../geobrain/geobrain_profile.dart';
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
        themes[PassportKnowledgeTheme.location] = PassportThemeProgress(
          masteryLevel: mastery.masteryLevel,
          correctAnswers: mastery.correctAnswers,
          wrongAnswers: mastery.wrongAnswers,
          totalAttempts: mastery.totalAttempts,
          firstSeenAt: discoveredAt,
          lastAnsweredAt: mastery.lastReviewedAt,
        );
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

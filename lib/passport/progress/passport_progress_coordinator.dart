import '../../features/atlas/atlas_personal_progress.dart';
import '../../features/atlas/atlas_personal_storage.dart';
import '../../game/passport/player_passport.dart';
import '../../geobrain/geobrain_profile.dart';
import '../../player/player_profile.dart';
import '../achievements/passport_achievement_progress.dart';
import '../achievements/passport_achievement_storage.dart';
import 'passport_progress_migrator.dart';
import 'passport_progress_storage.dart';
import 'passport_progress_v2.dart';

class PassportProgressCoordinator {
  PassportProgressCoordinator._();

  static Future<PassportProgressV2> synchronize({
    required PlayerPassport passport,
    required PlayerProfile playerProfile,
    required GeoBrainProfile geoBrainProfile,
    AtlasPersonalProgress? atlasProgress,
    DateTime? synchronizedAt,
    bool preferProvidedPassport = false,
    bool preferProvidedPlayerProfile = false,
    bool preserveUnifiedPersonalLists = false,
  }) async {
    AtlasPersonalProgress personalProgress =
        atlasProgress ?? await AtlasPersonalStorage.load();
    final PassportProgressV2? existingProgress =
        await PassportProgressStorage.load();
    final PassportAchievementProgress legacyAchievements =
        await PassportAchievementStorage.load();
    final bool isFirstMigration = existingProgress == null;
    if (existingProgress != null && preserveUnifiedPersonalLists) {
      personalProgress = _personalProgressFrom(existingProgress);
    }
    final PlayerPassport effectivePassport = existingProgress == null
        ? passport
        : preferProvidedPassport
            ? passport
            : _newestPassport(existingProgress.licenseProgress, passport);
    final PlayerProfile effectivePlayerProfile = existingProgress == null
        ? playerProfile
        : preferProvidedPlayerProfile
            ? playerProfile
            : _newestPlayerProfile(existingProgress.playerProfile, playerProfile);
    PassportProgressV2 progress = existingProgress == null
        ? PassportProgressMigrator.fromLegacy(
            passport: effectivePassport,
            playerProfile: effectivePlayerProfile,
            geoBrainProfile: geoBrainProfile,
            atlasProgress: personalProgress,
            mergeLegacyGeoBrainPersonalLists: true,
            migratedAt: synchronizedAt,
          )
        : PassportProgressMigrator.refreshExisting(
            existingProgress: existingProgress,
            passport: effectivePassport,
            playerProfile: effectivePlayerProfile,
            geoBrainProfile: geoBrainProfile,
            atlasProgress: personalProgress,
            synchronizedAt: synchronizedAt,
          );
    progress = progress.recordAchievementTiers(
      legacyAchievements.completedAtByTierId,
      recordedAt: synchronizedAt,
    );
    progress = progress.recordMigrationVersions(
      <String, int>{
        'passportAchievements': legacyAchievements.schemaVersion,
      },
      recordedAt: synchronizedAt,
    );

    if (isFirstMigration || preserveUnifiedPersonalLists) {
      final AtlasPersonalProgress mergedPersonalProgress =
          AtlasPersonalProgress.fromJson(
        <String, dynamic>{
          'visitedCountryIds': progress.entities.values
              .where((entity) => entity.isVisited)
              .map((entity) => entity.entityId)
              .toList(growable: false),
          'wishlistCountryIds': progress.entities.values
              .where((entity) => entity.isWishlisted)
              .map((entity) => entity.entityId)
              .toList(growable: false),
          'favoriteCountryIds': progress.entities.values
              .where((entity) => entity.isFavorite)
              .map((entity) => entity.entityId)
              .toList(growable: false),
        },
      );

      await AtlasPersonalStorage.save(mergedPersonalProgress);
    }

    await PassportProgressStorage.save(progress);
    await PassportAchievementStorage.save(
      legacyAchievements.mergeCompletedTierDates(
        progress.completedAchievementTierDates,
      ),
    );

    return progress;
  }

  static PlayerPassport _newestPassport(
    PlayerPassport unified,
    PlayerPassport legacy,
  ) {
    if (legacy.totalAttempts > unified.totalAttempts ||
        legacy.validatedStampCount > unified.validatedStampCount ||
        legacy.currentLicenseId > unified.currentLicenseId) {
      return legacy;
    }
    final bool sameHistory = legacy.playerId == unified.playerId &&
        legacy.createdAt == unified.createdAt;
    if (sameHistory && legacy.updatedAt.isAfter(unified.updatedAt)) {
      return legacy;
    }
    return unified;
  }

  static AtlasPersonalProgress _personalProgressFrom(
    PassportProgressV2 progress,
  ) {
    return AtlasPersonalProgress.fromJson(
      <String, dynamic>{
        'visitedCountryIds': progress.entities.values
            .where((entity) => entity.isVisited)
            .map((entity) => entity.entityId)
            .toList(growable: false),
        'wishlistCountryIds': progress.entities.values
            .where((entity) => entity.isWishlisted)
            .map((entity) => entity.entityId)
            .toList(growable: false),
        'favoriteCountryIds': progress.entities.values
            .where((entity) => entity.isFavorite)
            .map((entity) => entity.entityId)
            .toList(growable: false),
      },
    );
  }

  static PlayerProfile _newestPlayerProfile(
    PlayerProfile unified,
    PlayerProfile legacy,
  ) {
    if (legacy.gamesPlayed > unified.gamesPlayed ||
        legacy.totalAnswers > unified.totalAnswers ||
        legacy.totalXp > unified.totalXp) {
      return legacy;
    }
    final DateTime? unifiedPlayedAt = unified.lastPlayedAt;
    final DateTime? legacyPlayedAt = legacy.lastPlayedAt;
    if (legacyPlayedAt != null &&
        (unifiedPlayedAt == null || legacyPlayedAt.isAfter(unifiedPlayedAt))) {
      return legacy;
    }
    return unified;
  }
}

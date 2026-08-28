import '../../features/atlas/atlas_personal_progress.dart';
import '../../features/atlas/atlas_personal_storage.dart';
import '../../game/passport/player_passport.dart';
import '../../geobrain/geobrain_profile.dart';
import '../../player/player_profile.dart';
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
  }) async {
    final AtlasPersonalProgress personalProgress =
        atlasProgress ?? await AtlasPersonalStorage.load();
    final PassportProgressV2? existingProgress =
        await PassportProgressStorage.load();
    final bool isFirstMigration = existingProgress == null;
    final PassportProgressV2 progress = PassportProgressMigrator.fromLegacy(
      passport: passport,
      playerProfile: playerProfile,
      geoBrainProfile: geoBrainProfile,
      atlasProgress: personalProgress,
      mergeLegacyGeoBrainPersonalLists: isFirstMigration,
      migratedAt: synchronizedAt,
    );

    if (isFirstMigration) {
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

    return progress;
  }
}

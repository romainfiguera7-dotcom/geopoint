import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/atlas/atlas_personal_progress.dart';
import 'package:geopoint/game/passport/player_passport.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/passport/progress/passport_progress_migrator.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';
import 'package:geopoint/passport/progress/passport_progress_v2.dart';
import 'package:geopoint/player/player_profile.dart';

void main() {
  group('PassportProgressMigrator', () {
    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    final DateTime reviewedAt = DateTime.utc(2026, 8, 20);
    final DateTime migratedAt = DateTime.utc(2026, 8, 28);

    test('fusionne GeoBrain et Atlas sans perdre les états personnels', () {
      final GeoBrainProfile geoBrain = GeoBrainProfile(
        schemaVersion: GeoBrainProfile.currentSchemaVersion,
        countries: <String, CountryMastery>{
          'FRA': CountryMastery(
            countryId: 'FRA',
            masteryLevel: 3,
            correctAnswers: 4,
            wrongAnswers: 1,
            totalAttempts: 5,
            currentStreak: 2,
            bestStreak: 3,
            lastReviewedAt: reviewedAt,
            nextReviewAt: reviewedAt.add(const Duration(days: 7)),
            isWishlisted: true,
            isVisited: false,
          ),
        },
        createdAt: createdAt,
        updatedAt: reviewedAt,
      );
      final AtlasPersonalProgress atlas = AtlasPersonalProgress.fromJson(
        <String, dynamic>{
          'visitedCountryIds': <String>['FRA'],
          'wishlistCountryIds': <String>['FRA', 'ESP'],
          'favoriteCountryIds': <String>['FRA'],
        },
      );

      final PassportProgressV2 result = PassportProgressMigrator.fromLegacy(
        passport: PlayerPassport.initial(createdAt: createdAt),
        playerProfile: PlayerProfile.initial(createdAt: createdAt),
        geoBrainProfile: geoBrain,
        atlasProgress: atlas,
        migratedAt: migratedAt,
      );

      expect(result.entities.keys, containsAll(<String>['FRA', 'ESP']));
      expect(result.progressFor('FRA').isVisited, isTrue);
      expect(result.progressFor('FRA').isWishlisted, isFalse);
      expect(result.progressFor('ESP').isWishlisted, isTrue);
      expect(result.progressFor('FRA').isFavorite, isTrue);
      expect(
        result.progressFor('FRA').locationProgress.totalAttempts,
        5,
      );
      expect(
        result.progressFor('FRA').locationProgress.correctAnswers,
        4,
      );
      expect(
        result.progressFor('FRA').stampStage,
        PassportCountryStampStage.learned,
      );
      expect(result.discoveredEntityCount, 1);
      expect(result.unlockedCountryStampCount, 1);
      expect(result.licenseProgress.currentLicenseId, 1);
      expect(result.playerProfile.totalXp, 0);
    });

    test('un pays uniquement visité ne devient pas découvert', () {
      final AtlasPersonalProgress atlas = AtlasPersonalProgress.fromJson(
        <String, dynamic>{
          'visitedCountryIds': <String>['JPN'],
        },
      );

      final PassportProgressV2 result = PassportProgressMigrator.fromLegacy(
        passport: PlayerPassport.initial(createdAt: createdAt),
        playerProfile: PlayerProfile.initial(createdAt: createdAt),
        geoBrainProfile: GeoBrainProfile.initial(createdAt: createdAt),
        atlasProgress: atlas,
        migratedAt: migratedAt,
      );

      expect(result.progressFor('JPN').isVisited, isTrue);
      expect(
        result.progressFor('JPN').learningState,
        PassportLearningState.undiscovered,
      );
      expect(result.progressFor('JPN').isMastered, isFalse);
    });

    test('après migration l’Atlas devient la référence des listes', () {
      final GeoBrainProfile geoBrain = GeoBrainProfile(
        schemaVersion: GeoBrainProfile.currentSchemaVersion,
        countries: <String, CountryMastery>{
          'FRA': CountryMastery(
            countryId: 'FRA',
            masteryLevel: 0,
            correctAnswers: 0,
            wrongAnswers: 0,
            totalAttempts: 0,
            currentStreak: 0,
            bestStreak: 0,
            lastReviewedAt: null,
            nextReviewAt: null,
            isWishlisted: true,
            isVisited: true,
          ),
        },
        createdAt: createdAt,
        updatedAt: migratedAt,
      );

      final PassportProgressV2 result = PassportProgressMigrator.fromLegacy(
        passport: PlayerPassport.initial(createdAt: createdAt),
        playerProfile: PlayerProfile.initial(createdAt: createdAt),
        geoBrainProfile: geoBrain,
        atlasProgress: AtlasPersonalProgress.initial(),
        mergeLegacyGeoBrainPersonalLists: false,
        migratedAt: migratedAt,
      );

      expect(result.progressFor('FRA').isVisited, isFalse);
      expect(result.progressFor('FRA').isWishlisted, isFalse);
    });

    test('une progression thématique existante n’est jamais écrasée', () {
      final PassportProgressV2 existing = PassportProgressV2.initial(
        createdAt: createdAt,
      ).registerAnswer(
        entityId: 'FRA',
        theme: PassportKnowledgeTheme.flag,
        isCorrect: true,
        source: PassportDiscoverySource.game,
        answeredAt: reviewedAt,
      );
      final GeoBrainProfile geoBrain = GeoBrainProfile(
        schemaVersion: GeoBrainProfile.currentSchemaVersion,
        countries: <String, CountryMastery>{
          'FRA': CountryMastery(
            countryId: 'FRA',
            masteryLevel: 1,
            correctAnswers: 1,
            wrongAnswers: 0,
            totalAttempts: 1,
            currentStreak: 1,
            bestStreak: 1,
            lastReviewedAt: reviewedAt,
            nextReviewAt: reviewedAt.add(const Duration(days: 1)),
            isWishlisted: false,
            isVisited: false,
          ),
        },
        createdAt: createdAt,
        updatedAt: reviewedAt,
      );

      final PassportProgressV2 result =
          PassportProgressMigrator.refreshExisting(
        existingProgress: existing,
        passport: PlayerPassport.initial(createdAt: createdAt),
        playerProfile: PlayerProfile.initial(createdAt: createdAt),
        geoBrainProfile: geoBrain,
        atlasProgress: AtlasPersonalProgress.initial(),
        synchronizedAt: migratedAt,
      );

      expect(result.progressFor('FRA').locationProgress.totalAttempts, 0);
      expect(
        result.progressFor('FRA').progressFor(PassportKnowledgeTheme.flag)
            .totalAttempts,
        1,
      );
      expect(result.progressFor('FRA').hasBeenDiscovered, isTrue);
    });

    test('la sauvegarde V2 peut être relue sans modification', () {
      final PassportProgressV2 source = PassportProgressMigrator.fromLegacy(
        passport: PlayerPassport.initial(createdAt: createdAt),
        playerProfile: PlayerProfile.initial(createdAt: createdAt),
        geoBrainProfile: GeoBrainProfile.initial(createdAt: createdAt),
        atlasProgress: AtlasPersonalProgress.fromJson(
          <String, dynamic>{
            'wishlistCountryIds': <String>['CAN'],
          },
        ),
        migratedAt: migratedAt,
      );
      final PassportProgressV2 restored =
          PassportProgressV2.fromJson(source.toJson());

      expect(restored.schemaVersion, PassportProgressV2.currentSchemaVersion);
      expect(restored.progressFor('CAN').isWishlisted, isTrue);
      expect(
        restored.licenseProgress.playerId,
        source.licenseProgress.playerId,
      );
      expect(
        restored.playerProfile.totalXp,
        source.playerProfile.totalXp,
      );
      expect(
        restored.migratedFromSchemaVersions,
        source.migratedFromSchemaVersions,
      );
    });
  });
}

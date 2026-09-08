import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/atlas/atlas_personal_progress.dart';
import 'package:geopoint/features/atlas/atlas_personal_storage.dart';
import 'package:geopoint/game/passport/player_passport.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/passport/progress/passport_progress_coordinator.dart';
import 'package:geopoint/passport/progress/passport_entity_progress.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';
import 'package:geopoint/passport/progress/passport_progress_storage.dart';
import 'package:geopoint/passport/progress/passport_progress_v2.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/player/player_statistics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la migration est sauvegardée sans perdre les anciennes données', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    final DateTime migratedAt = DateTime.utc(2026, 8, 28);
    final PlayerProfile playerProfile = PlayerProfile(
      schemaVersion: PlayerProfile.currentSchemaVersion,
      playerId: 'local_player',
      displayName: 'Voyageur',
      avatarId: 'default',
      totalXp: 17740,
      gamesPlayed: 178,
      correctAnswers: 600,
      totalAnswers: 890,
      totalScore: 55000,
      statisticsByMode: const {},
      detailedStatistics: DetailedPlayerStatistics.initial(),
      totalDistanceInKilometers: 12345,
      totalElapsedSeconds: 45678,
      createdAt: createdAt,
      lastPlayedAt: migratedAt,
    );
    final GeoBrainProfile geoBrainProfile = GeoBrainProfile(
      schemaVersion: GeoBrainProfile.currentSchemaVersion,
      countries: <String, CountryMastery>{
        'FRA': CountryMastery(
          countryId: 'FRA',
          masteryLevel: 5,
          correctAnswers: 8,
          wrongAnswers: 2,
          totalAttempts: 10,
          currentStreak: 3,
          bestStreak: 5,
          lastReviewedAt: migratedAt,
          nextReviewAt: migratedAt.add(const Duration(days: 45)),
          isWishlisted: false,
          isVisited: true,
        ),
      },
      createdAt: createdAt,
      updatedAt: migratedAt,
    );

    await PassportProgressCoordinator.synchronize(
      passport: PlayerPassport.initial(createdAt: createdAt),
      playerProfile: playerProfile,
      geoBrainProfile: geoBrainProfile,
      atlasProgress: AtlasPersonalProgress.initial(),
      synchronizedAt: migratedAt,
    );

    final PassportProgressV2? saved = await PassportProgressStorage.load();
    final AtlasPersonalProgress atlas = await AtlasPersonalStorage.load();

    expect(saved, isNotNull);
    expect(saved!.playerProfile.totalXp, 17740);
    expect(saved.playerProfile.gamesPlayed, 178);
    expect(saved.progressFor('FRA').isMastered, isTrue);
    expect(saved.progressFor('FRA').isVisited, isTrue);
    expect(atlas.visitedCountryIds, contains('FRA'));

    final PassportProgressV2 withFlagProgress = saved.registerAnswer(
      entityId: 'FRA',
      theme: PassportKnowledgeTheme.flag,
      isCorrect: true,
      source: PassportDiscoverySource.game,
      answeredAt: migratedAt.add(const Duration(seconds: 1)),
    );
    await PassportProgressStorage.save(withFlagProgress);

    final AtlasPersonalProgress emptiedAtlas = AtlasPersonalProgress.initial();
    await AtlasPersonalStorage.save(emptiedAtlas);
    await PassportProgressCoordinator.synchronize(
      passport: PlayerPassport.initial(createdAt: createdAt),
      playerProfile: playerProfile,
      geoBrainProfile: geoBrainProfile,
      atlasProgress: emptiedAtlas,
      synchronizedAt: migratedAt.add(const Duration(minutes: 1)),
    );

    final PassportProgressV2? updated = await PassportProgressStorage.load();

    expect(updated, isNotNull);
    expect(updated!.progressFor('FRA').isVisited, isFalse);
    expect(
      updated.progressFor('FRA').progressFor(PassportKnowledgeTheme.flag)
          .totalAttempts,
      1,
    );
    expect(updated.progressFor('FRA').locationProgress.totalAttempts, 10);
    expect(updated.playerProfile.totalXp, 17740);
    expect(updated.playerProfile.gamesPlayed, 178);
  });

  test('le modèle unifié reste prioritaire si les anciens fichiers manquent',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    final PassportProgressV2 unified = PassportProgressV2.initial(
      createdAt: createdAt,
    ).replaceEntity(
      PassportEntityProgress.initial('FRA').setVisited(true),
      updatedAt: createdAt,
    ).recordAchievementTiers(
      <String, DateTime>{'world_discovery_10': createdAt},
      recordedAt: createdAt,
    );
    final PassportProgressV2 withPlayer = PassportProgressV2(
      schemaVersion: PassportProgressV2.currentSchemaVersion,
      licenseProgress: unified.licenseProgress,
      playerProfile: unified.playerProfile.copyWith(
        totalXp: 17740,
        gamesPlayed: 178,
        totalAnswers: 890,
      ),
      entities: unified.entities,
      unlockedCollectionItemIds: unified.unlockedCollectionItemIds,
      completedAchievementTierDates:
          unified.completedAchievementTierDates,
      migratedFromSchemaVersions: unified.migratedFromSchemaVersions,
      createdAt: unified.createdAt,
      updatedAt: unified.updatedAt,
    );
    await PassportProgressStorage.save(withPlayer);

    final PassportProgressV2 restarted =
        await PassportProgressCoordinator.synchronize(
      passport: PlayerPassport.initial(
        createdAt: createdAt.add(const Duration(days: 1)),
      ),
      playerProfile: PlayerProfile.initial(
        createdAt: createdAt.add(const Duration(days: 1)),
      ),
      geoBrainProfile: GeoBrainProfile.initial(createdAt: createdAt),
      atlasProgress: AtlasPersonalProgress.initial(),
      preserveUnifiedPersonalLists: true,
      synchronizedAt: createdAt.add(const Duration(days: 2)),
    );

    expect(restarted.playerProfile.totalXp, 17740);
    expect(restarted.playerProfile.gamesPlayed, 178);
    expect(restarted.playerProfile.totalAnswers, 890);
    expect(restarted.progressFor('FRA').isVisited, isTrue);
    expect(
      restarted.completedAchievementTierDates,
      contains('world_discovery_10'),
    );
    expect(
      (await AtlasPersonalStorage.load()).visitedCountryIds,
      contains('FRA'),
    );
  });
}

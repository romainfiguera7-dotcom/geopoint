import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/game/passport/passport_storage.dart';
import 'package:geopoint/game/passport/player_passport.dart';
import 'package:geopoint/player/player_identity_service.dart';
import 'package:geopoint/player/player_identity_storage.dart';
import 'package:geopoint/player/player_online_identity.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/player/player_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime.utc(2026, 9, 9, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('migre les anciens identifiants sans perdre la progression', () async {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 1, 1),
    ).copyWith(
      totalXp: 1250,
      gamesPlayed: 12,
      correctAnswers: 40,
      totalAnswers: 60,
      totalScore: 5400,
    );
    final PlayerPassport passport = PlayerPassport.initial(
      createdAt: DateTime.utc(2026, 1, 1),
    ).copyWith(currentLicenseId: 3);

    final PlayerIdentityBootstrapResult result =
        await PlayerIdentityService.bootstrap(
      playerProfile: profile,
      passport: passport,
      nowUtc: now,
      installationIdFactory: () => 'install_fixed',
      localPlayerIdFactory: () => 'player_fixed',
    );

    expect(result.status, PlayerIdentityBootstrapStatus.created);
    expect(result.identity.localPlayerId, 'player_fixed');
    expect(result.playerProfile.playerId, 'player_fixed');
    expect(result.passport.playerId, 'player_fixed');
    expect(result.playerProfile.totalXp, 1250);
    expect(result.playerProfile.gamesPlayed, 12);
    expect(result.playerProfile.totalScore, 5400);
    expect(result.passport.currentLicenseId, 3);
    expect((await PlayerStorage.load())?.totalXp, 1250);
    expect((await PassportStorage.load())?.currentLicenseId, 3);
    expect((await PlayerIdentityStorage.load())?.localPlayerId, 'player_fixed');
  });

  test('réutilise exactement la même identité au redémarrage', () async {
    final PlayerIdentityBootstrapResult first =
        await PlayerIdentityService.bootstrap(
      playerProfile: PlayerProfile.initial(createdAt: now),
      passport: PlayerPassport.initial(createdAt: now),
      nowUtc: now,
      installationIdFactory: () => 'install_fixed',
      localPlayerIdFactory: () => 'player_fixed',
    );
    final PlayerIdentityBootstrapResult second =
        await PlayerIdentityService.bootstrap(
      playerProfile: first.playerProfile,
      passport: first.passport,
      nowUtc: now.add(const Duration(days: 1)),
      installationIdFactory: () => throw StateError('ne doit pas être appelé'),
      localPlayerIdFactory: () => throw StateError('ne doit pas être appelé'),
    );

    expect(second.status, PlayerIdentityBootstrapStatus.restored);
    expect(second.identity.installationId, 'install_fixed');
    expect(second.identity.localPlayerId, 'player_fixed');
  });

  test('répare une migration interrompue au démarrage suivant', () async {
    await PlayerIdentityStorage.save(
      PlayerOnlineIdentity.local(
        installationId: 'install_fixed',
        localPlayerId: 'player_fixed',
        createdAtUtc: now,
      ),
    );

    final PlayerIdentityBootstrapResult result =
        await PlayerIdentityService.bootstrap(
      playerProfile: PlayerProfile.initial(createdAt: now).copyWith(
        totalXp: 900,
        gamesPlayed: 8,
      ),
      passport: PlayerPassport.initial(createdAt: now).copyWith(
        currentLicenseId: 2,
      ),
      nowUtc: now.add(const Duration(minutes: 1)),
    );

    expect(
      result.status,
      PlayerIdentityBootstrapStatus.repairedLocalProfiles,
    );
    expect(result.playerProfile.playerId, 'player_fixed');
    expect(result.playerProfile.totalXp, 900);
    expect(result.passport.playerId, 'player_fixed');
    expect(result.passport.currentLicenseId, 2);
  });

  test('conserve un identifiant joueur déjà personnalisé', () async {
    final PlayerIdentityBootstrapResult result =
        await PlayerIdentityService.bootstrap(
      playerProfile: PlayerProfile.initial(
        playerId: 'existing_player',
        createdAt: now,
      ),
      passport: PlayerPassport.initial(createdAt: now),
      nowUtc: now,
      installationIdFactory: () => 'install_fixed',
      localPlayerIdFactory: () => 'unused_player',
    );

    expect(result.identity.localPlayerId, 'existing_player');
    expect(result.playerProfile.playerId, 'existing_player');
    expect(result.passport.playerId, 'existing_player');
  });
}

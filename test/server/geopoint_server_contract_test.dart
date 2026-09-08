import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/game/passport/player_passport.dart';
import 'package:geopoint/player/player_online_identity.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/server/geopoint_server_contract.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 10, 12);

  PlayerOnlineIdentity identity() {
    return PlayerOnlineIdentity.local(
      installationId: 'install_test',
      localPlayerId: 'player_test',
      createdAtUtc: now,
    );
  }

  test('l’inscription signale la présence d’une progression locale', () {
    final PlayerIdentityRegistrationRequest request =
        PlayerIdentityRegistrationRequest.fromLocalProgress(
      identity: identity(),
      playerProfile: PlayerProfile.initial(
        displayName: 'Explorateur',
        createdAt: now,
      ).copyWith(totalXp: 900),
      passport: PlayerPassport.initial(createdAt: now),
    );
    final Map<String, dynamic> json = request.toJson();

    expect(json['apiVersion'], 1);
    expect(json['localPlayerId'], 'player_test');
    expect(json['hasLocalProgress'], isTrue);
    expect(json['profileType'], 'adult');
    expect(json, isNot(contains('email')));
    expect(json, isNot(contains('token')));
  });

  test('l’inscription transmet uniquement la tranche d’âge enfant', () {
    final PlayerIdentityRegistrationRequest request =
        PlayerIdentityRegistrationRequest.fromLocalProgress(
      identity: identity(),
      playerProfile: PlayerProfile.initial(createdAt: now)
          .activateChildProtection(PlayerChildAgeGroup.ages12To14),
      passport: PlayerPassport.initial(createdAt: now),
    );
    final Map<String, dynamic> json = request.toJson();

    expect(json['profileType'], 'child');
    expect(json['childAgeGroup'], '12_14');
    expect(json, isNot(contains('birthDate')));
  });

  test('la photographie de migration conserve les totaux utiles', () {
    final PlayerProfileMigrationRequest request =
        PlayerProfileMigrationRequest.fromLocalProgress(
      identity: identity(),
      playerProfile: PlayerProfile.initial(createdAt: now).copyWith(
        totalXp: 1250,
        gamesPlayed: 12,
        totalScore: 5400,
      ),
      passport: PlayerPassport.initial(createdAt: now).copyWith(
        currentLicenseId: 3,
      ),
    );
    final Map<String, dynamic> json = request.toJson();
    final Map<String, dynamic> profile =
        json['profile'] as Map<String, dynamic>;
    final Map<String, dynamic> passport =
        json['passport'] as Map<String, dynamic>;

    expect(profile['totalXp'], 1250);
    expect(profile['gamesPlayed'], 12);
    expect(profile['totalScore'], 5400);
    expect(passport['currentLicenseId'], 3);
  });

  test('refuse une version serveur incompatible', () {
    expect(
      () => PlayerIdentityRegistrationResponse.fromJson(<String, dynamic>{
        'apiVersion': 99,
        'onlinePlayerId': 'online_test',
        'providerId': 'firebase',
        'migrationRequired': false,
        'migrationStatus': 'not_required',
        'serverNowUtc': now.toIso8601String(),
      }),
      throwsFormatException,
    );
  });

  test('décode la protection enfant décidée par Firebase', () {
    final PlayerIdentityRegistrationResponse response =
        PlayerIdentityRegistrationResponse.fromJson(<String, dynamic>{
      'apiVersion': 1,
      'onlinePlayerId': 'online_child',
      'providerId': 'firebase',
      'migrationRequired': false,
      'migrationStatus': 'not_required',
      'serverNowUtc': now.toIso8601String(),
      'profileType': 'child',
      'childProtectionEnabled': true,
      'childAgeGroup': '9_11',
    });

    expect(response.isChildProfile, true);
    expect(response.childAgeGroup, PlayerChildAgeGroup.ages9To11);
  });

  test('le serveur expose uniquement des capacités connues', () {
    final GeoPointServerStatus status = GeoPointServerStatus.fromJson(
      <String, dynamic>{
        'apiVersion': 1,
        'schemaVersion': 1,
        'region': 'europe-west1',
        'serverNowUtc': now.toIso8601String(),
        'capabilities': <String>[
          'identity_registration',
          'profile_migration_queue',
        ],
      },
    );

    expect(status.region, 'europe-west1');
    expect(status.capabilities, contains('identity_registration'));
  });
}

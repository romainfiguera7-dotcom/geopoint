import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/game/passport/player_passport.dart';
import 'package:geopoint/player/player_identity_storage.dart';
import 'package:geopoint/player/player_online_identity.dart';
import 'package:geopoint/player/player_online_link_service.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/server/geopoint_server_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeServerGateway implements GeoPointServerGateway {
  _FakeServerGateway({
    required this.registration,
    this.migration,
    this.migrationStatus,
    this.registrationError,
  });

  final PlayerIdentityRegistrationResponse registration;
  final PlayerProfileMigrationResponse? migration;
  final PlayerProfileMigrationStatusResponse? migrationStatus;
  final Object? registrationError;
  int migrationCalls = 0;

  @override
  Future<GeoPointServerStatus> getStatus() {
    throw UnimplementedError();
  }

  @override
  Future<PlayerProfileMigrationStatusResponse> getProfileMigrationStatus() async {
    return migrationStatus!;
  }

  @override
  Future<PlayerIdentityRegistrationResponse> registerPlayerIdentity(
    PlayerIdentityRegistrationRequest request,
  ) async {
    if (registrationError != null) {
      throw registrationError!;
    }
    return registration;
  }

  @override
  Future<PlayerProfileMigrationResponse> submitProfileMigration(
    PlayerProfileMigrationRequest request,
  ) async {
    migrationCalls += 1;
    return migration!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime.utc(2026, 9, 10, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  PlayerOnlineIdentity localIdentity() {
    return PlayerOnlineIdentity.local(
      installationId: 'install_test',
      localPlayerId: 'player_test',
      createdAtUtc: now,
    );
  }

  PlayerIdentityRegistrationResponse registration({
    required bool migrationRequired,
    required GeoPointProfileMigrationStatus status,
  }) {
    return PlayerIdentityRegistrationResponse(
      onlinePlayerId: 'firebase_uid_test',
      providerId: 'firebase',
      migrationRequired: migrationRequired,
      migrationStatus: status,
      serverNowUtc: now,
    );
  }

  test('active immédiatement un nouveau profil sans progression', () async {
    final _FakeServerGateway gateway = _FakeServerGateway(
      registration: registration(
        migrationRequired: false,
        status: GeoPointProfileMigrationStatus.notRequired,
      ),
    );
    final PlayerOnlineLinkReport report = await PlayerOnlineLinkService.link(
      identity: localIdentity(),
      playerProfile: PlayerProfile.initial(createdAt: now),
      passport: PlayerPassport.initial(createdAt: now),
      gateway: gateway,
    );

    expect(report.status, PlayerOnlineLinkStatus.online);
    expect(report.identity.rankingPlayerId, 'firebase_uid_test');
    expect(gateway.migrationCalls, 0);
    expect((await PlayerIdentityStorage.load())?.isLinked, isTrue);
  });

  test('conserve un ancien profil en attente de validation', () async {
    final _FakeServerGateway gateway = _FakeServerGateway(
      registration: registration(
        migrationRequired: true,
        status: GeoPointProfileMigrationStatus.requiredMigration,
      ),
      migration: PlayerProfileMigrationResponse(
        requestId: 'profile_v1_test',
        status: GeoPointProfileMigrationStatus.pendingServerValidation,
        serverNowUtc: now,
      ),
    );
    final PlayerOnlineLinkReport report = await PlayerOnlineLinkService.link(
      identity: localIdentity(),
      playerProfile: PlayerProfile.initial(createdAt: now).copyWith(
        totalXp: 1250,
      ),
      passport: PlayerPassport.initial(createdAt: now),
      gateway: gateway,
    );

    expect(report.status, PlayerOnlineLinkStatus.migrationPending);
    expect(report.identity.isMigrationPending, isTrue);
    expect(report.identity.rankingPlayerId, isNull);
    expect(report.migrationRequestId, 'profile_v1_test');
  });

  test('active le compte lorsque le serveur termine la migration', () async {
    final PlayerOnlineIdentity pending = localIdentity()
        .prepareOnlineMigration(
          providerId: 'firebase',
          onlinePlayerId: 'firebase_uid_test',
          requestedAtUtc: now,
        );
    final _FakeServerGateway gateway = _FakeServerGateway(
      registration: registration(
        migrationRequired: true,
        status: GeoPointProfileMigrationStatus.pendingServerValidation,
      ),
      migrationStatus: PlayerProfileMigrationStatusResponse(
        status: GeoPointProfileMigrationStatus.completed,
        requestId: 'profile_v1_test',
        serverNowUtc: now.add(const Duration(minutes: 2)),
      ),
    );

    final PlayerOnlineLinkReport report =
        await PlayerOnlineLinkService.refreshMigration(
      identity: pending,
      gateway: gateway,
    );

    expect(report.status, PlayerOnlineLinkStatus.online);
    expect(report.identity.isLinked, isTrue);
  });

  test('une panne ne détruit pas l’identité locale', () async {
    final PlayerOnlineIdentity identity = localIdentity();
    final _FakeServerGateway gateway = _FakeServerGateway(
      registration: registration(
        migrationRequired: false,
        status: GeoPointProfileMigrationStatus.notRequired,
      ),
      registrationError: StateError('hors ligne'),
    );

    final PlayerOnlineLinkReport report = await PlayerOnlineLinkService.link(
      identity: identity,
      playerProfile: PlayerProfile.initial(createdAt: now),
      passport: PlayerPassport.initial(createdAt: now),
      gateway: gateway,
    );

    expect(report.status, PlayerOnlineLinkStatus.serverUnavailable);
    expect(report.identity.localPlayerId, identity.localPlayerId);
    expect(report.identity.isLinked, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/player_online_identity.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 9, 12);

  test('une identité locale ne peut pas envoyer de classement officiel', () {
    final PlayerOnlineIdentity identity = PlayerOnlineIdentity.local(
      installationId: 'install_001',
      localPlayerId: 'player_001',
      createdAtUtc: now,
    );

    expect(identity.status, PlayerOnlineIdentityStatus.localOnly);
    expect(identity.isLinked, isFalse);
    expect(identity.rankingPlayerId, isNull);
  });

  test('la migration doit être confirmée avant d’activer le compte', () {
    final PlayerOnlineIdentity pending = PlayerOnlineIdentity.local(
      installationId: 'install_001',
      localPlayerId: 'player_001',
      createdAtUtc: now,
    ).prepareOnlineMigration(
      providerId: 'supabase',
      onlinePlayerId: 'online_001',
      requestedAtUtc: now.add(const Duration(minutes: 1)),
    );

    expect(pending.isMigrationPending, isTrue);
    expect(pending.rankingPlayerId, isNull);

    final PlayerOnlineIdentity online = pending.confirmMigration(
      migratedAtUtc: now.add(const Duration(minutes: 2)),
    );
    expect(online.isLinked, isTrue);
    expect(online.rankingPlayerId, 'online_001');
  });

  test('la sérialisation ne contient aucun secret de connexion', () {
    final PlayerOnlineIdentity source = PlayerOnlineIdentity.local(
      installationId: 'install_001',
      localPlayerId: 'player_001',
      createdAtUtc: now,
    ).prepareOnlineMigration(
      providerId: 'provider_test',
      onlinePlayerId: 'online_001',
      requestedAtUtc: now,
    ).confirmMigration(migratedAtUtc: now);
    final Map<String, dynamic> json = source.toJson();
    final PlayerOnlineIdentity restored =
        PlayerOnlineIdentity.fromJson(json);

    expect(restored.isLinked, isTrue);
    expect(restored.localPlayerId, 'player_001');
    expect(restored.onlinePlayerId, 'online_001');
    expect(json, isNot(contains('email')));
    expect(json, isNot(contains('password')));
    expect(json, isNot(contains('token')));
  });

  test('une identité distante incomplète redevient locale au chargement', () {
    final PlayerOnlineIdentity restored = PlayerOnlineIdentity.fromJson(
      <String, dynamic>{
        'schemaVersion': 1,
        'installationId': 'install_001',
        'localPlayerId': 'player_001',
        'status': 'online',
        'createdAtUtc': now.toIso8601String(),
        'updatedAtUtc': now.toIso8601String(),
      },
    );

    expect(restored.status, PlayerOnlineIdentityStatus.localOnly);
    expect(restored.isLinked, isFalse);
  });
}

import '../game/passport/player_passport.dart';
import '../server/geopoint_server_contract.dart';
import 'player_identity_storage.dart';
import 'player_online_identity.dart';
import 'player_profile.dart';

enum PlayerOnlineLinkStatus {
  online,
  migrationPending,
  rejected,
  serverUnavailable,
  storageFailure,
}

class PlayerOnlineLinkReport {
  const PlayerOnlineLinkReport({
    required this.status,
    required this.identity,
    this.migrationRequestId,
    this.failureReason,
  });

  final PlayerOnlineLinkStatus status;
  final PlayerOnlineIdentity identity;
  final String? migrationRequestId;
  final String? failureReason;
}

class PlayerOnlineLinkService {
  const PlayerOnlineLinkService._();

  static Future<PlayerOnlineLinkReport> link({
    required PlayerOnlineIdentity identity,
    required PlayerProfile playerProfile,
    required PlayerPassport passport,
    required GeoPointServerGateway gateway,
  }) async {
    PlayerOnlineIdentity currentIdentity = identity;
    try {
      final PlayerIdentityRegistrationResponse registration =
          await gateway.registerPlayerIdentity(
        PlayerIdentityRegistrationRequest.fromLocalProgress(
          identity: identity,
          playerProfile: playerProfile,
          passport: passport,
        ),
      );
      PlayerOnlineIdentity pending = identity.prepareOnlineMigration(
        providerId: registration.providerId,
        onlinePlayerId: registration.onlinePlayerId,
        requestedAtUtc: registration.serverNowUtc,
      );
      if (!await PlayerIdentityStorage.save(pending)) {
        return PlayerOnlineLinkReport(
          status: PlayerOnlineLinkStatus.storageFailure,
          identity: pending,
          failureReason: 'L’identité liée n’a pas pu être sauvegardée.',
        );
      }
      currentIdentity = pending;

      if (!registration.migrationRequired &&
          registration.migrationStatus.allowsOnlineIdentity) {
        pending = pending.confirmMigration(
          migratedAtUtc: registration.serverNowUtc,
        );
        return _saveFinalIdentity(pending);
      }
      if (registration.migrationStatus ==
          GeoPointProfileMigrationStatus.rejected) {
        return _reject(pending, 'La migration du profil a été refusée.');
      }

      final PlayerProfileMigrationResponse migration =
          await gateway.submitProfileMigration(
        PlayerProfileMigrationRequest.fromLocalProgress(
          identity: pending,
          playerProfile: playerProfile,
          passport: passport,
        ),
      );
      if (migration.status.allowsOnlineIdentity) {
        pending = pending.confirmMigration(
          migratedAtUtc: migration.serverNowUtc,
        );
        return _saveFinalIdentity(pending);
      }
      if (migration.status == GeoPointProfileMigrationStatus.rejected) {
        return _reject(pending, 'La migration du profil a été refusée.');
      }
      return PlayerOnlineLinkReport(
        status: PlayerOnlineLinkStatus.migrationPending,
        identity: pending,
        migrationRequestId: migration.requestId,
      );
    } catch (error) {
      return PlayerOnlineLinkReport(
        status: PlayerOnlineLinkStatus.serverUnavailable,
        identity: currentIdentity,
        failureReason: error.toString(),
      );
    }
  }

  static Future<PlayerOnlineLinkReport> refreshMigration({
    required PlayerOnlineIdentity identity,
    required GeoPointServerGateway gateway,
  }) async {
    if (!identity.isMigrationPending) {
      return PlayerOnlineLinkReport(
        status: identity.isLinked
            ? PlayerOnlineLinkStatus.online
            : PlayerOnlineLinkStatus.rejected,
        identity: identity,
      );
    }
    try {
      final PlayerProfileMigrationStatusResponse response =
          await gateway.getProfileMigrationStatus();
      if (response.status.allowsOnlineIdentity) {
        return _saveFinalIdentity(
          identity.confirmMigration(migratedAtUtc: response.serverNowUtc),
        );
      }
      if (response.status == GeoPointProfileMigrationStatus.rejected) {
        return _reject(identity, 'La migration du profil a été refusée.');
      }
      return PlayerOnlineLinkReport(
        status: PlayerOnlineLinkStatus.migrationPending,
        identity: identity,
        migrationRequestId: response.requestId,
      );
    } catch (error) {
      return PlayerOnlineLinkReport(
        status: PlayerOnlineLinkStatus.serverUnavailable,
        identity: identity,
        failureReason: error.toString(),
      );
    }
  }

  static Future<PlayerOnlineLinkReport> _saveFinalIdentity(
    PlayerOnlineIdentity identity,
  ) async {
    final bool saved = await PlayerIdentityStorage.save(identity);
    return PlayerOnlineLinkReport(
      status: saved
          ? PlayerOnlineLinkStatus.online
          : PlayerOnlineLinkStatus.storageFailure,
      identity: identity,
      failureReason: saved
          ? null
          : 'Le compte confirmé n’a pas pu être sauvegardé.',
    );
  }

  static Future<PlayerOnlineLinkReport> _reject(
    PlayerOnlineIdentity identity,
    String reason,
  ) async {
    final PlayerOnlineIdentity local = identity.unlink();
    final bool saved = await PlayerIdentityStorage.save(local);
    return PlayerOnlineLinkReport(
      status: saved
          ? PlayerOnlineLinkStatus.rejected
          : PlayerOnlineLinkStatus.storageFailure,
      identity: local,
      failureReason: reason,
    );
  }
}

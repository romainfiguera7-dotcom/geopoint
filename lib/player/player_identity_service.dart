import 'dart:math';

import '../game/passport/passport_storage.dart';
import '../game/passport/player_passport.dart';
import 'player_identity_storage.dart';
import 'player_online_identity.dart';
import 'player_profile.dart';
import 'player_storage.dart';

enum PlayerIdentityBootstrapStatus {
  created,
  restored,
  repairedLocalProfiles,
  storageFailure,
}

class PlayerIdentityBootstrapResult {
  const PlayerIdentityBootstrapResult({
    required this.identity,
    required this.playerProfile,
    required this.passport,
    required this.status,
  });

  final PlayerOnlineIdentity identity;
  final PlayerProfile playerProfile;
  final PlayerPassport passport;
  final PlayerIdentityBootstrapStatus status;

  bool get wasSaved => status != PlayerIdentityBootstrapStatus.storageFailure;
}

/// Crée une identité locale stable et rattache les anciens profils
/// `local_player` sans modifier leur progression.
class PlayerIdentityService {
  const PlayerIdentityService._();

  static Future<PlayerIdentityBootstrapResult> bootstrap({
    required PlayerProfile playerProfile,
    required PlayerPassport passport,
    DateTime? nowUtc,
    String Function()? installationIdFactory,
    String Function()? localPlayerIdFactory,
  }) async {
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    final PlayerOnlineIdentity? savedIdentity =
        await PlayerIdentityStorage.load();
    final bool identityWasCreated = savedIdentity == null;
    final PlayerOnlineIdentity identity = savedIdentity ??
        PlayerOnlineIdentity.local(
          installationId:
              installationIdFactory?.call() ?? _generateId('install'),
          localPlayerId: _resolveLocalPlayerId(
            playerProfile: playerProfile,
            passport: passport,
            generatedId: localPlayerIdFactory?.call() ?? _generateId('player'),
          ),
          createdAtUtc: now,
        );

    final bool profileNeedsRepair =
        playerProfile.playerId != identity.localPlayerId;
    final bool passportNeedsRepair = passport.playerId != identity.localPlayerId;
    final PlayerProfile migratedProfile = profileNeedsRepair
        ? playerProfile.copyWith(playerId: identity.localPlayerId)
        : playerProfile;
    final PlayerPassport migratedPassport = passportNeedsRepair
        ? passport.copyWith(playerId: identity.localPlayerId, updatedAt: now)
        : passport;

    final List<bool> saveResults = await Future.wait(<Future<bool>>[
      if (identityWasCreated) PlayerIdentityStorage.save(identity),
      if (profileNeedsRepair) PlayerStorage.save(migratedProfile),
      if (passportNeedsRepair) PassportStorage.save(migratedPassport),
    ]);
    if (saveResults.any((bool saved) => !saved)) {
      return PlayerIdentityBootstrapResult(
        identity: identity,
        playerProfile: migratedProfile,
        passport: migratedPassport,
        status: PlayerIdentityBootstrapStatus.storageFailure,
      );
    }

    final PlayerIdentityBootstrapStatus status;
    if (identityWasCreated) {
      status = PlayerIdentityBootstrapStatus.created;
    } else if (profileNeedsRepair || passportNeedsRepair) {
      status = PlayerIdentityBootstrapStatus.repairedLocalProfiles;
    } else {
      status = PlayerIdentityBootstrapStatus.restored;
    }
    return PlayerIdentityBootstrapResult(
      identity: identity,
      playerProfile: migratedProfile,
      passport: migratedPassport,
      status: status,
    );
  }

  static String _resolveLocalPlayerId({
    required PlayerProfile playerProfile,
    required PlayerPassport passport,
    required String generatedId,
  }) {
    if (!_isLegacyId(playerProfile.playerId)) {
      return playerProfile.playerId;
    }
    if (!_isLegacyId(passport.playerId)) {
      return passport.playerId;
    }
    return generatedId;
  }

  static bool _isLegacyId(String value) {
    final String normalized = value.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'local_player';
  }

  static String _generateId(String prefix) {
    final int micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    final int random = Random.secure().nextInt(1 << 32);
    return '${prefix}_${micros.toRadixString(36)}_${random.toRadixString(36)}';
  }
}

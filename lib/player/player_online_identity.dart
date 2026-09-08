enum PlayerOnlineIdentityStatus {
  localOnly,
  migrationPending,
  online,
}

extension PlayerOnlineIdentityStatusRules on PlayerOnlineIdentityStatus {
  String get id {
    switch (this) {
      case PlayerOnlineIdentityStatus.localOnly:
        return 'local_only';
      case PlayerOnlineIdentityStatus.migrationPending:
        return 'migration_pending';
      case PlayerOnlineIdentityStatus.online:
        return 'online';
    }
  }
}

/// Identité stable du joueur, indépendante du fournisseur distant retenu.
///
/// Aucun mot de passe, jeton d'authentification ou adresse e-mail n'est
/// enregistré ici. Le futur connecteur serveur conservera ces informations
/// dans le stockage sécurisé adapté.
class PlayerOnlineIdentity {
  const PlayerOnlineIdentity({
    required this.schemaVersion,
    required this.installationId,
    required this.localPlayerId,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.providerId,
    this.onlinePlayerId,
    this.migrationRequestedAtUtc,
    this.migratedAtUtc,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String installationId;
  final String localPlayerId;
  final PlayerOnlineIdentityStatus status;
  final String? providerId;
  final String? onlinePlayerId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? migrationRequestedAtUtc;
  final DateTime? migratedAtUtc;

  bool get isLinked {
    return status == PlayerOnlineIdentityStatus.online &&
        providerId != null &&
        onlinePlayerId != null;
  }

  bool get isMigrationPending {
    return status == PlayerOnlineIdentityStatus.migrationPending;
  }

  /// Identifiant public à joindre aux futures requêtes de classement.
  String? get rankingPlayerId => isLinked ? onlinePlayerId : null;

  factory PlayerOnlineIdentity.local({
    required String installationId,
    required String localPlayerId,
    DateTime? createdAtUtc,
  }) {
    final DateTime now = (createdAtUtc ?? DateTime.now()).toUtc();
    return PlayerOnlineIdentity(
      schemaVersion: currentSchemaVersion,
      installationId: _requireIdentifier(installationId, 'installationId'),
      localPlayerId: _requireIdentifier(localPlayerId, 'localPlayerId'),
      status: PlayerOnlineIdentityStatus.localOnly,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
  }

  PlayerOnlineIdentity prepareOnlineMigration({
    required String providerId,
    required String onlinePlayerId,
    DateTime? requestedAtUtc,
  }) {
    final DateTime now = (requestedAtUtc ?? DateTime.now()).toUtc();
    return PlayerOnlineIdentity(
      schemaVersion: currentSchemaVersion,
      installationId: installationId,
      localPlayerId: localPlayerId,
      status: PlayerOnlineIdentityStatus.migrationPending,
      providerId: _requireIdentifier(providerId, 'providerId').toLowerCase(),
      onlinePlayerId: _requireIdentifier(onlinePlayerId, 'onlinePlayerId'),
      createdAtUtc: createdAtUtc,
      updatedAtUtc: now,
      migrationRequestedAtUtc: now,
    );
  }

  PlayerOnlineIdentity confirmMigration({DateTime? migratedAtUtc}) {
    if (!isMigrationPending || providerId == null || onlinePlayerId == null) {
      throw StateError(
        'Aucune migration de profil en ligne ne peut être confirmée.',
      );
    }
    final DateTime now = (migratedAtUtc ?? DateTime.now()).toUtc();
    return PlayerOnlineIdentity(
      schemaVersion: currentSchemaVersion,
      installationId: installationId,
      localPlayerId: localPlayerId,
      status: PlayerOnlineIdentityStatus.online,
      providerId: providerId,
      onlinePlayerId: onlinePlayerId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: now,
      migrationRequestedAtUtc: migrationRequestedAtUtc,
      migratedAtUtc: now,
    );
  }

  PlayerOnlineIdentity unlink({DateTime? unlinkedAtUtc}) {
    final DateTime now = (unlinkedAtUtc ?? DateTime.now()).toUtc();
    return PlayerOnlineIdentity(
      schemaVersion: currentSchemaVersion,
      installationId: installationId,
      localPlayerId: localPlayerId,
      status: PlayerOnlineIdentityStatus.localOnly,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: now,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'installationId': installationId,
      'localPlayerId': localPlayerId,
      'status': status.id,
      if (providerId != null) 'providerId': providerId,
      if (onlinePlayerId != null) 'onlinePlayerId': onlinePlayerId,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
      if (migrationRequestedAtUtc != null)
        'migrationRequestedAtUtc':
            migrationRequestedAtUtc!.toUtc().toIso8601String(),
      if (migratedAtUtc != null)
        'migratedAtUtc': migratedAtUtc!.toUtc().toIso8601String(),
    };
  }

  factory PlayerOnlineIdentity.fromJson(Map<String, dynamic> json) {
    final DateTime now = DateTime.now().toUtc();
    final String installationId = _requireIdentifier(
      json['installationId']?.toString() ?? '',
      'installationId',
    );
    final String localPlayerId = _requireIdentifier(
      json['localPlayerId']?.toString() ?? '',
      'localPlayerId',
    );
    final String? providerId = _readOptionalIdentifier(json['providerId']);
    final String? onlinePlayerId =
        _readOptionalIdentifier(json['onlinePlayerId']);
    PlayerOnlineIdentityStatus status = _statusFromId(json['status']);
    if (status != PlayerOnlineIdentityStatus.localOnly &&
        (providerId == null || onlinePlayerId == null)) {
      status = PlayerOnlineIdentityStatus.localOnly;
    }
    return PlayerOnlineIdentity(
      schemaVersion: currentSchemaVersion,
      installationId: installationId,
      localPlayerId: localPlayerId,
      status: status,
      providerId:
          status == PlayerOnlineIdentityStatus.localOnly ? null : providerId,
      onlinePlayerId:
          status == PlayerOnlineIdentityStatus.localOnly ? null : onlinePlayerId,
      createdAtUtc: _readDate(json['createdAtUtc'], fallback: now),
      updatedAtUtc: _readDate(json['updatedAtUtc'], fallback: now),
      migrationRequestedAtUtc: _readOptionalDate(
        json['migrationRequestedAtUtc'],
      ),
      migratedAtUtc: status == PlayerOnlineIdentityStatus.online
          ? _readOptionalDate(json['migratedAtUtc'])
          : null,
    );
  }

  static PlayerOnlineIdentityStatus _statusFromId(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'migration_pending':
        return PlayerOnlineIdentityStatus.migrationPending;
      case 'online':
        return PlayerOnlineIdentityStatus.online;
      default:
        return PlayerOnlineIdentityStatus.localOnly;
    }
  }

  static String _requireIdentifier(String value, String fieldName) {
    final String normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > 128 ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(normalized)) {
      throw FormatException('Identifiant joueur invalide : $fieldName.');
    }
    return normalized;
  }

  static String? _readOptionalIdentifier(Object? value) {
    final String normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return _requireIdentifier(normalized, 'identifiant optionnel');
  }

  static DateTime _readDate(Object? value, {required DateTime fallback}) {
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ?? fallback;
  }

  static DateTime? _readOptionalDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  }
}

import '../game/passport/player_passport.dart';
import '../player/player_online_identity.dart';
import '../player/player_profile.dart';

enum GeoPointProfileMigrationStatus {
  notRequired,
  requiredMigration,
  pendingServerValidation,
  completed,
  rejected,
}

extension GeoPointProfileMigrationStatusRules
    on GeoPointProfileMigrationStatus {
  String get id {
    switch (this) {
      case GeoPointProfileMigrationStatus.notRequired:
        return 'not_required';
      case GeoPointProfileMigrationStatus.requiredMigration:
        return 'required';
      case GeoPointProfileMigrationStatus.pendingServerValidation:
        return 'pending_server_validation';
      case GeoPointProfileMigrationStatus.completed:
        return 'completed';
      case GeoPointProfileMigrationStatus.rejected:
        return 'rejected';
    }
  }

  bool get allowsOnlineIdentity {
    return this == GeoPointProfileMigrationStatus.notRequired ||
        this == GeoPointProfileMigrationStatus.completed;
  }
}

class GeoPointServerStatus {
  const GeoPointServerStatus({
    required this.apiVersion,
    required this.schemaVersion,
    required this.region,
    required this.serverNowUtc,
    required this.capabilities,
  });

  final int apiVersion;
  final int schemaVersion;
  final String region;
  final DateTime serverNowUtc;
  final Set<String> capabilities;

  factory GeoPointServerStatus.fromJson(Map<String, dynamic> json) {
    return GeoPointServerStatus(
      apiVersion: _requirePositiveInt(json['apiVersion'], 'apiVersion'),
      schemaVersion:
          _requirePositiveInt(json['schemaVersion'], 'schemaVersion'),
      region: _requireText(json['region'], 'region'),
      serverNowUtc: _requireDate(json['serverNowUtc'], 'serverNowUtc'),
      capabilities: Set<String>.unmodifiable(
        _readStringList(json['capabilities']).map((String item) => item.trim()),
      ),
    );
  }
}

class PlayerIdentityRegistrationRequest {
  const PlayerIdentityRegistrationRequest({
    required this.localPlayerId,
    required this.displayName,
    required this.avatarId,
    required this.profileSchemaVersion,
    required this.hasLocalProgress,
    required this.profileType,
    this.childAgeGroup,
  });

  static const int apiVersion = 1;

  final String localPlayerId;
  final String displayName;
  final String avatarId;
  final int profileSchemaVersion;
  final bool hasLocalProgress;
  final PlayerProfileType profileType;
  final PlayerChildAgeGroup? childAgeGroup;

  factory PlayerIdentityRegistrationRequest.fromLocalProgress({
    required PlayerOnlineIdentity identity,
    required PlayerProfile playerProfile,
    required PlayerPassport passport,
  }) {
    return PlayerIdentityRegistrationRequest(
      localPlayerId: identity.localPlayerId,
      displayName: playerProfile.displayName,
      avatarId: playerProfile.avatarId,
      profileSchemaVersion: playerProfile.schemaVersion,
      profileType: playerProfile.profileType,
      childAgeGroup: playerProfile.childAgeGroup,
      hasLocalProgress: playerProfile.totalXp > 0 ||
          playerProfile.gamesPlayed > 0 ||
          playerProfile.totalAnswers > 0 ||
          passport.hasStarted,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'apiVersion': apiVersion,
      'localPlayerId': localPlayerId,
      'displayName': displayName,
      'avatarId': avatarId,
      'profileSchemaVersion': profileSchemaVersion,
      'hasLocalProgress': hasLocalProgress,
      'profileType': profileType.id,
      if (childAgeGroup != null) 'childAgeGroup': childAgeGroup!.id,
    };
  }
}

class PlayerIdentityRegistrationResponse {
  const PlayerIdentityRegistrationResponse({
    required this.onlinePlayerId,
    required this.providerId,
    required this.migrationRequired,
    required this.migrationStatus,
    required this.serverNowUtc,
    this.profileType = PlayerProfileType.adult,
    this.childAgeGroup,
  });

  final String onlinePlayerId;
  final String providerId;
  final bool migrationRequired;
  final GeoPointProfileMigrationStatus migrationStatus;
  final DateTime serverNowUtc;
  final PlayerProfileType profileType;
  final PlayerChildAgeGroup? childAgeGroup;

  bool get isChildProfile => profileType == PlayerProfileType.child;

  factory PlayerIdentityRegistrationResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    _requireSupportedApiVersion(json);
    final bool migrationRequired = json['migrationRequired'] == true;
    final GeoPointProfileMigrationStatus migrationStatus =
        _migrationStatus(json['migrationStatus']);
    final bool statusRequiresMigration = migrationStatus ==
            GeoPointProfileMigrationStatus.requiredMigration ||
        migrationStatus ==
            GeoPointProfileMigrationStatus.pendingServerValidation;
    if (migrationRequired != statusRequiresMigration) {
      throw const FormatException(
        'Réponse serveur incohérente pour la migration du profil.',
      );
    }
    return PlayerIdentityRegistrationResponse(
      onlinePlayerId:
          _requireIdentifier(json['onlinePlayerId'], 'onlinePlayerId'),
      providerId: _requireIdentifier(json['providerId'], 'providerId'),
      migrationRequired: migrationRequired,
      migrationStatus: migrationStatus,
      serverNowUtc: _requireDate(json['serverNowUtc'], 'serverNowUtc'),
      profileType: PlayerProfileTypeRules.fromId(json['profileType']),
      childAgeGroup: PlayerChildAgeGroupRules.fromId(json['childAgeGroup']),
    );
  }
}

class PlayerProfileMigrationRequest {
  const PlayerProfileMigrationRequest({
    required this.localPlayerId,
    required this.profile,
    required this.passport,
  });

  static const int apiVersion = 1;

  final String localPlayerId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> passport;

  factory PlayerProfileMigrationRequest.fromLocalProgress({
    required PlayerOnlineIdentity identity,
    required PlayerProfile playerProfile,
    required PlayerPassport passport,
  }) {
    return PlayerProfileMigrationRequest(
      localPlayerId: identity.localPlayerId,
      profile: <String, dynamic>{
        'schemaVersion': playerProfile.schemaVersion,
        'totalXp': playerProfile.totalXp,
        'gamesPlayed': playerProfile.gamesPlayed,
        'correctAnswers': playerProfile.correctAnswers,
        'totalAnswers': playerProfile.totalAnswers,
        'totalScore': playerProfile.totalScore,
        'totalDistanceInKilometers':
            playerProfile.totalDistanceInKilometers,
        'totalElapsedSeconds': playerProfile.totalElapsedSeconds,
        'createdAt': playerProfile.createdAt.toUtc().toIso8601String(),
        'lastPlayedAt': playerProfile.lastPlayedAt?.toUtc().toIso8601String(),
      },
      passport: <String, dynamic>{
        'schemaVersion': passport.schemaVersion,
        'currentLicenseId': passport.currentLicenseId,
        'totalAttempts': passport.totalAttempts,
        'validatedStampCount': passport.validatedStampCount,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'apiVersion': apiVersion,
      'localPlayerId': localPlayerId,
      'profile': profile,
      'passport': passport,
    };
  }
}

class PlayerProfileMigrationResponse {
  const PlayerProfileMigrationResponse({
    required this.requestId,
    required this.status,
    required this.serverNowUtc,
  });

  final String requestId;
  final GeoPointProfileMigrationStatus status;
  final DateTime serverNowUtc;

  factory PlayerProfileMigrationResponse.fromJson(Map<String, dynamic> json) {
    _requireSupportedApiVersion(json);
    return PlayerProfileMigrationResponse(
      requestId: _requireIdentifier(json['requestId'], 'requestId'),
      status: _migrationStatus(json['status']),
      serverNowUtc: _requireDate(json['serverNowUtc'], 'serverNowUtc'),
    );
  }
}

class PlayerProfileMigrationStatusResponse {
  const PlayerProfileMigrationStatusResponse({
    required this.status,
    required this.serverNowUtc,
    this.requestId,
  });

  final GeoPointProfileMigrationStatus status;
  final String? requestId;
  final DateTime serverNowUtc;

  factory PlayerProfileMigrationStatusResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    _requireSupportedApiVersion(json);
    final String requestId = json['requestId']?.toString().trim() ?? '';
    return PlayerProfileMigrationStatusResponse(
      status: _migrationStatus(json['status']),
      requestId: requestId.isEmpty ? null : _requireIdentifier(
        requestId,
        'requestId',
      ),
      serverNowUtc: _requireDate(json['serverNowUtc'], 'serverNowUtc'),
    );
  }
}

abstract interface class GeoPointServerGateway {
  Future<GeoPointServerStatus> getStatus();

  Future<PlayerIdentityRegistrationResponse> registerPlayerIdentity(
    PlayerIdentityRegistrationRequest request,
  );

  Future<PlayerProfileMigrationResponse> submitProfileMigration(
    PlayerProfileMigrationRequest request,
  );

  Future<PlayerProfileMigrationStatusResponse> getProfileMigrationStatus();
}

void _requireSupportedApiVersion(Map<String, dynamic> json) {
  final int version = _requirePositiveInt(json['apiVersion'], 'apiVersion');
  if (version != 1) {
    throw FormatException('Version serveur GeoPoint incompatible : $version.');
  }
}

GeoPointProfileMigrationStatus _migrationStatus(Object? value) {
  switch (value?.toString().trim().toLowerCase()) {
    case 'not_required':
      return GeoPointProfileMigrationStatus.notRequired;
    case 'required':
      return GeoPointProfileMigrationStatus.requiredMigration;
    case 'pending_server_validation':
      return GeoPointProfileMigrationStatus.pendingServerValidation;
    case 'completed':
      return GeoPointProfileMigrationStatus.completed;
    case 'rejected':
      return GeoPointProfileMigrationStatus.rejected;
    default:
      throw const FormatException('État de migration serveur inconnu.');
  }
}

String _requireIdentifier(Object? value, String fieldName) {
  final String text = _requireText(value, fieldName);
  if (text.length > 128 || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(text)) {
    throw FormatException('Identifiant serveur invalide : $fieldName.');
  }
  return text;
}

String _requireText(Object? value, String fieldName) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    throw FormatException('Champ serveur manquant : $fieldName.');
  }
  return text;
}

int _requirePositiveInt(Object? value, String fieldName) {
  final int? number = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (number == null || number <= 0) {
    throw FormatException('Nombre serveur invalide : $fieldName.');
  }
  return number;
}

DateTime _requireDate(Object? value, String fieldName) {
  final DateTime? date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) {
    throw FormatException('Date serveur invalide : $fieldName.');
  }
  return date.toUtc();
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    throw const FormatException('Liste de capacités serveur invalide.');
  }
  return value
      .map((dynamic item) => item.toString().trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

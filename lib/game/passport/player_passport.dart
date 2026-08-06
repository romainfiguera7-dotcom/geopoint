import 'player_stamp_progress.dart';

class PlayerPassport {
  const PlayerPassport({
    required this.schemaVersion,
    required this.playerId,
    required this.displayName,
    required this.currentLicenseId,
    required this.stampProgress,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Version du format de sauvegarde.
  ///
  /// Elle permettra plus tard de convertir les anciennes
  /// sauvegardes lorsque le Passeport évoluera.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;

  /// Identifiant local du joueur.
  ///
  /// Pour la première version, un identifiant local suffit.
  /// Il pourra ensuite être remplacé ou associé à un compte.
  final String playerId;

  /// Nom affiché dans le Passeport.
  final String displayName;

  /// Dernière licence obtenue.
  ///
  /// Exemple :
  /// 1 = Débutant
  /// 2 = Voyageur
  /// 3 = Explorateur
  final int currentLicenseId;

  /// Progression du joueur pour chaque tampon.
  ///
  /// La clé correspond à l'identifiant du tampon :
  /// countries, capitals, flags, mixed, etc.
  final Map<String, PlayerStampProgress>
      stampProgress;

  /// Date de création du Passeport.
  final DateTime createdAt;

  /// Date de la dernière modification.
  final DateTime updatedAt;

  factory PlayerPassport.initial({
    String playerId = 'local_player',
    String displayName = 'Voyageur',
    DateTime? createdAt,
  }) {
    final DateTime now =
        createdAt ?? DateTime.now();

    return PlayerPassport(
      schemaVersion: currentSchemaVersion,
      playerId: playerId.trim().isEmpty
          ? 'local_player'
          : playerId.trim(),
      displayName: displayName.trim().isEmpty
          ? 'Voyageur'
          : displayName.trim(),
      currentLicenseId: 1,
      stampProgress:
          const <String, PlayerStampProgress>{},
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get hasStarted {
    return stampProgress.values.any(
      (PlayerStampProgress progress) =>
          progress.hasPlayed,
    );
  }

  int get totalAttempts {
    int total = 0;

    for (final PlayerStampProgress progress
        in stampProgress.values) {
      total += progress.attempts;
    }

    return total;
  }

  int get validatedStampCount {
    int total = 0;

    for (final PlayerStampProgress progress
        in stampProgress.values) {
      if (progress.isValidated) {
        total++;
      }
    }

    return total;
  }

  PlayerStampProgress progressFor(
    String stampId,
  ) {
    final String normalizedStampId =
        stampId.trim().toLowerCase();

    return stampProgress[normalizedStampId] ??
        PlayerStampProgress.empty(
          normalizedStampId,
        );
  }

  bool hasProgressFor(
    String stampId,
  ) {
    final String normalizedStampId =
        stampId.trim().toLowerCase();

    return stampProgress.containsKey(
      normalizedStampId,
    );
  }

  PlayerPassport updateStampProgress(
    PlayerStampProgress progress, {
    DateTime? updatedAt,
  }) {
    final String normalizedStampId =
        progress.stampId
            .trim()
            .toLowerCase();

    final Map<String, PlayerStampProgress>
        updatedProgress =
        Map<String, PlayerStampProgress>.from(
      stampProgress,
    );

    updatedProgress[normalizedStampId] =
        progress;

    return copyWith(
      stampProgress:
          Map<String, PlayerStampProgress>
              .unmodifiable(
        updatedProgress,
      ),
      updatedAt:
          updatedAt ?? DateTime.now(),
    );
  }

  PlayerPassport unlockLicense(
    int licenseId, {
    DateTime? updatedAt,
  }) {
    if (licenseId <= currentLicenseId) {
      return this;
    }

    return copyWith(
      currentLicenseId: licenseId,
      updatedAt:
          updatedAt ?? DateTime.now(),
    );
  }

  PlayerPassport rename(
    String newDisplayName, {
    DateTime? updatedAt,
  }) {
    final String normalizedName =
        newDisplayName.trim();

    if (normalizedName.isEmpty ||
        normalizedName == displayName) {
      return this;
    }

    return copyWith(
      displayName: normalizedName,
      updatedAt:
          updatedAt ?? DateTime.now(),
    );
  }

  PlayerPassport copyWith({
    int? schemaVersion,
    String? playerId,
    String? displayName,
    int? currentLicenseId,
    Map<String, PlayerStampProgress>?
        stampProgress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlayerPassport(
      schemaVersion:
          schemaVersion ?? this.schemaVersion,
      playerId:
          playerId ?? this.playerId,
      displayName:
          displayName ?? this.displayName,
      currentLicenseId:
          currentLicenseId ??
              this.currentLicenseId,
      stampProgress:
          stampProgress ??
              this.stampProgress,
      createdAt:
          createdAt ?? this.createdAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic>
        serializedProgress =
        <String, dynamic>{};

    for (final MapEntry<
            String,
            PlayerStampProgress> entry
        in stampProgress.entries) {
      serializedProgress[entry.key] =
          entry.value.toJson();
    }

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'playerId': playerId,
      'displayName': displayName,
      'currentLicenseId':
          currentLicenseId,
      'stampProgress':
          serializedProgress,
      'createdAt':
          createdAt.toIso8601String(),
      'updatedAt':
          updatedAt.toIso8601String(),
    };
  }

  factory PlayerPassport.fromJson(
    Map<String, dynamic> json,
  ) {
    final int schemaVersion =
        _readInt(
      json['schemaVersion'],
      fallback: currentSchemaVersion,
    );

    final DateTime now =
        DateTime.now();

    return PlayerPassport(
      schemaVersion: schemaVersion,
      playerId: _readString(
        json['playerId'],
        fallback: 'local_player',
      ),
      displayName: _readString(
        json['displayName'],
        fallback: 'Voyageur',
      ),
      currentLicenseId: _readInt(
        json['currentLicenseId'],
        fallback: 1,
      ),
      stampProgress:
          Map<String, PlayerStampProgress>
              .unmodifiable(
        _readStampProgress(
          json['stampProgress'],
        ),
      ),
      createdAt:
          _readDateTime(
        json['createdAt'],
        fallback: now,
      ),
      updatedAt:
          _readDateTime(
        json['updatedAt'],
        fallback: now,
      ),
    );
  }

  static Map<String, PlayerStampProgress>
      _readStampProgress(
    Object? value,
  ) {
    if (value is! Map) {
      return <String, PlayerStampProgress>{};
    }

    final Map<String, PlayerStampProgress>
        result =
        <String, PlayerStampProgress>{};

    for (final MapEntry<dynamic, dynamic> entry
        in value.entries) {
      if (entry.value is! Map) {
        continue;
      }

      final Map<String, dynamic>
          progressJson =
          (entry.value as Map)
              .map<String, dynamic>(
        (
          dynamic key,
          dynamic item,
        ) {
          return MapEntry<String, dynamic>(
            key.toString(),
            item,
          );
        },
      );

      final PlayerStampProgress progress =
          PlayerStampProgress.fromJson(
        progressJson,
      );

      result[progress.stampId] =
          progress;
    }

    return result;
  }

  static String _readString(
    Object? value, {
    required String fallback,
  }) {
    final String text =
        value?.toString().trim() ?? '';

    return text.isEmpty
        ? fallback
        : text;
  }

  static int _readInt(
    Object? value, {
    required int fallback,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  static DateTime _readDateTime(
    Object? value, {
    required DateTime fallback,
  }) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return fallback;
    }

    return DateTime.tryParse(text) ??
        fallback;
  }

  @override
  String toString() {
    return 'PlayerPassport('
        'playerId: $playerId, '
        'displayName: $displayName, '
        'currentLicenseId: $currentLicenseId, '
        'stamps: ${stampProgress.length}, '
        'totalAttempts: $totalAttempts'
        ')';
  }
}
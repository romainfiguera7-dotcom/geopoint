import '../../geo_engine/geo_entity_id.dart';
import '../../game/passport/player_passport.dart';
import '../../player/player_profile.dart';
import 'passport_entity_progress.dart';
import 'passport_progress_rules.dart';

class PassportProgressV2 {
  const PassportProgressV2({
    required this.schemaVersion,
    required this.licenseProgress,
    required this.playerProfile,
    required this.entities,
    required this.migratedFromSchemaVersions,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final PlayerPassport licenseProgress;
  final PlayerProfile playerProfile;
  final Map<String, PassportEntityProgress> entities;
  final Map<String, int> migratedFromSchemaVersions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PassportProgressV2.initial({
    DateTime? createdAt,
  }) {
    final DateTime now = createdAt ?? DateTime.now();

    return PassportProgressV2(
      schemaVersion: currentSchemaVersion,
      licenseProgress: PlayerPassport.initial(createdAt: now),
      playerProfile: PlayerProfile.initial(createdAt: now),
      entities: const <String, PassportEntityProgress>{},
      migratedFromSchemaVersions: const <String, int>{},
      createdAt: now,
      updatedAt: now,
    );
  }

  int get discoveredEntityCount {
    return entities.values
        .where(
          (PassportEntityProgress progress) => progress.hasBeenDiscovered,
        )
        .length;
  }

  int get learningEntityCount {
    return entities.values
        .where(
          (PassportEntityProgress progress) =>
              progress.learningState == PassportLearningState.learning,
        )
        .length;
  }

  int get masteredEntityCount {
    return entities.values
        .where(
          (PassportEntityProgress progress) => progress.isMastered,
        )
        .length;
  }

  int get unlockedCountryStampCount {
    return entities.values
        .where(
          (PassportEntityProgress progress) =>
              progress.stampUnlockedAt != null,
        )
        .length;
  }

  int get visitedEntityCount {
    return entities.values
        .where(
          (PassportEntityProgress progress) => progress.isVisited,
        )
        .length;
  }

  int get wishlistedEntityCount {
    return entities.values
        .where(
          (PassportEntityProgress progress) => progress.isWishlisted,
        )
        .length;
  }

  int get favoriteEntityCount {
    return entities.values
        .where(
          (PassportEntityProgress progress) => progress.isFavorite,
        )
        .length;
  }

  PassportEntityProgress progressFor(
    String entityId,
  ) {
    final String normalizedId = GeoEntityId.require(entityId);

    return entities[normalizedId] ??
        PassportEntityProgress.initial(normalizedId);
  }

  PassportProgressV2 replaceEntity(
    PassportEntityProgress progress, {
    DateTime? updatedAt,
  }) {
    final Map<String, PassportEntityProgress> updatedEntities =
        Map<String, PassportEntityProgress>.from(entities);

    updatedEntities[progress.entityId] = progress;

    return PassportProgressV2(
      schemaVersion: currentSchemaVersion,
      licenseProgress: licenseProgress,
      playerProfile: playerProfile,
      entities: Map<String, PassportEntityProgress>.unmodifiable(
        updatedEntities,
      ),
      migratedFromSchemaVersions: migratedFromSchemaVersions,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'licenseProgress': licenseProgress.toJson(),
      'playerProfile': playerProfile.toJson(),
      'entities': <String, dynamic>{
        for (final MapEntry<String, PassportEntityProgress> entry
            in entities.entries)
          entry.key: entry.value.toJson(),
      },
      'migratedFromSchemaVersions': migratedFromSchemaVersions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PassportProgressV2.fromJson(
    Map<String, dynamic> json,
  ) {
    final DateTime now = DateTime.now();
    final Object? rawLicenseProgress = json['licenseProgress'];
    final Object? rawPlayerProfile = json['playerProfile'];
    final Map<String, PassportEntityProgress> entities =
        <String, PassportEntityProgress>{};
    final Object? rawEntities = json['entities'];

    if (rawEntities is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawEntities.entries) {
        if (entry.value is! Map) {
          continue;
        }

        try {
          final PassportEntityProgress progress =
              PassportEntityProgress.fromJson(
            _asStringMap(entry.value as Map),
          );

          entities[progress.entityId] = progress;
        } on ArgumentError {
          continue;
        }
      }
    }

    return PassportProgressV2(
      schemaVersion: currentSchemaVersion,
      licenseProgress: rawLicenseProgress is Map
          ? PlayerPassport.fromJson(_asStringMap(rawLicenseProgress))
          : PlayerPassport.initial(createdAt: now),
      playerProfile: rawPlayerProfile is Map
          ? PlayerProfile.fromJson(_asStringMap(rawPlayerProfile))
          : PlayerProfile.initial(createdAt: now),
      entities: Map<String, PassportEntityProgress>.unmodifiable(entities),
      migratedFromSchemaVersions: Map<String, int>.unmodifiable(
        _readSchemaVersions(json['migratedFromSchemaVersions']),
      ),
      createdAt: _readDateTime(json['createdAt'], fallback: now),
      updatedAt: _readDateTime(json['updatedAt'], fallback: now),
    );
  }
}

Map<String, int> _readSchemaVersions(Object? value) {
  if (value is! Map) {
    return <String, int>{};
  }

  final Map<String, int> result = <String, int>{};

  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    final int? version = entry.value is num
        ? (entry.value as num).toInt()
        : int.tryParse(entry.value?.toString() ?? '');

    if (version == null || version < 0) {
      continue;
    }

    result[entry.key.toString()] = version;
  }

  return result;
}

DateTime _readDateTime(
  Object? value, {
  required DateTime fallback,
}) {
  final String text = value?.toString().trim() ?? '';

  if (text.isEmpty) {
    return fallback;
  }

  return DateTime.tryParse(text) ?? fallback;
}

Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> source) {
  return source.map<String, dynamic>(
    (dynamic key, dynamic value) {
      return MapEntry<String, dynamic>(key.toString(), value);
    },
  );
}

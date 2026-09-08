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
    this.unlockedCollectionItemIds = const <String>{},
    this.completedAchievementTierDates = const <String, DateTime>{},
    required this.migratedFromSchemaVersions,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int currentSchemaVersion = 4;

  final int schemaVersion;
  final PlayerPassport licenseProgress;
  final PlayerProfile playerProfile;
  final Map<String, PassportEntityProgress> entities;
  final Set<String> unlockedCollectionItemIds;
  final Map<String, DateTime> completedAchievementTierDates;
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
      unlockedCollectionItemIds: const <String>{},
      completedAchievementTierDates: const <String, DateTime>{},
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
      unlockedCollectionItemIds: unlockedCollectionItemIds,
      completedAchievementTierDates: completedAchievementTierDates,
      migratedFromSchemaVersions: migratedFromSchemaVersions,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  PassportProgressV2 registerAnswer({
    required String entityId,
    required PassportKnowledgeTheme theme,
    required bool isCorrect,
    required PassportDiscoverySource source,
    DateTime? answeredAt,
  }) {
    final DateTime answerDate = answeredAt ?? DateTime.now();
    final PassportEntityProgress updatedEntity = progressFor(entityId)
        .registerAnswer(
      theme: theme,
      isCorrect: isCorrect,
      source: source,
      answeredAt: answerDate,
    );

    return replaceEntity(updatedEntity, updatedAt: answerDate);
  }

  PassportProgressV2 markDiscovered({
    required String entityId,
    required PassportDiscoverySource source,
    DateTime? discoveredAt,
  }) {
    final DateTime discoveryDate = discoveredAt ?? DateTime.now();
    final PassportEntityProgress updatedEntity = progressFor(entityId)
        .markDiscovered(
      source: source,
      discoveredAt: discoveryDate,
    );

    return replaceEntity(updatedEntity, updatedAt: discoveryDate);
  }

  PassportProgressV2 unlockCollectionItem(
    String itemId, {
    DateTime? unlockedAt,
  }) {
    final String normalizedId = itemId.trim().toLowerCase();
    if (normalizedId.isEmpty || unlockedCollectionItemIds.contains(normalizedId)) {
      return this;
    }

    return PassportProgressV2(
      schemaVersion: currentSchemaVersion,
      licenseProgress: licenseProgress,
      playerProfile: playerProfile,
      entities: entities,
      unlockedCollectionItemIds: Set<String>.unmodifiable(
        <String>{...unlockedCollectionItemIds, normalizedId},
      ),
      completedAchievementTierDates: completedAchievementTierDates,
      migratedFromSchemaVersions: migratedFromSchemaVersions,
      createdAt: createdAt,
      updatedAt: unlockedAt ?? DateTime.now(),
    );
  }

  PassportProgressV2 recordAchievementTiers(
    Map<String, DateTime> completedDates, {
    DateTime? recordedAt,
  }) {
    final Map<String, DateTime> merged =
        Map<String, DateTime>.from(completedAchievementTierDates);
    bool changed = false;

    for (final MapEntry<String, DateTime> entry in completedDates.entries) {
      final String tierId = entry.key.trim().toLowerCase();
      if (tierId.isEmpty || merged.containsKey(tierId)) {
        continue;
      }
      merged[tierId] = entry.value;
      changed = true;
    }
    if (!changed) {
      return this;
    }

    return PassportProgressV2(
      schemaVersion: currentSchemaVersion,
      licenseProgress: licenseProgress,
      playerProfile: playerProfile,
      entities: entities,
      unlockedCollectionItemIds: unlockedCollectionItemIds,
      completedAchievementTierDates:
          Map<String, DateTime>.unmodifiable(merged),
      migratedFromSchemaVersions: migratedFromSchemaVersions,
      createdAt: createdAt,
      updatedAt: recordedAt ?? DateTime.now(),
    );
  }

  PassportProgressV2 recordMigrationVersions(
    Map<String, int> versions, {
    DateTime? recordedAt,
  }) {
    final Map<String, int> merged =
        Map<String, int>.from(migratedFromSchemaVersions);
    bool changed = false;
    for (final MapEntry<String, int> entry in versions.entries) {
      if (entry.key.trim().isEmpty || entry.value < 0) {
        continue;
      }
      if (merged[entry.key] != entry.value) {
        merged[entry.key] = entry.value;
        changed = true;
      }
    }
    if (!changed) {
      return this;
    }
    return PassportProgressV2(
      schemaVersion: currentSchemaVersion,
      licenseProgress: licenseProgress,
      playerProfile: playerProfile,
      entities: entities,
      unlockedCollectionItemIds: unlockedCollectionItemIds,
      completedAchievementTierDates: completedAchievementTierDates,
      migratedFromSchemaVersions: Map<String, int>.unmodifiable(merged),
      createdAt: createdAt,
      updatedAt: recordedAt ?? DateTime.now(),
    );
  }

  PassportProgressV2 replaceCoreProgress({
    required PlayerPassport licenseProgress,
    required PlayerProfile playerProfile,
    DateTime? replacedAt,
  }) {
    return PassportProgressV2(
      schemaVersion: currentSchemaVersion,
      licenseProgress: licenseProgress,
      playerProfile: playerProfile,
      entities: entities,
      unlockedCollectionItemIds: unlockedCollectionItemIds,
      completedAchievementTierDates: completedAchievementTierDates,
      migratedFromSchemaVersions: migratedFromSchemaVersions,
      createdAt: createdAt,
      updatedAt: replacedAt ?? DateTime.now(),
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
      'unlockedCollectionItemIds': unlockedCollectionItemIds.toList(),
      'completedAchievementTierDates': <String, dynamic>{
        for (final MapEntry<String, DateTime> entry
            in completedAchievementTierDates.entries)
          entry.key: entry.value.toIso8601String(),
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
      unlockedCollectionItemIds: Set<String>.unmodifiable(
        _readStringSet(json['unlockedCollectionItemIds']),
      ),
      completedAchievementTierDates: Map<String, DateTime>.unmodifiable(
        _readDateMap(json['completedAchievementTierDates']),
      ),
      migratedFromSchemaVersions: Map<String, int>.unmodifiable(
        _readSchemaVersions(json['migratedFromSchemaVersions']),
      ),
      createdAt: _readDateTime(json['createdAt'], fallback: now),
      updatedAt: _readDateTime(json['updatedAt'], fallback: now),
    );
  }
}

Map<String, DateTime> _readDateMap(Object? value) {
  if (value is! Map) {
    return <String, DateTime>{};
  }
  final Map<String, DateTime> result = <String, DateTime>{};
  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    final String key = entry.key.toString().trim().toLowerCase();
    final DateTime? date = DateTime.tryParse(entry.value?.toString() ?? '');
    if (key.isNotEmpty && date != null) {
      result[key] = date;
    }
  }
  return result;
}

Set<String> _readStringSet(Object? value) {
  if (value is! List) {
    return <String>{};
  }

  return value
      .map((dynamic item) => item.toString().trim().toLowerCase())
      .where((String item) => item.isNotEmpty)
      .toSet();
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

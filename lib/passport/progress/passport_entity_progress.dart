import '../../geo_engine/geo_entity_id.dart';
import 'passport_progress_rules.dart';

class PassportThemeProgress {
  const PassportThemeProgress({
    required this.masteryLevel,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.totalAttempts,
    required this.firstSeenAt,
    required this.lastAnsweredAt,
  });

  final int masteryLevel;
  final int correctAnswers;
  final int wrongAnswers;
  final int totalAttempts;
  final DateTime? firstSeenAt;
  final DateTime? lastAnsweredAt;

  factory PassportThemeProgress.initial() {
    return const PassportThemeProgress(
      masteryLevel: PassportProgressRules.minimumMasteryLevel,
      correctAnswers: 0,
      wrongAnswers: 0,
      totalAttempts: 0,
      firstSeenAt: null,
      lastAnsweredAt: null,
    );
  }

  bool get hasBeenSeen => totalAttempts > 0;

  bool get isMastered {
    return masteryLevel >= PassportProgressRules.masteredMasteryLevel;
  }

  double get accuracy {
    if (totalAttempts <= 0) {
      return 0;
    }

    return correctAnswers / totalAttempts;
  }

  PassportLearningState learningState({
    required bool entityHasBeenDiscovered,
  }) {
    return PassportProgressRules.learningState(
      hasBeenDiscovered: entityHasBeenDiscovered,
      totalAttempts: totalAttempts,
      masteryLevel: masteryLevel,
    );
  }

  PassportThemeProgress registerAnswer({
    required bool isCorrect,
    required int masteryLevelAfterAnswer,
    required DateTime answeredAt,
  }) {
    return PassportThemeProgress(
      masteryLevel: PassportProgressRules.normalizeMasteryLevel(
        masteryLevelAfterAnswer,
      ),
      correctAnswers: correctAnswers + (isCorrect ? 1 : 0),
      wrongAnswers: wrongAnswers + (isCorrect ? 0 : 1),
      totalAttempts: totalAttempts + 1,
      firstSeenAt: firstSeenAt ?? answeredAt,
      lastAnsweredAt: answeredAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'masteryLevel': masteryLevel,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'totalAttempts': totalAttempts,
      'firstSeenAt': firstSeenAt?.toIso8601String(),
      'lastAnsweredAt': lastAnsweredAt?.toIso8601String(),
    };
  }

  factory PassportThemeProgress.fromJson(
    Map<String, dynamic> json,
  ) {
    final int attempts = _readNonNegativeInt(
      json['totalAttempts'],
    );
    final int correct = _readNonNegativeInt(
      json['correctAnswers'],
    ).clamp(0, attempts);
    final int wrong = _readNonNegativeInt(
      json['wrongAnswers'],
    ).clamp(0, attempts - correct);

    return PassportThemeProgress(
      masteryLevel: PassportProgressRules.normalizeMasteryLevel(
        _readNonNegativeInt(json['masteryLevel']),
      ),
      correctAnswers: correct,
      wrongAnswers: wrong,
      totalAttempts: attempts,
      firstSeenAt: _readOptionalDateTime(json['firstSeenAt']),
      lastAnsweredAt: _readOptionalDateTime(json['lastAnsweredAt']),
    );
  }
}

class PassportEntityProgress {
  const PassportEntityProgress._({
    required this.entityId,
    required this.discoveredAt,
    required this.discoverySource,
    required this.themes,
    required this.isVisited,
    required this.isWishlisted,
    required this.isFavorite,
    required this.stampUnlockedAt,
    required this.stampUnlockSource,
  });

  final String entityId;
  final DateTime? discoveredAt;
  final PassportDiscoverySource? discoverySource;
  final Map<PassportKnowledgeTheme, PassportThemeProgress> themes;
  final bool isVisited;
  final bool isWishlisted;
  final bool isFavorite;
  final DateTime? stampUnlockedAt;
  final PassportDiscoverySource? stampUnlockSource;

  factory PassportEntityProgress.initial(
    String entityId,
  ) {
    return PassportEntityProgress._(
      entityId: GeoEntityId.require(entityId),
      discoveredAt: null,
      discoverySource: null,
      themes: const <PassportKnowledgeTheme, PassportThemeProgress>{},
      isVisited: false,
      isWishlisted: false,
      isFavorite: false,
      stampUnlockedAt: null,
      stampUnlockSource: null,
    );
  }

  factory PassportEntityProgress.migrated({
    required String entityId,
    required DateTime? discoveredAt,
    required Map<PassportKnowledgeTheme, PassportThemeProgress> themes,
    required bool isVisited,
    required bool isWishlisted,
    required bool isFavorite,
    required DateTime? stampUnlockedAt,
  }) {
    return PassportEntityProgress._(
      entityId: GeoEntityId.require(entityId),
      discoveredAt: discoveredAt,
      discoverySource: discoveredAt == null
          ? null
          : PassportDiscoverySource.migration,
      themes:
          Map<PassportKnowledgeTheme, PassportThemeProgress>.unmodifiable(
        themes,
      ),
      isVisited: isVisited,
      isWishlisted: !isVisited && isWishlisted,
      isFavorite: isFavorite,
      stampUnlockedAt: stampUnlockedAt,
      stampUnlockSource: stampUnlockedAt == null
          ? null
          : PassportDiscoverySource.migration,
    );
  }

  bool get hasBeenDiscovered => discoveredAt != null;

  PassportThemeProgress progressFor(
    PassportKnowledgeTheme theme,
  ) {
    return themes[theme] ?? PassportThemeProgress.initial();
  }

  PassportThemeProgress get locationProgress {
    return progressFor(PassportKnowledgeTheme.location);
  }

  PassportLearningState get learningState {
    return locationProgress.learningState(
      entityHasBeenDiscovered: hasBeenDiscovered,
    );
  }

  bool get isMastered {
    return learningState == PassportLearningState.mastered;
  }

  PassportCountryStampStage get stampStage {
    return PassportProgressRules.countryStampStage(
      unlockedAt: stampUnlockedAt,
      locationMasteryLevel: locationProgress.masteryLevel,
    );
  }

  PassportEntityProgress markDiscovered({
    required PassportDiscoverySource source,
    required DateTime discoveredAt,
  }) {
    if (this.discoveredAt != null) {
      return this;
    }

    return _copyWith(
      discoveredAt: discoveredAt,
      discoverySource: source,
    );
  }

  PassportEntityProgress registerAnswer({
    required PassportKnowledgeTheme theme,
    required bool isCorrect,
    required int masteryLevelAfterAnswer,
    required PassportDiscoverySource source,
    required DateTime answeredAt,
  }) {
    final PassportEntityProgress discovered = markDiscovered(
      source: source,
      discoveredAt: answeredAt,
    );
    final Map<PassportKnowledgeTheme, PassportThemeProgress> updatedThemes =
        Map<PassportKnowledgeTheme, PassportThemeProgress>.from(
      discovered.themes,
    );

    updatedThemes[theme] = discovered.progressFor(theme).registerAnswer(
          isCorrect: isCorrect,
          masteryLevelAfterAnswer: masteryLevelAfterAnswer,
          answeredAt: answeredAt,
        );

    final bool unlockStamp = discovered.stampUnlockedAt == null &&
        PassportProgressRules.shouldUnlockCountryStamp(
          isCorrect: isCorrect,
        );

    return discovered._copyWith(
      themes: Map<PassportKnowledgeTheme, PassportThemeProgress>.unmodifiable(
        updatedThemes,
      ),
      stampUnlockedAt: unlockStamp ? answeredAt : discovered.stampUnlockedAt,
      stampUnlockSource: unlockStamp ? source : discovered.stampUnlockSource,
    );
  }

  PassportEntityProgress setVisited(bool value) {
    return _copyWith(
      isVisited: value,
      isWishlisted: value ? false : isWishlisted,
    );
  }

  PassportEntityProgress setWishlisted(bool value) {
    return _copyWith(
      isWishlisted: value,
      isVisited: value ? false : isVisited,
    );
  }

  PassportEntityProgress setFavorite(bool value) {
    return _copyWith(isFavorite: value);
  }

  PassportEntityProgress _copyWith({
    DateTime? discoveredAt,
    PassportDiscoverySource? discoverySource,
    Map<PassportKnowledgeTheme, PassportThemeProgress>? themes,
    bool? isVisited,
    bool? isWishlisted,
    bool? isFavorite,
    DateTime? stampUnlockedAt,
    PassportDiscoverySource? stampUnlockSource,
  }) {
    return PassportEntityProgress._(
      entityId: entityId,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      discoverySource: discoverySource ?? this.discoverySource,
      themes: themes ?? this.themes,
      isVisited: isVisited ?? this.isVisited,
      isWishlisted: isWishlisted ?? this.isWishlisted,
      isFavorite: isFavorite ?? this.isFavorite,
      stampUnlockedAt: stampUnlockedAt ?? this.stampUnlockedAt,
      stampUnlockSource: stampUnlockSource ?? this.stampUnlockSource,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entityId': entityId,
      'discoveredAt': discoveredAt?.toIso8601String(),
      'discoverySource': discoverySource?.id,
      'themes': <String, dynamic>{
        for (final MapEntry<PassportKnowledgeTheme, PassportThemeProgress>
            entry in themes.entries)
          entry.key.id: entry.value.toJson(),
      },
      'isVisited': isVisited,
      'isWishlisted': isWishlisted,
      'isFavorite': isFavorite,
      'stampUnlockedAt': stampUnlockedAt?.toIso8601String(),
      'stampUnlockSource': stampUnlockSource?.id,
    };
  }

  factory PassportEntityProgress.fromJson(
    Map<String, dynamic> json,
  ) {
    final Map<PassportKnowledgeTheme, PassportThemeProgress> themes =
        <PassportKnowledgeTheme, PassportThemeProgress>{};
    final Object? rawThemes = json['themes'];

    if (rawThemes is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawThemes.entries) {
        final PassportKnowledgeTheme? theme =
            PassportKnowledgeTheme.fromId(entry.key.toString());

        if (theme == null || entry.value is! Map) {
          continue;
        }

        themes[theme] = PassportThemeProgress.fromJson(
          _asStringMap(entry.value as Map),
        );
      }
    }

    final bool visited = _readBool(json['isVisited']);
    final bool wishlisted = !visited && _readBool(json['isWishlisted']);
    final String discoverySourceId =
        json['discoverySource']?.toString().trim() ?? '';
    final String stampSourceId =
        json['stampUnlockSource']?.toString().trim() ?? '';

    return PassportEntityProgress._(
      entityId: GeoEntityId.require(json['entityId']?.toString() ?? ''),
      discoveredAt: _readOptionalDateTime(json['discoveredAt']),
      discoverySource: discoverySourceId.isEmpty
          ? null
          : PassportDiscoverySource.fromId(discoverySourceId),
      themes:
          Map<PassportKnowledgeTheme, PassportThemeProgress>.unmodifiable(
        themes,
      ),
      isVisited: visited,
      isWishlisted: wishlisted,
      isFavorite: _readBool(json['isFavorite']),
      stampUnlockedAt: _readOptionalDateTime(json['stampUnlockedAt']),
      stampUnlockSource: stampSourceId.isEmpty
          ? null
          : PassportDiscoverySource.fromId(stampSourceId),
    );
  }
}

int _readNonNegativeInt(Object? value) {
  final int parsed;

  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else {
    parsed = int.tryParse(value?.toString() ?? '') ?? 0;
  }

  return parsed < 0 ? 0 : parsed;
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }

  return value?.toString().trim().toLowerCase() == 'true';
}

DateTime? _readOptionalDateTime(Object? value) {
  final String text = value?.toString().trim() ?? '';

  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}

Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> source) {
  return source.map<String, dynamic>(
    (dynamic key, dynamic value) {
      return MapEntry<String, dynamic>(key.toString(), value);
    },
  );
}

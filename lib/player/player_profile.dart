import 'player_level.dart';
import 'player_statistics.dart';
import 'player_xp_ledger.dart';

enum PlayerProfileType {
  adult,
  child,
}

extension PlayerProfileTypeRules on PlayerProfileType {
  String get id => this == PlayerProfileType.child ? 'child' : 'adult';

  static PlayerProfileType fromId(Object? value) {
    return value?.toString().trim().toLowerCase() == 'child'
        ? PlayerProfileType.child
        : PlayerProfileType.adult;
  }
}

enum PlayerChildAgeGroup {
  ages6To8,
  ages9To11,
  ages12To14,
  ages15To17,
}

extension PlayerChildAgeGroupRules on PlayerChildAgeGroup {
  String get id {
    switch (this) {
      case PlayerChildAgeGroup.ages6To8:
        return '6_8';
      case PlayerChildAgeGroup.ages9To11:
        return '9_11';
      case PlayerChildAgeGroup.ages12To14:
        return '12_14';
      case PlayerChildAgeGroup.ages15To17:
        return '15_17';
    }
  }

  String get label {
    switch (this) {
      case PlayerChildAgeGroup.ages6To8:
        return '6 à 8 ans';
      case PlayerChildAgeGroup.ages9To11:
        return '9 à 11 ans';
      case PlayerChildAgeGroup.ages12To14:
        return '12 à 14 ans';
      case PlayerChildAgeGroup.ages15To17:
        return '15 à 17 ans';
    }
  }

  static PlayerChildAgeGroup? fromId(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case '6_8':
        return PlayerChildAgeGroup.ages6To8;
      case '9_11':
        return PlayerChildAgeGroup.ages9To11;
      case '12_14':
        return PlayerChildAgeGroup.ages12To14;
      case '15_17':
        return PlayerChildAgeGroup.ages15To17;
      default:
        return null;
    }
  }
}

class PlayerProfile {
  const PlayerProfile({
    required this.schemaVersion,
    required this.playerId,
    required this.displayName,
    required this.avatarId,
    this.profileType = PlayerProfileType.adult,
    this.childAgeGroup,
    required this.totalXp,
    this.xpLedger = const PlayerXpLedger(),
    required this.gamesPlayed,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.totalScore,
    this.statisticsByMode = const <String, ModeStatistics>{},
    required this.detailedStatistics,
    required this.totalDistanceInKilometers,
    required this.totalElapsedSeconds,
    required this.createdAt,
    required this.lastPlayedAt,
  });

  static const int currentSchemaVersion = 6;

  /// Première version de sauvegarde utilisant la progression longue du
  /// point 27. Une sauvegarde plus ancienne conserve ses statistiques et son
  /// GeoBrain, mais son XP joueur repart une seule fois à zéro.
  static const int longProgressionSchemaVersion = 4;

  final int schemaVersion;

  final String playerId;
  final String displayName;
  final String avatarId;
  final PlayerProfileType profileType;
  final PlayerChildAgeGroup? childAgeGroup;

  bool get isChildProfile => profileType == PlayerProfileType.child;
  bool get advertisementsAllowed => !isChildProfile;
  bool get socialFeaturesAllowed => !isChildProfile;
  bool get publicRankingsAllowed => !isChildProfile;
  bool get purchasesAllowed => !isChildProfile;

  final int totalXp;
  final PlayerXpLedger xpLedger;

  final int gamesPlayed;
  final int correctAnswers;
  final int totalAnswers;
  final int totalScore;

  /// Statistiques détaillées pour chaque mode de jeu.
  ///
  /// Les anciennes sauvegardes restent compatibles :
  /// cette collection est simplement vide jusqu’à la
  /// prochaine partie terminée.
  final Map<String, ModeStatistics> statisticsByMode;

  /// Ventilations ajoutées par le Passeport 2.0. Une ancienne sauvegarde
  /// reçoit simplement un agrégat vide, sans modifier ses totaux historiques.
  final DetailedPlayerStatistics detailedStatistics;

  final double totalDistanceInKilometers;
  final int totalElapsedSeconds;

  final DateTime createdAt;
  final DateTime? lastPlayedAt;

  factory PlayerProfile.initial({
    String playerId = 'local_player',
    String displayName = 'Voyageur',
    String avatarId = 'default',
    PlayerProfileType profileType = PlayerProfileType.adult,
    PlayerChildAgeGroup? childAgeGroup,
    DateTime? createdAt,
  }) {
    final DateTime now = createdAt ?? DateTime.now();

    return PlayerProfile(
      schemaVersion: currentSchemaVersion,
      playerId: playerId.trim().isEmpty ? 'local_player' : playerId.trim(),
      displayName: displayName.trim().isEmpty ? 'Voyageur' : displayName.trim(),
      avatarId: avatarId.trim().isEmpty ? 'default' : avatarId.trim(),
      profileType: profileType,
      childAgeGroup:
          profileType == PlayerProfileType.child ? childAgeGroup : null,
      totalXp: 0,
      gamesPlayed: 0,
      correctAnswers: 0,
      totalAnswers: 0,
      totalScore: 0,
      statisticsByMode: const <String, ModeStatistics>{},
      detailedStatistics: DetailedPlayerStatistics.initial(),
      totalDistanceInKilometers: 0,
      totalElapsedSeconds: 0,
      createdAt: now,
      lastPlayedAt: null,
    );
  }

  int get currentLevel {
    return PlayerLevelCatalog.levelForTotalXp(totalXp);
  }

  PlayerLevel get level {
    return PlayerLevelCatalog.forLevel(currentLevel);
  }

  int get majorLevel {
    return level.majorLevel;
  }

  int get levelTier {
    return level.tier;
  }

  String get levelTierLabel {
    return level.tierLabel;
  }

  String get title {
    return level.title;
  }

  String get displayLevelTitle {
    return level.displayTitle;
  }

  int get xpIntoCurrentLevel {
    return PlayerLevelCatalog.xpIntoCurrentLevel(totalXp);
  }

  int get xpForNextLevel {
    return PlayerLevelCatalog.currentLevelXpTarget(totalXp);
  }

  int get xpRemainingForNextLevel {
    return PlayerLevelCatalog.xpNeededForNextLevel(totalXp);
  }

  double get levelProgress {
    return PlayerLevelCatalog.progressToNextLevel(totalXp);
  }

  bool get isMaximumLevel {
    return currentLevel >= PlayerLevelCatalog.maximumLevel;
  }

  bool get hasPlayed {
    return gamesPlayed > 0;
  }

  PlayerXpProfileUpdate applyXpGrant(PlayerXpGrantRequest request) {
    final PlayerXpGrantDecision decision = xpLedger.apply(request);

    if (!decision.wasGranted) {
      return PlayerXpProfileUpdate(
        profile: this,
        decision: decision,
      );
    }

    return PlayerXpProfileUpdate(
      profile: copyWith(
        totalXp: totalXp + decision.awardedXp,
        xpLedger: decision.updatedLedger,
      ),
      decision: decision,
    );
  }

  double get accuracy {
    if (totalAnswers <= 0) {
      return 0;
    }

    return correctAnswers / totalAnswers;
  }

  double get averageScore {
    if (gamesPlayed <= 0) {
      return 0;
    }

    return totalScore / gamesPlayed;
  }

  double get averageDistanceInKilometers {
    if (totalAnswers <= 0) {
      return 0;
    }

    return totalDistanceInKilometers / totalAnswers;
  }

  double get averageElapsedSeconds {
    if (totalAnswers <= 0) {
      return 0;
    }

    return totalElapsedSeconds / totalAnswers;
  }

  Duration get totalPlayTime {
    return Duration(seconds: totalElapsedSeconds);
  }

  ModeStatistics statisticsForMode(String modeId) {
    final String normalizedId = _normalizeStatisticsId(
      modeId,
      fallback: 'find_country',
    );

    return statisticsByMode[normalizedId] ??
        ModeStatistics.initial(normalizedId);
  }

  PlayerProfile registerGameResult({
    required int earnedXp,
    required PlayerXpLedger updatedXpLedger,
    required int gameScore,
    required int gameCorrectAnswers,
    required int gameTotalAnswers,
    String modeId = 'find_country',
    String difficultyId = 'discovery',
    required double gameDistanceInKilometers,
    required int gameElapsedSeconds,
    List<QuestionStatisticsResult> questionResults =
        const <QuestionStatisticsResult>[],
    DateTime? playedAt,
  }) {
    if (earnedXp < 0) {
      throw ArgumentError('L’XP gagnée ne peut pas être négative.');
    }

    if (gameScore < 0) {
      throw ArgumentError('Le score ne peut pas être négatif.');
    }

    if (gameCorrectAnswers < 0 ||
        gameTotalAnswers < 0 ||
        gameCorrectAnswers > gameTotalAnswers) {
      throw ArgumentError('Le nombre de bonnes réponses est invalide.');
    }

    if (gameDistanceInKilometers < 0) {
      throw ArgumentError('La distance totale ne peut pas être négative.');
    }

    if (gameElapsedSeconds < 0) {
      throw ArgumentError('Le temps total ne peut pas être négatif.');
    }

    final String normalizedModeId = _normalizeStatisticsId(
      modeId,
      fallback: 'find_country',
    );

    final String normalizedDifficultyId = _normalizeStatisticsId(
      difficultyId,
      fallback: 'discovery',
    );

    final Map<String, ModeStatistics> updatedStatistics =
        Map<String, ModeStatistics>.from(statisticsByMode);

    final DateTime resolvedPlayedAt = playedAt ?? DateTime.now();
    final List<QuestionStatisticsResult> resolvedQuestionResults =
        questionResults.isEmpty && gameTotalAnswers > 0
            ? _fallbackQuestionResults(
                modeId: normalizedModeId,
                correctAnswers: gameCorrectAnswers,
                totalAnswers: gameTotalAnswers,
                totalDistanceInKilometers: gameDistanceInKilometers,
                totalElapsedSeconds: gameElapsedSeconds,
              )
            : List<QuestionStatisticsResult>.unmodifiable(questionResults);

    updatedStatistics[normalizedModeId] = statisticsForMode(normalizedModeId)
        .registerGame(
          difficultyId: normalizedDifficultyId,
          score: gameScore,
          correctAnswers: gameCorrectAnswers,
          totalQuestions: gameTotalAnswers,
        );

    return copyWith(
      totalXp: totalXp + earnedXp,
      xpLedger: updatedXpLedger,
      gamesPlayed: gamesPlayed + 1,
      correctAnswers: correctAnswers + gameCorrectAnswers,
      totalAnswers: totalAnswers + gameTotalAnswers,
      totalScore: totalScore + gameScore,
      statisticsByMode: Map<String, ModeStatistics>.unmodifiable(
        updatedStatistics,
      ),
      detailedStatistics: detailedStatistics.registerGame(
        modeId: normalizedModeId,
        difficultyId: normalizedDifficultyId,
        questions: resolvedQuestionResults,
        playedAt: resolvedPlayedAt,
      ),
      totalDistanceInKilometers:
          totalDistanceInKilometers + gameDistanceInKilometers,
      totalElapsedSeconds: totalElapsedSeconds + gameElapsedSeconds,
      lastPlayedAt: resolvedPlayedAt,
    );
  }

  PlayerProfile registerStandaloneQuestionResult({
    required String modeId,
    required String difficultyId,
    required QuestionStatisticsResult result,
    DateTime? answeredAt,
  }) {
    final DateTime resolvedAnsweredAt = answeredAt ?? DateTime.now();
    final double distance = result.distanceInKilometers ?? 0;

    return copyWith(
      correctAnswers: correctAnswers + (result.isCorrect ? 1 : 0),
      totalAnswers: totalAnswers + 1,
      totalDistanceInKilometers: totalDistanceInKilometers + distance,
      totalElapsedSeconds:
          totalElapsedSeconds + result.elapsedSeconds.clamp(0, 86400),
      detailedStatistics: detailedStatistics.registerStandaloneQuestion(
        modeId: modeId,
        difficultyId: difficultyId,
        question: result,
        answeredAt: resolvedAnsweredAt,
      ),
      lastPlayedAt: resolvedAnsweredAt,
    );
  }

  PlayerProfile rename(String newDisplayName) {
    final String normalizedName = newDisplayName.trim();

    if (normalizedName.isEmpty || normalizedName == displayName) {
      return this;
    }

    return copyWith(displayName: normalizedName);
  }

  PlayerProfile changeAvatar(String newAvatarId) {
    final String normalizedAvatarId = newAvatarId.trim();

    if (normalizedAvatarId.isEmpty || normalizedAvatarId == avatarId) {
      return this;
    }

    return copyWith(avatarId: normalizedAvatarId);
  }

  PlayerProfile activateChildProtection(PlayerChildAgeGroup ageGroup) {
    if (isChildProfile && childAgeGroup == ageGroup) {
      return this;
    }
    return copyWith(
      profileType: PlayerProfileType.child,
      childAgeGroup: ageGroup,
    );
  }

  PlayerProfile copyWith({
    int? schemaVersion,
    String? playerId,
    String? displayName,
    String? avatarId,
    PlayerProfileType? profileType,
    PlayerChildAgeGroup? childAgeGroup,
    int? totalXp,
    PlayerXpLedger? xpLedger,
    int? gamesPlayed,
    int? correctAnswers,
    int? totalAnswers,
    int? totalScore,
    Map<String, ModeStatistics>? statisticsByMode,
    DetailedPlayerStatistics? detailedStatistics,
    double? totalDistanceInKilometers,
    int? totalElapsedSeconds,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    bool clearLastPlayedAt = false,
  }) {
    return PlayerProfile(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      profileType: profileType ?? this.profileType,
      childAgeGroup: (profileType ?? this.profileType) == PlayerProfileType.child
          ? childAgeGroup ?? this.childAgeGroup
          : null,
      totalXp: totalXp ?? this.totalXp,
      xpLedger: xpLedger ?? this.xpLedger,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalAnswers: totalAnswers ?? this.totalAnswers,
      totalScore: totalScore ?? this.totalScore,
      statisticsByMode: statisticsByMode ?? this.statisticsByMode,
      detailedStatistics: detailedStatistics ?? this.detailedStatistics,
      totalDistanceInKilometers:
          totalDistanceInKilometers ?? this.totalDistanceInKilometers,
      totalElapsedSeconds: totalElapsedSeconds ?? this.totalElapsedSeconds,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: clearLastPlayedAt
          ? null
          : lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'playerId': playerId,
      'displayName': displayName,
      'avatarId': avatarId,
      'profileType': profileType.id,
      if (childAgeGroup != null) 'childAgeGroup': childAgeGroup!.id,
      'totalXp': totalXp,
      'xpLedger': xpLedger.toJson(),
      'gamesPlayed': gamesPlayed,
      'correctAnswers': correctAnswers,
      'totalAnswers': totalAnswers,
      'totalScore': totalScore,
      'statisticsByMode': <String, dynamic>{
        for (final MapEntry<String, ModeStatistics> entry
            in statisticsByMode.entries)
          entry.key: entry.value.toJson(),
      },
      'detailedStatistics': detailedStatistics.toJson(),
      'totalDistanceInKilometers': totalDistanceInKilometers,
      'totalElapsedSeconds': totalElapsedSeconds,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    };
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final DateTime now = DateTime.now();
    final int sourceSchemaVersion = _readInt(
      json['schemaVersion'],
      fallback: 1,
    );
    final int savedTotalXp = _readInt(json['totalXp'], fallback: 0);
    final int restoredTotalXp =
        sourceSchemaVersion < longProgressionSchemaVersion
            ? 0
            : savedTotalXp.clamp(0, 1 << 31);

    final Map<String, ModeStatistics> statistics = <String, ModeStatistics>{};

    final Object? rawStatistics = json['statisticsByMode'];

    if (rawStatistics is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawStatistics.entries) {
        final String modeId = _normalizeStatisticsId(
          entry.key.toString(),
          fallback: '',
        );

        if (modeId.isEmpty || entry.value is! Map) {
          continue;
        }

        final Map<String, dynamic> modeJson = (entry.value as Map)
            .map<String, dynamic>((dynamic key, dynamic value) {
              return MapEntry<String, dynamic>(key.toString(), value);
            });

        statistics[modeId] = ModeStatistics.fromJson(modeId, modeJson);
      }
    }

    return PlayerProfile(
      schemaVersion: currentSchemaVersion,
      playerId: _readString(json['playerId'], fallback: 'local_player'),
      displayName: _readString(json['displayName'], fallback: 'Voyageur'),
      avatarId: _readString(json['avatarId'], fallback: 'default'),
      profileType: PlayerProfileTypeRules.fromId(json['profileType']),
      childAgeGroup: PlayerChildAgeGroupRules.fromId(json['childAgeGroup']),
      totalXp: restoredTotalXp,
      xpLedger: json['xpLedger'] is Map
          ? PlayerXpLedger.fromJson(
              (json['xpLedger'] as Map).map<String, dynamic>(
                (dynamic key, dynamic value) {
                  return MapEntry<String, dynamic>(key.toString(), value);
                },
              ),
            )
          : PlayerXpLedger.initial(),
      gamesPlayed: _readInt(json['gamesPlayed'], fallback: 0),
      correctAnswers: _readInt(json['correctAnswers'], fallback: 0),
      totalAnswers: _readInt(json['totalAnswers'], fallback: 0),
      totalScore: _readInt(json['totalScore'], fallback: 0),
      statisticsByMode: Map<String, ModeStatistics>.unmodifiable(statistics),
      detailedStatistics: json['detailedStatistics'] is Map
          ? DetailedPlayerStatistics.fromJson(
              (json['detailedStatistics'] as Map).map<String, dynamic>(
                (dynamic key, dynamic value) {
                  return MapEntry<String, dynamic>(key.toString(), value);
                },
              ),
            )
          : DetailedPlayerStatistics.initial(),
      totalDistanceInKilometers: _readDouble(
        json['totalDistanceInKilometers'],
        fallback: 0,
      ),
      totalElapsedSeconds: _readInt(json['totalElapsedSeconds'], fallback: 0),
      createdAt: _readDateTime(json['createdAt'], fallback: now),
      lastPlayedAt: _readOptionalDateTime(json['lastPlayedAt']),
    );
  }

  static String _readString(Object? value, {required String fallback}) {
    final String text = value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(Object? value, {required double fallback}) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime _readDateTime(Object? value, {required DateTime fallback}) {
    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return fallback;
    }

    return DateTime.tryParse(text) ?? fallback;
  }

  static DateTime? _readOptionalDateTime(Object? value) {
    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static String _normalizeStatisticsId(
    String value, {
    required String fallback,
  }) {
    final String normalized = value.trim().toLowerCase();

    return normalized.isEmpty ? fallback : normalized;
  }

  static List<QuestionStatisticsResult> _fallbackQuestionResults({
    required String modeId,
    required int correctAnswers,
    required int totalAnswers,
    required double totalDistanceInKilometers,
    required int totalElapsedSeconds,
  }) {
    final String themeId;
    switch (modeId) {
      case 'find_capital':
        themeId = 'capital';
        break;
      case 'find_flag':
        themeId = 'flag';
        break;
      case 'ultimate':
      case 'find_silhouette':
        themeId = 'silhouette';
        break;
      default:
        themeId = 'location';
        break;
    }

    final double? averageDistance = totalAnswers == 0 ||
            totalDistanceInKilometers <= 0
        ? null
        : totalDistanceInKilometers / totalAnswers;
    final int elapsedPerAnswer =
        totalAnswers == 0 ? 0 : totalElapsedSeconds ~/ totalAnswers;
    final int elapsedRemainder =
        totalAnswers == 0 ? 0 : totalElapsedSeconds % totalAnswers;

    return List<QuestionStatisticsResult>.generate(
      totalAnswers,
      (int index) {
        return QuestionStatisticsResult(
          countryId: 'unknown',
          continentId: 'unknown',
          themeId: themeId,
          isCorrect: index < correctAnswers,
          elapsedSeconds: elapsedPerAnswer + (index < elapsedRemainder ? 1 : 0),
          distanceInKilometers: averageDistance,
        );
      },
      growable: false,
    );
  }

  @override
  String toString() {
    return 'PlayerProfile('
        'displayName: $displayName, '
        'profileType: ${profileType.id}, '
        'level: $currentLevel, '
        'majorLevel: $majorLevel, '
        'title: $displayLevelTitle, '
        'totalXp: $totalXp, '
        'gamesPlayed: $gamesPlayed'
        ')';
  }
}

class PlayerXpProfileUpdate {
  const PlayerXpProfileUpdate({
    required this.profile,
    required this.decision,
  });

  final PlayerProfile profile;
  final PlayerXpGrantDecision decision;
}

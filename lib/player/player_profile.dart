import 'player_level.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.schemaVersion,
    required this.playerId,
    required this.displayName,
    required this.avatarId,
    required this.totalXp,
    required this.gamesPlayed,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.totalScore,
    required this.totalDistanceInKilometers,
    required this.totalElapsedSeconds,
    required this.createdAt,
    required this.lastPlayedAt,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;

  final String playerId;
  final String displayName;
  final String avatarId;

  final int totalXp;

  final int gamesPlayed;
  final int correctAnswers;
  final int totalAnswers;
  final int totalScore;

  final double totalDistanceInKilometers;
  final int totalElapsedSeconds;

  final DateTime createdAt;
  final DateTime? lastPlayedAt;

  factory PlayerProfile.initial({
    String playerId = 'local_player',
    String displayName = 'Voyageur',
    String avatarId = 'default',
    DateTime? createdAt,
  }) {
    final DateTime now =
        createdAt ?? DateTime.now();

    return PlayerProfile(
      schemaVersion:
          currentSchemaVersion,
      playerId:
          playerId.trim().isEmpty
              ? 'local_player'
              : playerId.trim(),
      displayName:
          displayName.trim().isEmpty
              ? 'Voyageur'
              : displayName.trim(),
      avatarId:
          avatarId.trim().isEmpty
              ? 'default'
              : avatarId.trim(),
      totalXp: 0,
      gamesPlayed: 0,
      correctAnswers: 0,
      totalAnswers: 0,
      totalScore: 0,
      totalDistanceInKilometers: 0,
      totalElapsedSeconds: 0,
      createdAt: now,
      lastPlayedAt: null,
    );
  }

  int get currentLevel {
    return PlayerLevelCatalog.levelForTotalXp(
      totalXp,
    );
  }

  PlayerLevel get level {
    return PlayerLevelCatalog.forLevel(
      currentLevel,
    );
  }

  String get title {
    return level.title;
  }

  int get xpIntoCurrentLevel {
    return PlayerLevelCatalog.xpIntoCurrentLevel(
      totalXp,
    );
  }

  int get xpForNextLevel {
    return PlayerLevelCatalog.currentLevelXpTarget(
      totalXp,
    );
  }

  int get xpRemainingForNextLevel {
    return PlayerLevelCatalog.xpNeededForNextLevel(
      totalXp,
    );
  }

  double get levelProgress {
    return PlayerLevelCatalog.progressToNextLevel(
      totalXp,
    );
  }

  bool get isMaximumLevel {
    return currentLevel >=
        PlayerLevelCatalog.maximumLevel;
  }

  bool get hasPlayed {
    return gamesPlayed > 0;
  }

  double get accuracy {
    if (totalAnswers <= 0) {
      return 0;
    }

    return correctAnswers /
        totalAnswers;
  }

  double get averageScore {
    if (gamesPlayed <= 0) {
      return 0;
    }

    return totalScore /
        gamesPlayed;
  }

  double get averageDistanceInKilometers {
    if (totalAnswers <= 0) {
      return 0;
    }

    return totalDistanceInKilometers /
        totalAnswers;
  }

  double get averageElapsedSeconds {
    if (totalAnswers <= 0) {
      return 0;
    }

    return totalElapsedSeconds /
        totalAnswers;
  }

  Duration get totalPlayTime {
    return Duration(
      seconds: totalElapsedSeconds,
    );
  }

  PlayerProfile registerGameResult({
    required int earnedXp,
    required int gameScore,
    required int gameCorrectAnswers,
    required int gameTotalAnswers,
    required double gameDistanceInKilometers,
    required int gameElapsedSeconds,
    DateTime? playedAt,
  }) {
    if (earnedXp < 0) {
      throw ArgumentError(
        'L’XP gagnée ne peut pas être négative.',
      );
    }

    if (gameScore < 0) {
      throw ArgumentError(
        'Le score ne peut pas être négatif.',
      );
    }

    if (gameCorrectAnswers < 0 ||
        gameTotalAnswers < 0 ||
        gameCorrectAnswers >
            gameTotalAnswers) {
      throw ArgumentError(
        'Le nombre de bonnes réponses est invalide.',
      );
    }

    if (gameDistanceInKilometers < 0) {
      throw ArgumentError(
        'La distance totale ne peut pas être négative.',
      );
    }

    if (gameElapsedSeconds < 0) {
      throw ArgumentError(
        'Le temps total ne peut pas être négatif.',
      );
    }

    return copyWith(
      totalXp:
          totalXp + earnedXp,
      gamesPlayed:
          gamesPlayed + 1,
      correctAnswers:
          correctAnswers +
              gameCorrectAnswers,
      totalAnswers:
          totalAnswers +
              gameTotalAnswers,
      totalScore:
          totalScore +
              gameScore,
      totalDistanceInKilometers:
          totalDistanceInKilometers +
              gameDistanceInKilometers,
      totalElapsedSeconds:
          totalElapsedSeconds +
              gameElapsedSeconds,
      lastPlayedAt:
          playedAt ?? DateTime.now(),
    );
  }

  PlayerProfile rename(
    String newDisplayName,
  ) {
    final String normalizedName =
        newDisplayName.trim();

    if (normalizedName.isEmpty ||
        normalizedName == displayName) {
      return this;
    }

    return copyWith(
      displayName: normalizedName,
    );
  }

  PlayerProfile changeAvatar(
    String newAvatarId,
  ) {
    final String normalizedAvatarId =
        newAvatarId.trim();

    if (normalizedAvatarId.isEmpty ||
        normalizedAvatarId == avatarId) {
      return this;
    }

    return copyWith(
      avatarId: normalizedAvatarId,
    );
  }

  PlayerProfile copyWith({
    int? schemaVersion,
    String? playerId,
    String? displayName,
    String? avatarId,
    int? totalXp,
    int? gamesPlayed,
    int? correctAnswers,
    int? totalAnswers,
    int? totalScore,
    double? totalDistanceInKilometers,
    int? totalElapsedSeconds,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    bool clearLastPlayedAt = false,
  }) {
    return PlayerProfile(
      schemaVersion:
          schemaVersion ??
              this.schemaVersion,
      playerId:
          playerId ??
              this.playerId,
      displayName:
          displayName ??
              this.displayName,
      avatarId:
          avatarId ??
              this.avatarId,
      totalXp:
          totalXp ??
              this.totalXp,
      gamesPlayed:
          gamesPlayed ??
              this.gamesPlayed,
      correctAnswers:
          correctAnswers ??
              this.correctAnswers,
      totalAnswers:
          totalAnswers ??
              this.totalAnswers,
      totalScore:
          totalScore ??
              this.totalScore,
      totalDistanceInKilometers:
          totalDistanceInKilometers ??
              this.totalDistanceInKilometers,
      totalElapsedSeconds:
          totalElapsedSeconds ??
              this.totalElapsedSeconds,
      createdAt:
          createdAt ??
              this.createdAt,
      lastPlayedAt:
          clearLastPlayedAt
              ? null
              : lastPlayedAt ??
                  this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion':
          schemaVersion,
      'playerId':
          playerId,
      'displayName':
          displayName,
      'avatarId':
          avatarId,
      'totalXp':
          totalXp,
      'gamesPlayed':
          gamesPlayed,
      'correctAnswers':
          correctAnswers,
      'totalAnswers':
          totalAnswers,
      'totalScore':
          totalScore,
      'totalDistanceInKilometers':
          totalDistanceInKilometers,
      'totalElapsedSeconds':
          totalElapsedSeconds,
      'createdAt':
          createdAt.toIso8601String(),
      'lastPlayedAt':
          lastPlayedAt?.toIso8601String(),
    };
  }

  factory PlayerProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    final DateTime now =
        DateTime.now();

    return PlayerProfile(
      schemaVersion:
          _readInt(
        json['schemaVersion'],
        fallback:
            currentSchemaVersion,
      ),
      playerId:
          _readString(
        json['playerId'],
        fallback:
            'local_player',
      ),
      displayName:
          _readString(
        json['displayName'],
        fallback:
            'Voyageur',
      ),
      avatarId:
          _readString(
        json['avatarId'],
        fallback:
            'default',
      ),
      totalXp:
          _readInt(
        json['totalXp'],
        fallback: 0,
      ),
      gamesPlayed:
          _readInt(
        json['gamesPlayed'],
        fallback: 0,
      ),
      correctAnswers:
          _readInt(
        json['correctAnswers'],
        fallback: 0,
      ),
      totalAnswers:
          _readInt(
        json['totalAnswers'],
        fallback: 0,
      ),
      totalScore:
          _readInt(
        json['totalScore'],
        fallback: 0,
      ),
      totalDistanceInKilometers:
          _readDouble(
        json[
            'totalDistanceInKilometers'],
        fallback: 0,
      ),
      totalElapsedSeconds:
          _readInt(
        json['totalElapsedSeconds'],
        fallback: 0,
      ),
      createdAt:
          _readDateTime(
        json['createdAt'],
        fallback: now,
      ),
      lastPlayedAt:
          _readOptionalDateTime(
        json['lastPlayedAt'],
      ),
    );
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

  static double _readDouble(
    Object? value, {
    required double fallback,
  }) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
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

  static DateTime? _readOptionalDateTime(
    Object? value,
  ) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  @override
  String toString() {
    return 'PlayerProfile('
        'displayName: $displayName, '
        'level: $currentLevel, '
        'title: $title, '
        'totalXp: $totalXp, '
        'gamesPlayed: $gamesPlayed'
        ')';
  }
}
import 'challenge_season_reward.dart';

enum ChallengeLeaderboardKind {
  daily,
  weekly,
  season,
}

enum ChallengeLeaderboardScope {
  global,
  friends,
}

extension ChallengeLeaderboardScopeRules on ChallengeLeaderboardScope {
  String get id {
    switch (this) {
      case ChallengeLeaderboardScope.global:
        return 'global';
      case ChallengeLeaderboardScope.friends:
        return 'friends';
    }
  }

  String get label {
    switch (this) {
      case ChallengeLeaderboardScope.global:
        return 'Monde';
      case ChallengeLeaderboardScope.friends:
        return 'Amis';
    }
  }
}

extension ChallengeLeaderboardKindRules on ChallengeLeaderboardKind {
  String get id {
    switch (this) {
      case ChallengeLeaderboardKind.daily:
        return 'daily';
      case ChallengeLeaderboardKind.weekly:
        return 'weekly';
      case ChallengeLeaderboardKind.season:
        return 'season';
    }
  }

  String get label {
    switch (this) {
      case ChallengeLeaderboardKind.daily:
        return 'Jour';
      case ChallengeLeaderboardKind.weekly:
        return 'Semaine';
      case ChallengeLeaderboardKind.season:
        return 'Saison';
    }
  }
}

class ChallengeLeaderboardEntry {
  const ChallengeLeaderboardEntry({
    required this.displayName,
    required this.avatarId,
    required this.score,
    required this.correctAnswers,
    required this.averageDistanceKilometers,
    required this.elapsedSeconds,
    required this.challengeCount,
    required this.isCurrentPlayer,
    this.rank,
  });

  final int? rank;
  final String displayName;
  final String avatarId;
  final int score;
  final int correctAnswers;
  final double averageDistanceKilometers;
  final int elapsedSeconds;
  final int challengeCount;
  final bool isCurrentPlayer;

  factory ChallengeLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return ChallengeLeaderboardEntry(
      rank: json['rank'] == null ? null : _readPositiveInt(json['rank']),
      displayName: _readString(json['displayName'], fallback: 'Explorateur'),
      avatarId: _readString(json['avatarId'], fallback: 'default'),
      score: _readNonNegativeInt(json['score']),
      correctAnswers: _readNonNegativeInt(json['correctAnswers']),
      averageDistanceKilometers:
          _readNonNegativeDouble(json['averageDistanceKilometers']),
      elapsedSeconds: _readNonNegativeInt(json['elapsedSeconds']),
      challengeCount: _readPositiveInt(
        json['challengeCount'],
        fallback: 1,
      ),
      isCurrentPlayer: json['isCurrentPlayer'] == true,
    );
  }
}

class ChallengeLeaderboardBoard {
  const ChallengeLeaderboardBoard({
    required this.boardId,
    required this.kind,
    required this.title,
    required this.seasonKey,
    required this.totalParticipants,
    required this.entries,
    this.currentPlayerEntry,
  });

  final String boardId;
  final ChallengeLeaderboardKind kind;
  final String title;
  final String seasonKey;
  final int totalParticipants;
  final List<ChallengeLeaderboardEntry> entries;
  final ChallengeLeaderboardEntry? currentPlayerEntry;

  ChallengeLeaderboardEntry? get visibleCurrentPlayerEntry {
    for (final ChallengeLeaderboardEntry entry in entries) {
      if (entry.isCurrentPlayer) {
        return entry;
      }
    }
    return currentPlayerEntry;
  }

  factory ChallengeLeaderboardBoard.fromJson(Map<String, dynamic> json) {
    final Object? rawEntries = json['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Entrées de classement invalides.');
    }
    final Object? rawCurrent = json['currentPlayerEntry'];
    return ChallengeLeaderboardBoard(
      boardId: _readString(json['boardId']),
      kind: _kindFromId(json['type']),
      title: _readString(json['title'], fallback: 'Classement'),
      seasonKey: _readString(json['seasonKey']),
      totalParticipants: _readNonNegativeInt(json['totalParticipants']),
      entries: List<ChallengeLeaderboardEntry>.unmodifiable(
        rawEntries.map<ChallengeLeaderboardEntry>((Object? value) {
          return ChallengeLeaderboardEntry.fromJson(_readMap(value));
        }),
      ),
      currentPlayerEntry: rawCurrent == null
          ? null
          : ChallengeLeaderboardEntry.fromJson(_readMap(rawCurrent)),
    );
  }
}

enum ChallengeRankingHistoryStatus {
  validated,
  quarantined,
  rejected,
}

extension ChallengeRankingHistoryStatusRules on ChallengeRankingHistoryStatus {
  String get label {
    switch (this) {
      case ChallengeRankingHistoryStatus.validated:
        return 'Validée';
      case ChallengeRankingHistoryStatus.quarantined:
        return 'En vérification';
      case ChallengeRankingHistoryStatus.rejected:
        return 'Refusée';
    }
  }
}

class ChallengeRankingHistoryEntry {
  const ChallengeRankingHistoryEntry({
    required this.submissionId,
    required this.challengeId,
    required this.challengeTitle,
    required this.completedAtUtc,
    required this.score,
    required this.correctAnswers,
    required this.elapsedSeconds,
    required this.status,
    required this.isBest,
    this.reason,
  });

  final String submissionId;
  final String challengeId;
  final String challengeTitle;
  final DateTime completedAtUtc;
  final int score;
  final int correctAnswers;
  final int elapsedSeconds;
  final ChallengeRankingHistoryStatus status;
  final bool isBest;
  final String? reason;

  factory ChallengeRankingHistoryEntry.fromJson(Map<String, dynamic> json) {
    final DateTime? completedAt =
        DateTime.tryParse(json['completedAtUtc']?.toString() ?? '');
    if (completedAt == null) {
      throw const FormatException('Date d’historique invalide.');
    }
    return ChallengeRankingHistoryEntry(
      submissionId: _readString(json['submissionId']),
      challengeId: _readString(json['challengeId']),
      challengeTitle: _readString(
        json['challengeTitle'],
        fallback: 'Défi PointGeo',
      ),
      completedAtUtc: completedAt.toUtc(),
      score: _readNonNegativeInt(json['score']),
      correctAnswers: _readNonNegativeInt(json['correctAnswers']),
      elapsedSeconds: _readNonNegativeInt(json['elapsedSeconds']),
      status: _historyStatusFromId(json['status']),
      isBest: json['isBest'] == true,
      reason: _readOptionalString(json['reason']),
    );
  }
}

class ChallengeLeaderboardSnapshot {
  const ChallengeLeaderboardSnapshot({
    required this.serverNowUtc,
    required this.boards,
    this.scope = ChallengeLeaderboardScope.global,
    this.seasonRewardTiers = ChallengeSeasonRewardTier.defaults,
    this.currentPlayerHistory = const <ChallengeRankingHistoryEntry>[],
  });

  final DateTime serverNowUtc;
  final ChallengeLeaderboardScope scope;
  final List<ChallengeLeaderboardBoard> boards;
  final List<ChallengeSeasonRewardTier> seasonRewardTiers;
  final List<ChallengeRankingHistoryEntry> currentPlayerHistory;

  ChallengeLeaderboardBoard? boardFor(ChallengeLeaderboardKind kind) {
    for (final ChallengeLeaderboardBoard board in boards) {
      if (board.kind == kind) {
        return board;
      }
    }
    return null;
  }

  List<ChallengeLeaderboardBoard> boardsFor(
    ChallengeLeaderboardKind kind,
  ) {
    return boards
        .where((ChallengeLeaderboardBoard board) => board.kind == kind)
        .toList(growable: false);
  }

  factory ChallengeLeaderboardSnapshot.fromJson(Map<String, dynamic> json) {
    final DateTime? serverNow =
        DateTime.tryParse(json['serverNowUtc']?.toString() ?? '');
    final Object? rawBoards = json['boards'];
    if (serverNow == null || rawBoards is! List) {
      throw const FormatException('Réponse des classements invalide.');
    }
    final Object? rawPolicy = json['seasonRewardPolicy'];
    final Object? rawHistory = json['currentPlayerHistory'];
    final Object? rawTiers = rawPolicy is Map
        ? rawPolicy['tiers']
        : null;
    final List<ChallengeSeasonRewardTier> tiers = rawTiers is List
        ? rawTiers.map<ChallengeSeasonRewardTier>((Object? value) {
            return ChallengeSeasonRewardTier.fromJson(_readMap(value));
          }).toList(growable: false)
        : ChallengeSeasonRewardTier.defaults;
    if (tiers.isEmpty ||
        !tiers.any(
          (ChallengeSeasonRewardTier tier) => tier.maximumRank == null,
        )) {
      throw const FormatException('Paliers de saison manquants.');
    }
    return ChallengeLeaderboardSnapshot(
      serverNowUtc: serverNow.toUtc(),
      scope: _scopeFromId(json['scope']),
      seasonRewardTiers:
          List<ChallengeSeasonRewardTier>.unmodifiable(tiers),
      currentPlayerHistory: List<ChallengeRankingHistoryEntry>.unmodifiable(
        rawHistory is List
            ? rawHistory.map<ChallengeRankingHistoryEntry>((Object? value) {
                return ChallengeRankingHistoryEntry.fromJson(_readMap(value));
              })
            : const <ChallengeRankingHistoryEntry>[],
      ),
      boards: List<ChallengeLeaderboardBoard>.unmodifiable(
        rawBoards.map<ChallengeLeaderboardBoard>((Object? value) {
          return ChallengeLeaderboardBoard.fromJson(_readMap(value));
        }),
      ),
    );
  }
}

ChallengeRankingHistoryStatus _historyStatusFromId(Object? value) {
  switch (value?.toString().trim().toLowerCase()) {
    case 'validated':
      return ChallengeRankingHistoryStatus.validated;
    case 'quarantined':
      return ChallengeRankingHistoryStatus.quarantined;
    case 'rejected':
      return ChallengeRankingHistoryStatus.rejected;
    default:
      throw const FormatException('Statut d’historique inconnu.');
  }
}

abstract interface class ChallengeLeaderboardGateway {
  Future<ChallengeLeaderboardSnapshot> fetchLeaderboards({
    required List<String> rankingGroupIds,
    required String seasonKey,
    ChallengeLeaderboardScope scope = ChallengeLeaderboardScope.global,
  });
}

ChallengeLeaderboardScope _scopeFromId(Object? value) {
  switch (value?.toString().trim().toLowerCase()) {
    case null:
    case '':
    case 'global':
      return ChallengeLeaderboardScope.global;
    case 'friends':
      return ChallengeLeaderboardScope.friends;
    default:
      throw const FormatException('Portée de classement inconnue.');
  }
}

ChallengeLeaderboardKind _kindFromId(Object? value) {
  switch (value?.toString().trim().toLowerCase()) {
    case 'daily':
      return ChallengeLeaderboardKind.daily;
    case 'weekly':
      return ChallengeLeaderboardKind.weekly;
    case 'season':
      return ChallengeLeaderboardKind.season;
    default:
      throw const FormatException('Type de classement inconnu.');
  }
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Objet de classement invalide.');
  }
  return value.map<String, dynamic>(
    (dynamic key, dynamic item) =>
        MapEntry<String, dynamic>(key.toString(), item),
  );
}

String _readString(Object? value, {String? fallback}) {
  final String normalized = value?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    if (fallback != null) {
      return fallback;
    }
    throw const FormatException('Texte de classement manquant.');
  }
  return normalized;
}

String? _readOptionalString(Object? value) {
  final String normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

int _readNonNegativeInt(Object? value) {
  final int? parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) {
    throw const FormatException('Nombre de classement invalide.');
  }
  return parsed;
}

int _readPositiveInt(Object? value, {int? fallback}) {
  if (value == null && fallback != null) {
    return fallback;
  }
  final int parsed = _readNonNegativeInt(value);
  if (parsed <= 0) {
    throw const FormatException('Nombre positif de classement invalide.');
  }
  return parsed;
}

double _readNonNegativeDouble(Object? value) {
  final double? parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite || parsed < 0) {
    throw const FormatException('Précision de classement invalide.');
  }
  return parsed;
}

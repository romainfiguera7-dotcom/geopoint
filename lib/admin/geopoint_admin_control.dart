enum GeoPointAdminScoreAction {
  approveQuarantine('approve_quarantine'),
  rejectQuarantine('reject_quarantine'),
  invalidate('invalidate'),
  restore('restore'),
  restoreExpired('restore_expired');

  const GeoPointAdminScoreAction(this.id);
  final String id;
}

enum GeoPointAdminCompetitionAction {
  enable('enable'),
  disable('disable'),
  rebuild('rebuild');

  const GeoPointAdminCompetitionAction(this.id);
  final String id;
}

class GeoPointAdminCounters {
  const GeoPointAdminCounters({
    required this.pendingReviews,
    required this.rejectedSubmissions,
    required this.activeSessions,
  });

  final int pendingReviews;
  final int rejectedSubmissions;
  final int activeSessions;

  factory GeoPointAdminCounters.fromJson(Map<String, dynamic> json) {
    return GeoPointAdminCounters(
      pendingReviews: _integer(json['pendingReviews']),
      rejectedSubmissions: _integer(json['rejectedSubmissions']),
      activeSessions: _integer(json['activeSessions']),
    );
  }
}

class GeoPointAdminSubmission {
  const GeoPointAdminSubmission({
    required this.playerId,
    required this.submissionId,
    required this.challengeId,
    required this.rankingGroupId,
    required this.status,
    required this.score,
    required this.correctAnswers,
    required this.averageDistanceKilometers,
    required this.elapsedSeconds,
    this.completedAtUtc,
    this.reason,
  });

  final String playerId;
  final String submissionId;
  final String challengeId;
  final String rankingGroupId;
  final String status;
  final int score;
  final int correctAnswers;
  final double averageDistanceKilometers;
  final int elapsedSeconds;
  final DateTime? completedAtUtc;
  final String? reason;

  List<GeoPointAdminScoreAction> get availableActions {
    if (status == 'quarantined') {
      return const <GeoPointAdminScoreAction>[
        GeoPointAdminScoreAction.approveQuarantine,
        GeoPointAdminScoreAction.rejectQuarantine,
      ];
    }
    if (status == 'validated' ||
        status == 'validated_manual' ||
        status == 'validated_pending_identity') {
      return const <GeoPointAdminScoreAction>[
        GeoPointAdminScoreAction.invalidate,
      ];
    }
    if (status == 'invalidated_manual') {
      return const <GeoPointAdminScoreAction>[
        GeoPointAdminScoreAction.restore,
      ];
    }
    if (status == 'rejected' &&
        reason == 'La session officielle a expiré.') {
      return const <GeoPointAdminScoreAction>[
        GeoPointAdminScoreAction.restoreExpired,
      ];
    }
    return const <GeoPointAdminScoreAction>[];
  }

  factory GeoPointAdminSubmission.fromJson(Map<String, dynamic> json) {
    return GeoPointAdminSubmission(
      playerId: _requiredText(json, 'playerId'),
      submissionId: _requiredText(json, 'submissionId'),
      challengeId: json['challengeId']?.toString() ?? '',
      rankingGroupId: json['rankingGroupId']?.toString() ?? '',
      status: _requiredText(json, 'status'),
      score: _integer(json['score']),
      correctAnswers: _integer(json['correctAnswers']),
      averageDistanceKilometers: _number(
        json['averageDistanceKilometers'],
      ),
      elapsedSeconds: _integer(json['elapsedSeconds']),
      completedAtUtc: _date(json['completedAtUtc']),
      reason: _optionalText(json['reason']),
    );
  }
}

class GeoPointAdminPlayer {
  const GeoPointAdminPlayer({
    required this.playerId,
    required this.status,
    required this.profileType,
    required this.totalXp,
    required this.gamesPlayed,
    this.migrationStatus,
  });

  final String playerId;
  final String status;
  final String profileType;
  final int totalXp;
  final int gamesPlayed;
  final String? migrationStatus;

  factory GeoPointAdminPlayer.fromJson(Map<String, dynamic> json) {
    return GeoPointAdminPlayer(
      playerId: _requiredText(json, 'playerId'),
      status: _requiredText(json, 'status'),
      profileType: _requiredText(json, 'profileType'),
      totalXp: _integer(json['totalXp']),
      gamesPlayed: _integer(json['gamesPlayed']),
      migrationStatus: _optionalText(json['migrationStatus']),
    );
  }
}

class GeoPointAdminCompetition {
  const GeoPointAdminCompetition({
    required this.rankingGroupId,
    required this.challengeId,
    required this.type,
    required this.seasonKey,
    required this.disabled,
    this.disabledReason,
  });

  final String rankingGroupId;
  final String challengeId;
  final String type;
  final String seasonKey;
  final bool disabled;
  final String? disabledReason;

  factory GeoPointAdminCompetition.fromJson(Map<String, dynamic> json) {
    return GeoPointAdminCompetition(
      rankingGroupId: _requiredText(json, 'rankingGroupId'),
      challengeId: json['challengeId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'challenge',
      seasonKey: json['seasonKey']?.toString() ?? '',
      disabled: json['disabled'] == true,
      disabledReason: _optionalText(json['disabledReason']),
    );
  }
}

class GeoPointAdminAuditLog {
  const GeoPointAdminAuditLog({
    required this.action,
    required this.target,
    required this.reason,
    required this.actorUid,
    required this.before,
    required this.after,
    this.createdAtUtc,
  });

  final String action;
  final String target;
  final String reason;
  final String actorUid;
  final String before;
  final String after;
  final DateTime? createdAtUtc;

  factory GeoPointAdminAuditLog.fromJson(Map<String, dynamic> json) {
    return GeoPointAdminAuditLog(
      action: _requiredText(json, 'action'),
      target: _requiredText(json, 'target'),
      reason: _requiredText(json, 'reason'),
      actorUid: _requiredText(json, 'actorUid'),
      before: json['before']?.toString() ?? '',
      after: json['after']?.toString() ?? '',
      createdAtUtc: _date(json['createdAtUtc']),
    );
  }
}

class GeoPointAdminDashboard {
  const GeoPointAdminDashboard({
    required this.serverNowUtc,
    required this.counters,
    required this.submissions,
    required this.auditLogs,
    this.player,
    this.competition,
  });

  final DateTime serverNowUtc;
  final GeoPointAdminCounters counters;
  final List<GeoPointAdminSubmission> submissions;
  final List<GeoPointAdminAuditLog> auditLogs;
  final GeoPointAdminPlayer? player;
  final GeoPointAdminCompetition? competition;

  factory GeoPointAdminDashboard.fromJson(Map<String, dynamic> json) {
    if (json['apiVersion'] != 1) {
      throw const FormatException('apiVersion du contrôle interne invalide.');
    }
    final DateTime? serverNow = _date(json['serverNowUtc']);
    if (serverNow == null) {
      throw const FormatException('Horloge du contrôle interne invalide.');
    }
    return GeoPointAdminDashboard(
      serverNowUtc: serverNow,
      counters: GeoPointAdminCounters.fromJson(_map(json['counters'])),
      submissions: _list(json['submissions'])
          .map((item) => GeoPointAdminSubmission.fromJson(_map(item)))
          .toList(growable: false),
      auditLogs: _list(json['auditLogs'])
          .map((item) => GeoPointAdminAuditLog.fromJson(_map(item)))
          .toList(growable: false),
      player: json['player'] == null
          ? null
          : GeoPointAdminPlayer.fromJson(_map(json['player'])),
      competition: json['competition'] == null
          ? null
          : GeoPointAdminCompetition.fromJson(_map(json['competition'])),
    );
  }
}

class GeoPointAdminPublishedPack {
  const GeoPointAdminPublishedPack({
    required this.packId,
    required this.revision,
    required this.challengeCount,
  });

  final String packId;
  final int revision;
  final int challengeCount;

  factory GeoPointAdminPublishedPack.fromJson(Map<String, dynamic> json) {
    return GeoPointAdminPublishedPack(
      packId: _requiredText(json, 'packId'),
      revision: _integer(json['revision']),
      challengeCount: _integer(json['challengeCount']),
    );
  }
}

abstract interface class GeoPointAdminGateway {
  Future<GeoPointAdminDashboard> fetchDashboard({String query = ''});

  Future<void> updateSubmission({
    required String playerId,
    required String submissionId,
    required GeoPointAdminScoreAction action,
    required String reason,
  });

  Future<void> updateCompetition({
    required String rankingGroupId,
    required GeoPointAdminCompetitionAction action,
    required String reason,
  });

  Future<String> grantAdFreeByFriendCode({
    required String friendCode,
    required String reason,
  });

  Future<GeoPointAdminPublishedPack> publishChallengePack(String jsonSource);
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Objet administrateur invalide.');
  return value.map<String, dynamic>(
    (dynamic key, dynamic item) => MapEntry<String, dynamic>(key.toString(), item),
  );
}

List<dynamic> _list(Object? value) {
  if (value is! List) throw const FormatException('Liste administrateur invalide.');
  return value;
}

String _requiredText(Map<String, dynamic> json, String key) {
  final String value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw FormatException('$key est invalide.');
  return value;
}

String? _optionalText(Object? value) {
  final String normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

int _integer(Object? value) => value is num ? value.toInt() : 0;
double _number(Object? value) => value is num ? value.toDouble() : 0;
DateTime? _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toUtc();

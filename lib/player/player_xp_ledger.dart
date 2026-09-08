import 'dart:math' as math;

enum PlayerXpSource {
  gameCompleted,
  firstSuccessOfDay,
  challengeCompleted,
  expeditionMissionCompleted,
  expeditionExamCompleted,
  countryDiscovered,
  countryMastered,
  themeMastered,
  objectiveCompleted,
  achievementCompleted,
  dailyStreak,
  weeklyStreak,
  eventBonus,
  advertisement,
  purchase,
  paidRetry,
  tutorialCompleted,
  trainingCompleted,
}

extension PlayerXpSourceRules on PlayerXpSource {
  String get id {
    switch (this) {
      case PlayerXpSource.gameCompleted:
        return 'game_completed';
      case PlayerXpSource.firstSuccessOfDay:
        return 'first_success_of_day';
      case PlayerXpSource.challengeCompleted:
        return 'challenge_completed';
      case PlayerXpSource.expeditionMissionCompleted:
        return 'expedition_mission_completed';
      case PlayerXpSource.expeditionExamCompleted:
        return 'expedition_exam_completed';
      case PlayerXpSource.countryDiscovered:
        return 'country_discovered';
      case PlayerXpSource.countryMastered:
        return 'country_mastered';
      case PlayerXpSource.themeMastered:
        return 'theme_mastered';
      case PlayerXpSource.objectiveCompleted:
        return 'objective_completed';
      case PlayerXpSource.achievementCompleted:
        return 'achievement_completed';
      case PlayerXpSource.dailyStreak:
        return 'daily_streak';
      case PlayerXpSource.weeklyStreak:
        return 'weekly_streak';
      case PlayerXpSource.eventBonus:
        return 'event_bonus';
      case PlayerXpSource.advertisement:
        return 'advertisement';
      case PlayerXpSource.purchase:
        return 'purchase';
      case PlayerXpSource.paidRetry:
        return 'paid_retry';
      case PlayerXpSource.tutorialCompleted:
        return 'tutorial_completed';
      case PlayerXpSource.trainingCompleted:
        return 'training_completed';
    }
  }

  String get label {
    switch (this) {
      case PlayerXpSource.gameCompleted:
        return 'Partie terminée';
      case PlayerXpSource.firstSuccessOfDay:
        return 'Première réussite du jour';
      case PlayerXpSource.challengeCompleted:
        return 'Défi terminé';
      case PlayerXpSource.expeditionMissionCompleted:
        return 'Mission d’expédition';
      case PlayerXpSource.expeditionExamCompleted:
        return 'Examen d’expédition';
      case PlayerXpSource.countryDiscovered:
        return 'Nouveau pays découvert';
      case PlayerXpSource.countryMastered:
        return 'Nouveau pays maîtrisé';
      case PlayerXpSource.themeMastered:
        return 'Nouveau thème maîtrisé';
      case PlayerXpSource.objectiveCompleted:
        return 'Objectif accompli';
      case PlayerXpSource.achievementCompleted:
        return 'Accomplissement validé';
      case PlayerXpSource.dailyStreak:
        return 'Série quotidienne';
      case PlayerXpSource.weeklyStreak:
        return 'Série hebdomadaire';
      case PlayerXpSource.eventBonus:
        return 'Bonus d’événement';
      case PlayerXpSource.advertisement:
        return 'Publicité';
      case PlayerXpSource.purchase:
        return 'Achat';
      case PlayerXpSource.paidRetry:
        return 'Relance payante';
      case PlayerXpSource.tutorialCompleted:
        return 'Tutoriel';
      case PlayerXpSource.trainingCompleted:
        return 'Entraînement';
    }
  }

  bool get isForbidden {
    switch (this) {
      case PlayerXpSource.advertisement:
      case PlayerXpSource.purchase:
      case PlayerXpSource.paidRetry:
      case PlayerXpSource.tutorialCompleted:
      case PlayerXpSource.trainingCompleted:
        return true;
      default:
        return false;
    }
  }

  bool get keepsPermanentDeduplicationKey {
    switch (this) {
      case PlayerXpSource.firstSuccessOfDay:
      case PlayerXpSource.challengeCompleted:
      case PlayerXpSource.expeditionMissionCompleted:
      case PlayerXpSource.expeditionExamCompleted:
      case PlayerXpSource.countryDiscovered:
      case PlayerXpSource.countryMastered:
      case PlayerXpSource.themeMastered:
      case PlayerXpSource.objectiveCompleted:
      case PlayerXpSource.achievementCompleted:
      case PlayerXpSource.eventBonus:
        return true;
      default:
        return false;
    }
  }
}

class PlayerXpSourceCodec {
  const PlayerXpSourceCodec._();

  static PlayerXpSource fromId(String value) {
    final String normalized = value.trim().toLowerCase();

    for (final PlayerXpSource source in PlayerXpSource.values) {
      if (source.id == normalized) {
        return source;
      }
    }

    return PlayerXpSource.eventBonus;
  }
}

class PlayerXpGrantRequest {
  const PlayerXpGrantRequest({
    required this.grantId,
    required this.source,
    required this.baseXp,
    this.bonusXp = 0,
    required this.occurredAt,
  });

  final String grantId;
  final PlayerXpSource source;
  final int baseXp;
  final int bonusXp;
  final DateTime occurredAt;

  int get requestedXp => baseXp + bonusXp;
}

class PlayerXpGrantRecord {
  const PlayerXpGrantRecord({
    required this.grantId,
    required this.source,
    required this.baseXp,
    required this.bonusXp,
    required this.awardedXp,
    required this.occurredAt,
  });

  final String grantId;
  final PlayerXpSource source;
  final int baseXp;
  final int bonusXp;
  final int awardedXp;
  final DateTime occurredAt;

  int get requestedXp => baseXp + bonusXp;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'grantId': grantId,
      'source': source.id,
      'baseXp': baseXp,
      'bonusXp': bonusXp,
      'awardedXp': awardedXp,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
    };
  }

  factory PlayerXpGrantRecord.fromJson(Map<String, dynamic> json) {
    return PlayerXpGrantRecord(
      grantId: _readString(json['grantId']),
      source: PlayerXpSourceCodec.fromId(_readString(json['source'])),
      baseXp: _readInt(json['baseXp']),
      bonusXp: _readInt(json['bonusXp']),
      awardedXp: _readInt(json['awardedXp']),
      occurredAt: _readDateTime(json['occurredAt']),
    );
  }
}

enum PlayerXpGrantOutcome {
  granted,
  rejectedDuplicate,
  rejectedForbiddenSource,
  rejectedInvalidRequest,
}

class PlayerXpGrantDecision {
  const PlayerXpGrantDecision({
    required this.outcome,
    required this.requestedXp,
    required this.awardedXp,
    required this.updatedLedger,
    this.record,
  });

  final PlayerXpGrantOutcome outcome;
  final int requestedXp;
  final int awardedXp;
  final PlayerXpLedger updatedLedger;
  final PlayerXpGrantRecord? record;

  bool get wasGranted => awardedXp > 0;

  bool get wasRejected => !wasGranted;
}

class PlayerXpLedger {
  const PlayerXpLedger({
    this.schemaVersion = currentSchemaVersion,
    this.permanentGrantIds = const <String>{},
    this.recentGrantIds = const <String>[],
    this.recentGrants = const <PlayerXpGrantRecord>[],
  });

  static const int currentSchemaVersion = 2;
  static const int maximumRecentGrantIds = 500;
  static const int maximumRecentGrants = 50;

  final int schemaVersion;
  final Set<String> permanentGrantIds;
  final List<String> recentGrantIds;
  final List<PlayerXpGrantRecord> recentGrants;

  factory PlayerXpLedger.initial() {
    return const PlayerXpLedger();
  }

  bool containsGrant(String grantId) {
    final String normalized = grantId.trim();

    if (normalized.isEmpty) {
      return false;
    }

    return permanentGrantIds.contains(normalized) ||
        recentGrantIds.contains(normalized);
  }

  PlayerXpLedger withPermanentGrantIds(Iterable<String> grantIds) {
    final Set<String> updated = <String>{...permanentGrantIds};
    for (final String grantId in grantIds) {
      final String normalized = grantId.trim();
      if (normalized.isNotEmpty) {
        updated.add(normalized);
      }
    }

    if (updated.length == permanentGrantIds.length) {
      return this;
    }

    return PlayerXpLedger(
      schemaVersion: currentSchemaVersion,
      permanentGrantIds: Set<String>.unmodifiable(updated),
      recentGrantIds: recentGrantIds,
      recentGrants: recentGrants,
    );
  }

  PlayerXpGrantDecision apply(PlayerXpGrantRequest request) {
    final String grantId = request.grantId.trim();
    final int requestedXp = request.requestedXp;

    if (grantId.isEmpty ||
        request.baseXp < 0 ||
        request.bonusXp < 0 ||
        requestedXp <= 0) {
      return _rejected(
        outcome: PlayerXpGrantOutcome.rejectedInvalidRequest,
        requestedXp: math.max(0, requestedXp),
      );
    }

    if (request.source.isForbidden) {
      return _rejected(
        outcome: PlayerXpGrantOutcome.rejectedForbiddenSource,
        requestedXp: requestedXp,
      );
    }

    if (containsGrant(grantId)) {
      return _rejected(
        outcome: PlayerXpGrantOutcome.rejectedDuplicate,
        requestedXp: requestedXp,
      );
    }

    final PlayerXpGrantRecord record = PlayerXpGrantRecord(
      grantId: grantId,
      source: request.source,
      baseXp: request.baseXp,
      bonusXp: request.bonusXp,
      awardedXp: requestedXp,
      occurredAt: request.occurredAt.toUtc(),
    );
    final Set<String> updatedPermanentIds = <String>{...permanentGrantIds};
    List<String> updatedRecentIds = <String>[...recentGrantIds];

    if (request.source.keepsPermanentDeduplicationKey) {
      updatedPermanentIds.add(grantId);
    } else {
      updatedRecentIds.add(grantId);
      updatedRecentIds = _keepLast(
        updatedRecentIds,
        maximumRecentGrantIds,
      );
    }

    final List<PlayerXpGrantRecord> updatedRecentGrants =
        _keepLast<PlayerXpGrantRecord>(
      <PlayerXpGrantRecord>[...recentGrants, record],
      maximumRecentGrants,
    );
    final PlayerXpLedger updatedLedger = PlayerXpLedger(
      permanentGrantIds: Set<String>.unmodifiable(updatedPermanentIds),
      recentGrantIds: List<String>.unmodifiable(updatedRecentIds),
      recentGrants: List<PlayerXpGrantRecord>.unmodifiable(
        updatedRecentGrants,
      ),
    );

    return PlayerXpGrantDecision(
      outcome: PlayerXpGrantOutcome.granted,
      requestedXp: requestedXp,
      awardedXp: requestedXp,
      updatedLedger: updatedLedger,
      record: record,
    );
  }

  PlayerXpGrantDecision _rejected({
    required PlayerXpGrantOutcome outcome,
    required int requestedXp,
  }) {
    return PlayerXpGrantDecision(
      outcome: outcome,
      requestedXp: requestedXp,
      awardedXp: 0,
      updatedLedger: this,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'permanentGrantIds': permanentGrantIds.toList()..sort(),
      'recentGrantIds': recentGrantIds,
      'recentGrants': recentGrants
          .map((PlayerXpGrantRecord record) => record.toJson())
          .toList(growable: false),
    };
  }

  factory PlayerXpLedger.fromJson(Map<String, dynamic> json) {
    final Set<String> permanentIds = _readStringSet(
      json['permanentGrantIds'],
    );
    final List<String> recentIds = _readStringList(json['recentGrantIds']);

    final List<PlayerXpGrantRecord> records = <PlayerXpGrantRecord>[];
    final Object? rawRecords = json['recentGrants'];

    if (rawRecords is List) {
      for (final Object? rawRecord in rawRecords) {
        if (rawRecord is! Map) {
          continue;
        }

        final Map<String, dynamic> recordJson = rawRecord.map<String, dynamic>(
          (dynamic key, dynamic value) {
            return MapEntry<String, dynamic>(key.toString(), value);
          },
        );
        final PlayerXpGrantRecord record =
            PlayerXpGrantRecord.fromJson(recordJson);

        if (record.grantId.isNotEmpty && record.awardedXp > 0) {
          records.add(record);
        }
      }
    }

    return PlayerXpLedger(
      permanentGrantIds: Set<String>.unmodifiable(permanentIds),
      recentGrantIds: List<String>.unmodifiable(
        _keepLast(recentIds, maximumRecentGrantIds),
      ),
      recentGrants: List<PlayerXpGrantRecord>.unmodifiable(
        _keepLast(records, maximumRecentGrants),
      ),
    );
  }
}

List<T> _keepLast<T>(List<T> values, int maximumLength) {
  if (maximumLength <= 0) {
    return <T>[];
  }

  if (values.length <= maximumLength) {
    return List<T>.from(values);
  }

  return values.sublist(values.length - maximumLength);
}

Set<String> _readStringSet(Object? value) {
  return _readStringList(value).toSet();
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return <String>[];
  }

  return value
      .map((Object? item) => item?.toString().trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

String _readString(Object? value) {
  return value?.toString().trim() ?? '';
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _readDateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

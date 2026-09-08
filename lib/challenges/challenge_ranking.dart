import 'challenge_definition.dart';
import 'challenge_result.dart';

enum ChallengeRankingSubmissionStatus {
  pendingServerValidation,
  confirmed,
  quarantined,
  rejected,
}

extension ChallengeRankingSubmissionStatusRules
    on ChallengeRankingSubmissionStatus {
  String get id {
    switch (this) {
      case ChallengeRankingSubmissionStatus.pendingServerValidation:
        return 'pending_server_validation';
      case ChallengeRankingSubmissionStatus.confirmed:
        return 'confirmed';
      case ChallengeRankingSubmissionStatus.quarantined:
        return 'quarantined';
      case ChallengeRankingSubmissionStatus.rejected:
        return 'rejected';
    }
  }
}

class ChallengeLeaderboardPosition {
  const ChallengeLeaderboardPosition({
    required this.rank,
    required this.totalParticipants,
    required this.score,
    this.previousRank,
  });

  final int rank;
  final int totalParticipants;
  final int score;
  final int? previousRank;

  int? get movement {
    final int? previous = previousRank;
    return previous == null ? null : previous - rank;
  }

  factory ChallengeLeaderboardPosition.fromJson(Map<String, dynamic> json) {
    return ChallengeLeaderboardPosition(
      rank: _readNonNegativeInt(json['rank']),
      totalParticipants: _readNonNegativeInt(json['totalParticipants']),
      score: _readNonNegativeInt(json['score']),
      previousRank: json['previousRank'] == null
          ? null
          : _readNonNegativeInt(json['previousRank']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rank': rank,
      'totalParticipants': totalParticipants,
      'score': score,
      if (previousRank != null) 'previousRank': previousRank,
    };
  }
}

class ChallengeRankingSubmission {
  const ChallengeRankingSubmission({
    required this.submissionId,
    required this.challengeId,
    required this.rankingGroupId,
    required this.attemptNumber,
    required this.competitiveSignature,
    required this.completedAtUtc,
    required this.score,
    required this.correctAnswers,
    required this.averageDistanceKilometers,
    required this.elapsedSeconds,
    required this.status,
    this.officialSessionId,
    this.answerEvidence = const <ChallengeAnswerEvidence>[],
    this.position,
    this.reviewReason,
  });

  final String submissionId;
  final String challengeId;
  final String rankingGroupId;
  final int attemptNumber;
  final String competitiveSignature;
  final DateTime completedAtUtc;
  final int score;
  final int correctAnswers;
  final double averageDistanceKilometers;
  final int elapsedSeconds;
  final ChallengeRankingSubmissionStatus status;
  final String? officialSessionId;
  final List<ChallengeAnswerEvidence> answerEvidence;
  final ChallengeLeaderboardPosition? position;
  final String? reviewReason;

  bool get isPending {
    return status ==
        ChallengeRankingSubmissionStatus.pendingServerValidation;
  }

  ChallengeRankingSubmission confirm([ChallengeLeaderboardPosition? position]) {
    if (!isPending) {
      return this;
    }
    return _copyWith(
      status: ChallengeRankingSubmissionStatus.confirmed,
      position: position,
    );
  }

  ChallengeRankingSubmission quarantine({String? reason}) {
    if (!isPending) {
      return this;
    }
    return _copyWith(
      status: ChallengeRankingSubmissionStatus.quarantined,
      reviewReason: _normalizeOptionalText(reason),
    );
  }

  ChallengeRankingSubmission reject({String? reason}) {
    if (!isPending) {
      return this;
    }
    return _copyWith(
      status: ChallengeRankingSubmissionStatus.rejected,
      reviewReason: _normalizeOptionalText(reason),
    );
  }

  ChallengeRankingSubmission _copyWith({
    required ChallengeRankingSubmissionStatus status,
    ChallengeLeaderboardPosition? position,
    String? reviewReason,
  }) {
    return ChallengeRankingSubmission(
      submissionId: submissionId,
      challengeId: challengeId,
      rankingGroupId: rankingGroupId,
      attemptNumber: attemptNumber,
      competitiveSignature: competitiveSignature,
      completedAtUtc: completedAtUtc,
      score: score,
      correctAnswers: correctAnswers,
      averageDistanceKilometers: averageDistanceKilometers,
      elapsedSeconds: elapsedSeconds,
      status: status,
      officialSessionId: officialSessionId,
      answerEvidence: answerEvidence,
      position: position,
      reviewReason: reviewReason,
    );
  }

  factory ChallengeRankingSubmission.fromJson(Map<String, dynamic> json) {
    final String statusId = _readString(json['status']);
    final ChallengeRankingSubmissionStatus status;
    switch (statusId) {
      case 'confirmed':
        status = ChallengeRankingSubmissionStatus.confirmed;
      case 'quarantined':
        status = ChallengeRankingSubmissionStatus.quarantined;
      case 'rejected':
        status = ChallengeRankingSubmissionStatus.rejected;
      default:
        status =
            ChallengeRankingSubmissionStatus.pendingServerValidation;
    }
    final Map<String, dynamic>? positionJson = _readOptionalMap(
      json['position'],
    );
    return ChallengeRankingSubmission(
      submissionId: _readString(json['submissionId']),
      challengeId: _readString(json['challengeId']),
      rankingGroupId: _readString(json['rankingGroupId']),
      attemptNumber: _readPositiveInt(json['attemptNumber'], fallback: 1),
      competitiveSignature: _readString(json['competitiveSignature']),
      completedAtUtc: DateTime.tryParse('${json['completedAtUtc']}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      score: _readNonNegativeInt(json['score']),
      correctAnswers: _readNonNegativeInt(json['correctAnswers']),
      averageDistanceKilometers:
          _readNonNegativeDouble(json['averageDistanceKilometers']),
      elapsedSeconds: _readNonNegativeInt(json['elapsedSeconds']),
      status: status,
      officialSessionId: _normalizeOptionalText(
        json['officialSessionId']?.toString(),
      ),
      answerEvidence: _readAnswerEvidence(json['answerEvidence']),
      position: positionJson == null
          ? null
          : ChallengeLeaderboardPosition.fromJson(positionJson),
      reviewReason: _normalizeOptionalText(json['reviewReason']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    final ChallengeLeaderboardPosition? currentPosition = position;
    return <String, dynamic>{
      'submissionId': submissionId,
      'challengeId': challengeId,
      'rankingGroupId': rankingGroupId,
      'attemptNumber': attemptNumber,
      'competitiveSignature': competitiveSignature,
      'completedAtUtc': completedAtUtc.toUtc().toIso8601String(),
      'score': score,
      'correctAnswers': correctAnswers,
      'averageDistanceKilometers': averageDistanceKilometers,
      'elapsedSeconds': elapsedSeconds,
      'status': status.id,
      if (officialSessionId != null)
        'officialSessionId': officialSessionId,
      'answerEvidence': answerEvidence
          .map((ChallengeAnswerEvidence item) => item.toJson())
          .toList(growable: false),
      if (currentPosition != null) 'position': currentPosition.toJson(),
      if (reviewReason != null) 'reviewReason': reviewReason,
    };
  }
}

enum ChallengeRankingEnqueueOutcome {
  enqueued,
  ignoredNotRanked,
  ignoredOptedOut,
  rejectedInvalidPerformance,
  rejectedDuplicate,
}

class ChallengeRankingEnqueueDecision {
  const ChallengeRankingEnqueueDecision({
    required this.outcome,
    required this.updatedLedger,
    this.submission,
  });

  final ChallengeRankingEnqueueOutcome outcome;
  final ChallengeRankingLedger updatedLedger;
  final ChallengeRankingSubmission? submission;

  bool get wasEnqueued {
    return outcome == ChallengeRankingEnqueueOutcome.enqueued;
  }
}

class ChallengeRankingLedger {
  const ChallengeRankingLedger({
    this.schemaVersion = currentSchemaVersion,
    this.submissions = const <String, ChallengeRankingSubmission>{},
  });

  static const int currentSchemaVersion = 4;

  final int schemaVersion;
  final Map<String, ChallengeRankingSubmission> submissions;

  ChallengeRankingEnqueueDecision enqueue({
    required ChallengeDefinition challenge,
    required ChallengePerformance performance,
    int attemptNumber = 1,
    required DateTime completedAtUtc,
    required bool participationEnabled,
    String? officialSessionId,
  }) {
    final String? rankingGroupId = challenge.rankingGroupId;
    if (rankingGroupId == null) {
      return _reject(ChallengeRankingEnqueueOutcome.ignoredNotRanked);
    }
    if (!participationEnabled) {
      return _reject(ChallengeRankingEnqueueOutcome.ignoredOptedOut);
    }
    final double averageDistance =
        performance.averageDistanceKilometers ?? 0;
    if (attemptNumber <= 0 ||
        performance.score < 0 ||
        performance.correctAnswers < 0 ||
        averageDistance < 0 ||
        !averageDistance.isFinite ||
        performance.elapsedSeconds <= 0) {
      return _reject(
        ChallengeRankingEnqueueOutcome.rejectedInvalidPerformance,
      );
    }

    final String submissionId =
        'ranking:${challenge.rewardClaimId}:attempt:$attemptNumber';
    final ChallengeRankingSubmission? existing = submissions[submissionId];
    if (existing != null) {
      return ChallengeRankingEnqueueDecision(
        outcome: ChallengeRankingEnqueueOutcome.rejectedDuplicate,
        updatedLedger: this,
        submission: existing,
      );
    }
    final ChallengeRankingSubmission submission = ChallengeRankingSubmission(
      submissionId: submissionId,
      challengeId: challenge.id,
      rankingGroupId: rankingGroupId,
      attemptNumber: attemptNumber,
      competitiveSignature: challenge.competitiveSignature,
      completedAtUtc: completedAtUtc.toUtc(),
      score: performance.score,
      correctAnswers: performance.correctAnswers,
      averageDistanceKilometers: averageDistance,
      elapsedSeconds: performance.elapsedSeconds,
      status: ChallengeRankingSubmissionStatus.pendingServerValidation,
      officialSessionId: _normalizeOptionalText(officialSessionId),
      answerEvidence: List<ChallengeAnswerEvidence>.unmodifiable(
        performance.answerEvidence,
      ),
    );
    return ChallengeRankingEnqueueDecision(
      outcome: ChallengeRankingEnqueueOutcome.enqueued,
      updatedLedger: ChallengeRankingLedger(
        submissions: Map<String, ChallengeRankingSubmission>.unmodifiable(
          <String, ChallengeRankingSubmission>{
            ...submissions,
            submissionId: submission,
          },
        ),
      ),
      submission: submission,
    );
  }

  List<ChallengeRankingSubmission> get pendingSubmissions {
    return submissions.values
        .where((ChallengeRankingSubmission item) => item.isPending)
        .toList(growable: false);
  }

  ChallengeRankingSubmission? submissionForChallenge(String challengeId) {
    final String normalizedId = challengeId.trim();
    return ChallengeRankingRules.bestSubmission(
      submissions.values.where(
        (ChallengeRankingSubmission submission) =>
            submission.challengeId == normalizedId &&
            submission.status != ChallengeRankingSubmissionStatus.rejected,
      ),
    );
  }

  ChallengeRankingSubmission? bestConfirmedSubmissionForChallenge(
    String challengeId,
  ) {
    final String normalizedId = challengeId.trim();
    return ChallengeRankingRules.bestSubmission(
      submissions.values.where(
        (ChallengeRankingSubmission submission) =>
            submission.challengeId == normalizedId &&
            submission.status == ChallengeRankingSubmissionStatus.confirmed,
      ),
    );
  }

  ChallengeRankingLedger confirm(
    String submissionId, [
    ChallengeLeaderboardPosition? position,
  ]) {
    return _replace(
      submissionId,
      (ChallengeRankingSubmission item) => item.confirm(position),
    );
  }

  ChallengeRankingLedger quarantine(String submissionId, {String? reason}) {
    return _replace(
      submissionId,
      (ChallengeRankingSubmission item) => item.quarantine(reason: reason),
    );
  }

  ChallengeRankingLedger reject(String submissionId, {String? reason}) {
    return _replace(
      submissionId,
      (ChallengeRankingSubmission item) => item.reject(reason: reason),
    );
  }

  ChallengeRankingLedger _replace(
    String submissionId,
    ChallengeRankingSubmission Function(ChallengeRankingSubmission) update,
  ) {
    final String normalizedId = submissionId.trim();
    final ChallengeRankingSubmission? existing = submissions[normalizedId];
    if (existing == null || !existing.isPending) {
      return this;
    }
    final ChallengeRankingSubmission updated = update(existing);
    return ChallengeRankingLedger(
      submissions: Map<String, ChallengeRankingSubmission>.unmodifiable(
        <String, ChallengeRankingSubmission>{
          ...submissions,
          normalizedId: updated,
        },
      ),
    );
  }

  ChallengeRankingEnqueueDecision _reject(
    ChallengeRankingEnqueueOutcome outcome,
  ) {
    return ChallengeRankingEnqueueDecision(
      outcome: outcome,
      updatedLedger: this,
    );
  }

  factory ChallengeRankingLedger.fromJson(Map<String, dynamic> json) {
    final int storedSchemaVersion = _readPositiveInt(
      json['schemaVersion'],
      fallback: 1,
    );
    final Map<String, ChallengeRankingSubmission> submissions =
        <String, ChallengeRankingSubmission>{};
    final Object? rawSubmissions = json['submissions'];
    if (rawSubmissions is List) {
      for (final Object? rawSubmission in rawSubmissions) {
        final Map<String, dynamic>? submissionJson = _readOptionalMap(
          rawSubmission,
        );
        if (submissionJson == null) {
          continue;
        }
        ChallengeRankingSubmission submission =
            ChallengeRankingSubmission.fromJson(submissionJson);
        if (storedSchemaVersion < currentSchemaVersion &&
            submission.isPending &&
            (submission.officialSessionId == null ||
                submission.answerEvidence.isEmpty)) {
          submission = submission.reject(
            reason: 'Ancienne tentative non vérifiable par le serveur.',
          );
        }
        if (submission.submissionId.isNotEmpty &&
            submission.challengeId.isNotEmpty &&
            submission.rankingGroupId.isNotEmpty) {
          submissions[submission.submissionId] = submission;
        }
      }
    }
    return ChallengeRankingLedger(
      submissions: Map<String, ChallengeRankingSubmission>.unmodifiable(
        submissions,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final List<ChallengeRankingSubmission> sorted = submissions.values.toList()
      ..sort(
        (ChallengeRankingSubmission left, ChallengeRankingSubmission right) =>
            left.submissionId.compareTo(right.submissionId),
      );
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'submissions': sorted
          .map((ChallengeRankingSubmission item) => item.toJson())
          .toList(growable: false),
    };
  }
}

class ChallengeRankingRules {
  const ChallengeRankingRules._();

  /// Renvoie une valeur positive lorsque [candidate] est meilleure que
  /// [reference]. Le départage officiel est : score, précision, puis temps.
  static int compare(
    ChallengeRankingSubmission candidate,
    ChallengeRankingSubmission reference,
  ) {
    final int scoreComparison = candidate.score.compareTo(reference.score);
    if (scoreComparison != 0) {
      return scoreComparison;
    }
    final int distanceComparison = reference.averageDistanceKilometers
        .compareTo(candidate.averageDistanceKilometers);
    if (distanceComparison != 0) {
      return distanceComparison;
    }
    return reference.elapsedSeconds.compareTo(candidate.elapsedSeconds);
  }

  static bool isBetter(
    ChallengeRankingSubmission candidate,
    ChallengeRankingSubmission reference,
  ) {
    return compare(candidate, reference) > 0;
  }

  static ChallengeRankingSubmission? bestSubmission(
    Iterable<ChallengeRankingSubmission> submissions,
  ) {
    ChallengeRankingSubmission? best;
    for (final ChallengeRankingSubmission submission in submissions) {
      final ChallengeRankingSubmission? currentBest = best;
      if (currentBest == null || isBetter(submission, currentBest)) {
        best = submission;
      }
    }
    return best;
  }
}

Map<String, dynamic>? _readOptionalMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map<String, dynamic>(
    (dynamic key, dynamic item) =>
        MapEntry<String, dynamic>(key.toString(), item),
  );
}

List<ChallengeAnswerEvidence> _readAnswerEvidence(Object? value) {
  if (value is! List) {
    return const <ChallengeAnswerEvidence>[];
  }
  final List<ChallengeAnswerEvidence> evidence = <ChallengeAnswerEvidence>[];
  for (final Object? item in value) {
    final Map<String, dynamic>? json = _readOptionalMap(item);
    if (json == null) {
      continue;
    }
    evidence.add(ChallengeAnswerEvidence.fromJson(json));
  }
  return List<ChallengeAnswerEvidence>.unmodifiable(evidence);
}

String _readString(Object? value) {
  return value?.toString().trim() ?? '';
}

String? _normalizeOptionalText(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

int _readNonNegativeInt(Object? value) {
  final int parsed = value is int
      ? value
      : int.tryParse(value?.toString() ?? '') ?? 0;
  return parsed < 0 ? 0 : parsed;
}

int _readPositiveInt(Object? value, {required int fallback}) {
  final int parsed = value is int
      ? value
      : int.tryParse(value?.toString() ?? '') ?? fallback;
  return parsed <= 0 ? fallback : parsed;
}

double _readNonNegativeDouble(Object? value) {
  final double parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  return !parsed.isFinite || parsed < 0 ? 0 : parsed;
}

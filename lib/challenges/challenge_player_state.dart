import 'challenge_clock.dart';
import 'challenge_definition.dart';
import 'challenge_ranking.dart';
import 'challenge_wallet.dart';

class ChallengeAttemptProgress {
  const ChallengeAttemptProgress({
    required this.challengeId,
    this.attemptsUsed = 0,
    this.diamondRetriesUsed = 0,
    this.rewardedAdvertisementRetriesUsed = 0,
    this.bestScore = 0,
    this.bestCorrectAnswers = 0,
    this.completedAtUtc,
  });

  final String challengeId;
  final int attemptsUsed;
  final int diamondRetriesUsed;
  final int rewardedAdvertisementRetriesUsed;
  final int bestScore;
  final int bestCorrectAnswers;
  final DateTime? completedAtUtc;

  bool get isCompleted => completedAtUtc != null;

  ChallengeAttemptProgress registerAttempt({
    required int score,
    required int correctAnswers,
    required bool succeeded,
    required DateTime playedAt,
    bool usedDiamondRetry = false,
    bool usedRewardedAdvertisementRetry = false,
  }) {
    if (score < 0 || correctAnswers < 0) {
      throw ArgumentError('Le résultat du défi ne peut pas être négatif.');
    }
    if (usedDiamondRetry && usedRewardedAdvertisementRetry) {
      throw ArgumentError(
        'Une tentative ne peut utiliser qu’un seul type de relance.',
      );
    }

    return ChallengeAttemptProgress(
      challengeId: challengeId,
      attemptsUsed: attemptsUsed + 1,
      diamondRetriesUsed:
          diamondRetriesUsed + (usedDiamondRetry ? 1 : 0),
      rewardedAdvertisementRetriesUsed:
          rewardedAdvertisementRetriesUsed +
              (usedRewardedAdvertisementRetry ? 1 : 0),
      bestScore: score > bestScore ? score : bestScore,
      bestCorrectAnswers: correctAnswers > bestCorrectAnswers
          ? correctAnswers
          : bestCorrectAnswers,
      completedAtUtc: succeeded
          ? playedAt.toUtc()
          : completedAtUtc,
    );
  }

  bool canUseFreeAttempt(
    ChallengeRetryPolicy policy, {
    bool allowAfterCompletion = false,
  }) {
    return (allowAfterCompletion || !isCompleted) &&
        (policy.unlimitedFreeAttempts ||
            attemptsUsed < policy.maximumAttempts);
  }

  bool canUseDiamondRetry(
    ChallengeRetryPolicy policy, {
    bool allowAfterCompletion = false,
  }) {
    return (allowAfterCompletion || !isCompleted) &&
        policy.diamondRetryCost > 0 &&
        diamondRetriesUsed < policy.maximumDiamondRetries;
  }

  bool canUseRewardedAdvertisementRetry(
    ChallengeRetryPolicy policy, {
    bool allowAfterCompletion = false,
  }) {
    return (allowAfterCompletion || !isCompleted) &&
        policy.rewardedAdvertisementAllowed &&
        (policy.unlimitedRewardedAdvertisementRetries ||
            rewardedAdvertisementRetriesUsed <
                policy.maximumRewardedAdvertisementRetries);
  }

  factory ChallengeAttemptProgress.fromJson(Map<String, dynamic> json) {
    return ChallengeAttemptProgress(
      challengeId: _readString(json['challengeId']),
      attemptsUsed: _readNonNegativeInt(json['attemptsUsed']),
      diamondRetriesUsed: _readNonNegativeInt(json['diamondRetriesUsed']),
      rewardedAdvertisementRetriesUsed: _readNonNegativeInt(
        json['rewardedAdvertisementRetriesUsed'],
      ),
      bestScore: _readNonNegativeInt(json['bestScore']),
      bestCorrectAnswers: _readNonNegativeInt(json['bestCorrectAnswers']),
      completedAtUtc: _readOptionalDateTime(json['completedAtUtc']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'challengeId': challengeId,
      'attemptsUsed': attemptsUsed,
      'diamondRetriesUsed': diamondRetriesUsed,
      'rewardedAdvertisementRetriesUsed':
          rewardedAdvertisementRetriesUsed,
      'bestScore': bestScore,
      'bestCorrectAnswers': bestCorrectAnswers,
      if (completedAtUtc != null)
        'completedAtUtc': completedAtUtc!.toUtc().toIso8601String(),
    };
  }
}

enum ChallengeRewardClaimStatus {
  pendingServerValidation,
  confirmed,
  rejected,
}

extension ChallengeRewardClaimStatusRules on ChallengeRewardClaimStatus {
  String get id {
    switch (this) {
      case ChallengeRewardClaimStatus.pendingServerValidation:
        return 'pending_server_validation';
      case ChallengeRewardClaimStatus.confirmed:
        return 'confirmed';
      case ChallengeRewardClaimStatus.rejected:
        return 'rejected';
    }
  }
}

class ChallengeRewardClaimRecord {
  const ChallengeRewardClaimRecord({
    required this.claimId,
    required this.challengeId,
    required this.claimedAtUtc,
    required this.status,
    required this.reward,
    this.rejectionReason,
  });

  final String claimId;
  final String challengeId;
  final DateTime claimedAtUtc;
  final ChallengeRewardClaimStatus status;
  final ChallengeReward reward;
  final String? rejectionReason;

  bool get canDeliverReward {
    return status == ChallengeRewardClaimStatus.confirmed;
  }

  ChallengeRewardClaimRecord confirm({ChallengeReward? authoritativeReward}) {
    if (status == ChallengeRewardClaimStatus.confirmed) {
      return this;
    }
    return ChallengeRewardClaimRecord(
      claimId: claimId,
      challengeId: challengeId,
      claimedAtUtc: claimedAtUtc,
      status: ChallengeRewardClaimStatus.confirmed,
      reward: authoritativeReward ?? reward,
    );
  }

  ChallengeRewardClaimRecord reject({String? reason}) {
    if (status != ChallengeRewardClaimStatus.pendingServerValidation) {
      return this;
    }
    final String normalizedReason = reason?.trim() ?? '';
    return ChallengeRewardClaimRecord(
      claimId: claimId,
      challengeId: challengeId,
      claimedAtUtc: claimedAtUtc,
      status: ChallengeRewardClaimStatus.rejected,
      reward: reward,
      rejectionReason: normalizedReason.isEmpty ? null : normalizedReason,
    );
  }

  factory ChallengeRewardClaimRecord.fromJson(Map<String, dynamic> json) {
    final String statusId = _readString(json['status']);
    final ChallengeRewardClaimStatus status;
    switch (statusId) {
      case 'confirmed':
        status = ChallengeRewardClaimStatus.confirmed;
      case 'rejected':
        status = ChallengeRewardClaimStatus.rejected;
      default:
        status = ChallengeRewardClaimStatus.pendingServerValidation;
    }
    final Object? rawReward = json['reward'];
    final Map<String, dynamic> rewardJson = rawReward is Map
        ? rawReward.map<String, dynamic>(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          )
        : <String, dynamic>{};

    return ChallengeRewardClaimRecord(
      claimId: _readString(json['claimId']),
      challengeId: _readString(json['challengeId']),
      claimedAtUtc: _readOptionalDateTime(json['claimedAtUtc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: status,
      reward: ChallengeReward.fromJson(rewardJson),
      rejectionReason: _readOptionalString(json['rejectionReason']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'claimId': claimId,
      'challengeId': challengeId,
      'claimedAtUtc': claimedAtUtc.toUtc().toIso8601String(),
      'status': status.id,
      'reward': reward.toJson(),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }
}

enum ChallengeRewardClaimOutcome {
  accepted,
  rejectedDuplicate,
  rejectedIncomplete,
  rejectedExpired,
  rejectedClock,
}

class ChallengeRewardClaimDecision {
  const ChallengeRewardClaimDecision({
    required this.outcome,
    required this.updatedLedger,
    this.record,
  });

  final ChallengeRewardClaimOutcome outcome;
  final ChallengeRewardLedger updatedLedger;
  final ChallengeRewardClaimRecord? record;

  bool get wasAccepted => outcome == ChallengeRewardClaimOutcome.accepted;

  /// Une récompense hors ligne reste en attente : elle ne doit pas encore
  /// être ajoutée au profil, au porte-monnaie ou au Passeport.
  bool get canDeliverReward {
    return wasAccepted && record?.canDeliverReward == true;
  }
}

class ChallengeRewardLedger {
  const ChallengeRewardLedger({
    this.schemaVersion = currentSchemaVersion,
    this.claims = const <String, ChallengeRewardClaimRecord>{},
  });

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final Map<String, ChallengeRewardClaimRecord> claims;

  bool containsClaim(String claimId) {
    return claims.containsKey(claimId.trim());
  }

  ChallengeRewardClaimDecision claim({
    required ChallengeDefinition challenge,
    required bool completedSuccessfully,
    required ChallengeClockEvaluation clock,
  }) {
    final String claimId = challenge.rewardClaimId;
    if (!completedSuccessfully) {
      return _reject(ChallengeRewardClaimOutcome.rejectedIncomplete);
    }
    if (!clock.canClaimReward) {
      return _reject(ChallengeRewardClaimOutcome.rejectedClock);
    }
    if (!challenge.isActiveAt(clock.effectiveNowUtc)) {
      return _reject(ChallengeRewardClaimOutcome.rejectedExpired);
    }
    if (containsClaim(claimId)) {
      return _reject(ChallengeRewardClaimOutcome.rejectedDuplicate);
    }

    final ChallengeRewardClaimRecord record = ChallengeRewardClaimRecord(
      claimId: claimId,
      challengeId: challenge.id,
      claimedAtUtc: clock.effectiveNowUtc,
      status: ChallengeRewardClaimStatus.pendingServerValidation,
      reward: challenge.reward,
    );
    final Map<String, ChallengeRewardClaimRecord> updated =
        <String, ChallengeRewardClaimRecord>{...claims, claimId: record};
    return ChallengeRewardClaimDecision(
      outcome: ChallengeRewardClaimOutcome.accepted,
      updatedLedger: ChallengeRewardLedger(
        claims: Map<String, ChallengeRewardClaimRecord>.unmodifiable(updated),
      ),
      record: record,
    );
  }

  ChallengeRewardLedger confirm(
    String claimId, {
    ChallengeReward? authoritativeReward,
  }) {
    final String normalizedId = claimId.trim();
    final ChallengeRewardClaimRecord? existing = claims[normalizedId];
    if (existing == null ||
        existing.status !=
            ChallengeRewardClaimStatus.pendingServerValidation) {
      return this;
    }
    final Map<String, ChallengeRewardClaimRecord> updated =
        <String, ChallengeRewardClaimRecord>{
      ...claims,
      normalizedId: existing.confirm(
        authoritativeReward: authoritativeReward,
      ),
    };
    return ChallengeRewardLedger(
      claims: Map<String, ChallengeRewardClaimRecord>.unmodifiable(updated),
    );
  }

  ChallengeRewardLedger reject(String claimId, {String? reason}) {
    final String normalizedId = claimId.trim();
    final ChallengeRewardClaimRecord? existing = claims[normalizedId];
    if (existing == null ||
        existing.status !=
            ChallengeRewardClaimStatus.pendingServerValidation) {
      return this;
    }
    final Map<String, ChallengeRewardClaimRecord> updated =
        <String, ChallengeRewardClaimRecord>{
      ...claims,
      normalizedId: existing.reject(reason: reason),
    };
    return ChallengeRewardLedger(
      claims: Map<String, ChallengeRewardClaimRecord>.unmodifiable(updated),
    );
  }

  List<ChallengeRewardClaimRecord> get pendingClaims {
    return claims.values
        .where(
          (ChallengeRewardClaimRecord claim) =>
              claim.status ==
              ChallengeRewardClaimStatus.pendingServerValidation,
        )
        .toList(growable: false);
  }

  ChallengeRewardClaimDecision _reject(ChallengeRewardClaimOutcome outcome) {
    return ChallengeRewardClaimDecision(
      outcome: outcome,
      updatedLedger: this,
    );
  }

  factory ChallengeRewardLedger.fromJson(Map<String, dynamic> json) {
    final Map<String, ChallengeRewardClaimRecord> claims =
        <String, ChallengeRewardClaimRecord>{};
    final Object? rawClaims = json['claims'];
    if (rawClaims is List) {
      for (final Object? rawClaim in rawClaims) {
        if (rawClaim is! Map) {
          continue;
        }
        final ChallengeRewardClaimRecord claim =
            ChallengeRewardClaimRecord.fromJson(
          rawClaim.map<String, dynamic>(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          ),
        );
        if (claim.claimId.isNotEmpty && claim.challengeId.isNotEmpty) {
          claims[claim.claimId] = claim;
        }
      }
    }
    return ChallengeRewardLedger(
      claims: Map<String, ChallengeRewardClaimRecord>.unmodifiable(claims),
    );
  }

  Map<String, dynamic> toJson() {
    final List<ChallengeRewardClaimRecord> sortedClaims = claims.values.toList()
      ..sort(
        (ChallengeRewardClaimRecord left, ChallengeRewardClaimRecord right) =>
            left.claimId.compareTo(right.claimId),
      );
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'claims': sortedClaims
          .map((ChallengeRewardClaimRecord claim) => claim.toJson())
          .toList(growable: false),
    };
  }
}

class ChallengePlayerState {
  const ChallengePlayerState({
    this.schemaVersion = currentSchemaVersion,
    this.attempts = const <String, ChallengeAttemptProgress>{},
    this.rewardLedger = const ChallengeRewardLedger(),
    this.wallet = const ChallengeWallet(),
    this.clockState = const ChallengeClockState(),
    this.rankingLedger = const ChallengeRankingLedger(),
    this.rankingParticipationEnabled = false,
  });

  static const int currentSchemaVersion = 4;

  final int schemaVersion;
  final Map<String, ChallengeAttemptProgress> attempts;
  final ChallengeRewardLedger rewardLedger;
  final ChallengeWallet wallet;
  final ChallengeClockState clockState;
  final ChallengeRankingLedger rankingLedger;
  final bool rankingParticipationEnabled;

  factory ChallengePlayerState.initial() {
    return const ChallengePlayerState();
  }

  ChallengeAttemptProgress progressFor(String challengeId) {
    final String normalizedId = challengeId.trim();
    return attempts[normalizedId] ??
        ChallengeAttemptProgress(challengeId: normalizedId);
  }

  ChallengePlayerState registerAttempt({
    required String challengeId,
    required int score,
    required int correctAnswers,
    required bool succeeded,
    required DateTime playedAt,
    bool usedDiamondRetry = false,
    bool usedRewardedAdvertisementRetry = false,
  }) {
    final String normalizedId = challengeId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('L’identifiant du défi est obligatoire.');
    }
    final ChallengeAttemptProgress updated = progressFor(normalizedId)
        .registerAttempt(
          score: score,
          correctAnswers: correctAnswers,
          succeeded: succeeded,
          playedAt: playedAt,
          usedDiamondRetry: usedDiamondRetry,
          usedRewardedAdvertisementRetry:
              usedRewardedAdvertisementRetry,
        );
    return copyWith(
      attempts: Map<String, ChallengeAttemptProgress>.unmodifiable(
        <String, ChallengeAttemptProgress>{
          ...attempts,
          normalizedId: updated,
        },
      ),
    );
  }

  ChallengePlayerState deliverConfirmedRewards() {
    ChallengeWallet updatedWallet = wallet;
    for (final ChallengeRewardClaimRecord claim in rewardLedger.claims.values) {
      if (!claim.canDeliverReward) {
        continue;
      }
      updatedWallet = updatedWallet
          .deliver(
            claimId: claim.claimId,
            confirmed: true,
            reward: claim.reward,
          )
          .updatedWallet;
    }
    return identical(updatedWallet, wallet)
        ? this
        : copyWith(wallet: updatedWallet);
  }

  ChallengePlayerState copyWith({
    Map<String, ChallengeAttemptProgress>? attempts,
    ChallengeRewardLedger? rewardLedger,
    ChallengeWallet? wallet,
    ChallengeClockState? clockState,
    ChallengeRankingLedger? rankingLedger,
    bool? rankingParticipationEnabled,
  }) {
    return ChallengePlayerState(
      attempts: attempts ?? this.attempts,
      rewardLedger: rewardLedger ?? this.rewardLedger,
      wallet: wallet ?? this.wallet,
      clockState: clockState ?? this.clockState,
      rankingLedger: rankingLedger ?? this.rankingLedger,
      rankingParticipationEnabled:
          rankingParticipationEnabled ?? this.rankingParticipationEnabled,
    );
  }

  factory ChallengePlayerState.fromJson(Map<String, dynamic> json) {
    final Map<String, ChallengeAttemptProgress> attempts =
        <String, ChallengeAttemptProgress>{};
    final Object? rawAttempts = json['attempts'];
    if (rawAttempts is List) {
      for (final Object? rawAttempt in rawAttempts) {
        if (rawAttempt is! Map) {
          continue;
        }
        final ChallengeAttemptProgress progress =
            ChallengeAttemptProgress.fromJson(
          rawAttempt.map<String, dynamic>(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          ),
        );
        if (progress.challengeId.isNotEmpty) {
          attempts[progress.challengeId] = progress;
        }
      }
    }

    return ChallengePlayerState(
      attempts: Map<String, ChallengeAttemptProgress>.unmodifiable(attempts),
      rewardLedger: ChallengeRewardLedger.fromJson(
        _readMap(json['rewardLedger']),
      ),
      wallet: ChallengeWallet.fromJson(_readMap(json['wallet'])),
      clockState: ChallengeClockState.fromJson(
        _readMap(json['clockState']),
      ),
      rankingLedger: ChallengeRankingLedger.fromJson(
        _readMap(json['rankingLedger']),
      ),
      rankingParticipationEnabled:
          json['rankingParticipationEnabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    final List<ChallengeAttemptProgress> sortedAttempts =
        attempts.values.toList()
          ..sort(
            (ChallengeAttemptProgress left, ChallengeAttemptProgress right) =>
                left.challengeId.compareTo(right.challengeId),
          );
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'attempts': sortedAttempts
          .map((ChallengeAttemptProgress progress) => progress.toJson())
          .toList(growable: false),
      'rewardLedger': rewardLedger.toJson(),
      'wallet': wallet.toJson(),
      'clockState': clockState.toJson(),
      'rankingLedger': rankingLedger.toJson(),
      'rankingParticipationEnabled': rankingParticipationEnabled,
    };
  }
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is! Map) {
    return <String, dynamic>{};
  }
  return value.map<String, dynamic>(
    (dynamic key, dynamic item) =>
        MapEntry<String, dynamic>(key.toString(), item),
  );
}

String _readString(Object? value) {
  return value?.toString().trim() ?? '';
}

String? _readOptionalString(Object? value) {
  final String result = _readString(value);
  return result.isEmpty ? null : result;
}

int _readNonNegativeInt(Object? value) {
  final int result = value is int
      ? value
      : int.tryParse(value?.toString() ?? '') ?? 0;
  return result < 0 ? 0 : result;
}

DateTime? _readOptionalDateTime(Object? value) {
  final String source = value?.toString().trim() ?? '';
  if (source.isEmpty) {
    return null;
  }
  return DateTime.tryParse(source)?.toUtc();
}

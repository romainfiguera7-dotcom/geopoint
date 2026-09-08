import 'challenge_clock.dart';
import 'challenge_definition.dart';
import 'challenge_player_state.dart';
import 'challenge_storage.dart';
import 'challenge_wallet.dart';

enum ChallengeRewardValidationDecision {
  confirmed,
  pending,
  rejected,
}

extension ChallengeRewardValidationDecisionRules
    on ChallengeRewardValidationDecision {
  String get id {
    switch (this) {
      case ChallengeRewardValidationDecision.confirmed:
        return 'confirmed';
      case ChallengeRewardValidationDecision.pending:
        return 'pending';
      case ChallengeRewardValidationDecision.rejected:
        return 'rejected';
    }
  }
}

class ChallengeRewardValidationRequest {
  const ChallengeRewardValidationRequest({
    required this.claimId,
    required this.challengeId,
    required this.claimedAtUtc,
    required this.attemptsUsed,
    required this.rewardedAdvertisementRetriesUsed,
    required this.bestScore,
    required this.bestCorrectAnswers,
    required this.rewardSnapshot,
  });

  final String claimId;
  final String challengeId;
  final DateTime claimedAtUtc;
  final int attemptsUsed;
  final int rewardedAdvertisementRetriesUsed;
  final int bestScore;
  final int bestCorrectAnswers;

  /// Copie informative de la récompense attendue. Le serveur doit toujours
  /// utiliser son propre pack publié comme source de vérité.
  final ChallengeReward rewardSnapshot;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'claimId': claimId,
      'challengeId': challengeId,
      'claimedAtUtc': claimedAtUtc.toUtc().toIso8601String(),
      'attemptsUsed': attemptsUsed,
      'rewardedAdvertisementRetriesUsed':
          rewardedAdvertisementRetriesUsed,
      'bestScore': bestScore,
      'bestCorrectAnswers': bestCorrectAnswers,
      'rewardSnapshot': rewardSnapshot.toJson(),
    };
  }
}

class ChallengeRewardValidationResult {
  const ChallengeRewardValidationResult({
    required this.claimId,
    required this.decision,
    this.confirmedReward,
    this.rejectionReason,
  });

  final String claimId;
  final ChallengeRewardValidationDecision decision;

  /// Récompense autoritaire renvoyée par le serveur. Elle remplace la copie
  /// locale afin qu’une sauvegarde modifiée ne puisse pas imposer son montant.
  final ChallengeReward? confirmedReward;
  final String? rejectionReason;
}

class ChallengeRewardValidationResponse {
  const ChallengeRewardValidationResponse({
    required this.serverNowUtc,
    required this.results,
    this.authoritativeWallet,
  });

  final DateTime serverNowUtc;
  final List<ChallengeRewardValidationResult> results;
  final ChallengeWallet? authoritativeWallet;
}

abstract interface class ChallengeRewardValidationGateway {
  Future<ChallengeRewardValidationResponse> validatePendingRewards(
    List<ChallengeRewardValidationRequest> requests,
  );
}

enum ChallengeRewardSyncStatus {
  upToDate,
  synchronized,
  awaitingValidation,
  partiallyRejected,
  pendingConnection,
  serverUnavailable,
  invalidServerResponse,
  storageFailure,
}

class ChallengeRewardSyncReport {
  const ChallengeRewardSyncReport({
    required this.status,
    required this.playerState,
    required this.clock,
    required this.pendingBefore,
    required this.pendingAfter,
    this.confirmedCount = 0,
    this.rejectedCount = 0,
    this.failureReason,
  });

  final ChallengeRewardSyncStatus status;
  final ChallengePlayerState playerState;
  final ChallengeClockEvaluation clock;
  final int pendingBefore;
  final int pendingAfter;
  final int confirmedCount;
  final int rejectedCount;
  final String? failureReason;

  bool get contactedServer {
    return status == ChallengeRewardSyncStatus.synchronized ||
        status == ChallengeRewardSyncStatus.awaitingValidation ||
        status == ChallengeRewardSyncStatus.partiallyRejected;
  }
}

class ChallengeRewardSyncService {
  const ChallengeRewardSyncService._();

  static Future<ChallengeRewardSyncReport> synchronize({
    required ChallengePlayerState playerState,
    required DateTime deviceNow,
    DateTime? trustedServerNow,
    ChallengeRewardValidationGateway? gateway,
  }) async {
    ChallengeClockEvaluation clock = ChallengeClock.evaluate(
      deviceNow: deviceNow,
      serverNow: trustedServerNow,
      previousState: playerState.clockState,
    );
    ChallengePlayerState baseline = playerState
        .copyWith(clockState: clock.updatedState)
        .deliverConfirmedRewards();
    final List<ChallengeRewardClaimRecord> pending =
        baseline.rewardLedger.pendingClaims;

    if (pending.isEmpty && gateway == null) {
      return _saveReport(
        originalState: playerState,
        updatedState: baseline,
        clock: clock,
        status: ChallengeRewardSyncStatus.upToDate,
        pendingBefore: 0,
        pendingAfter: 0,
      );
    }

    if (gateway == null) {
      return _saveReport(
        originalState: playerState,
        updatedState: baseline,
        clock: clock,
        status: ChallengeRewardSyncStatus.pendingConnection,
        pendingBefore: pending.length,
        pendingAfter: pending.length,
      );
    }

    final List<ChallengeRewardValidationRequest> requests = pending
        .map(
          (ChallengeRewardClaimRecord claim) => _requestFor(
            claim,
            baseline.progressFor(claim.challengeId),
          ),
        )
        .toList(growable: false);

    final ChallengeRewardValidationResponse response;
    try {
      response = await gateway.validatePendingRewards(requests);
      _validateResponse(response, pending);
    } catch (error) {
      return _saveReport(
        originalState: playerState,
        updatedState: baseline,
        clock: clock,
        status: error is FormatException
            ? ChallengeRewardSyncStatus.invalidServerResponse
            : ChallengeRewardSyncStatus.serverUnavailable,
        pendingBefore: pending.length,
        pendingAfter: pending.length,
        failureReason: error.toString(),
      );
    }

    clock = ChallengeClock.evaluate(
      deviceNow: deviceNow,
      serverNow: response.serverNowUtc,
      previousState: baseline.clockState,
    );
    ChallengeRewardLedger ledger = baseline.rewardLedger;
    int confirmedCount = 0;
    int rejectedCount = 0;
    int stillPendingCount = 0;
    for (final ChallengeRewardValidationResult result in response.results) {
      switch (result.decision) {
        case ChallengeRewardValidationDecision.confirmed:
          ledger = ledger.confirm(
            result.claimId,
            authoritativeReward: result.confirmedReward,
          );
          confirmedCount += 1;
        case ChallengeRewardValidationDecision.pending:
          stillPendingCount += 1;
        case ChallengeRewardValidationDecision.rejected:
          ledger = ledger.reject(
            result.claimId,
            reason: result.rejectionReason,
          );
          rejectedCount += 1;
      }
    }

    final ChallengePlayerState synchronizedBase = baseline.copyWith(
      rewardLedger: ledger,
      clockState: clock.updatedState,
      wallet: response.authoritativeWallet,
    );
    final ChallengePlayerState synchronized =
        response.authoritativeWallet == null
            ? synchronizedBase.deliverConfirmedRewards()
            : synchronizedBase;
    return _saveReport(
      originalState: playerState,
      updatedState: synchronized,
      clock: clock,
      status: rejectedCount > 0
          ? ChallengeRewardSyncStatus.partiallyRejected
          : stillPendingCount > 0
              ? ChallengeRewardSyncStatus.awaitingValidation
              : confirmedCount > 0
                  ? ChallengeRewardSyncStatus.synchronized
                  : ChallengeRewardSyncStatus.upToDate,
      pendingBefore: pending.length,
      pendingAfter: synchronized.rewardLedger.pendingClaims.length,
      confirmedCount: confirmedCount,
      rejectedCount: rejectedCount,
    );
  }

  static ChallengeRewardValidationRequest _requestFor(
    ChallengeRewardClaimRecord claim,
    ChallengeAttemptProgress progress,
  ) {
    return ChallengeRewardValidationRequest(
      claimId: claim.claimId,
      challengeId: claim.challengeId,
      claimedAtUtc: claim.claimedAtUtc,
      attemptsUsed: progress.attemptsUsed,
      rewardedAdvertisementRetriesUsed:
          progress.rewardedAdvertisementRetriesUsed,
      bestScore: progress.bestScore,
      bestCorrectAnswers: progress.bestCorrectAnswers,
      rewardSnapshot: claim.reward,
    );
  }

  static void _validateResponse(
    ChallengeRewardValidationResponse response,
    List<ChallengeRewardClaimRecord> pending,
  ) {
    final Set<String> expected = pending
        .map((ChallengeRewardClaimRecord claim) => claim.claimId)
        .toSet();
    final Set<String> received = <String>{};
    for (final ChallengeRewardValidationResult result in response.results) {
      final String claimId = result.claimId.trim();
      if (!expected.contains(claimId)) {
        throw FormatException(
          'Le serveur a répondu pour une récompense inconnue : $claimId.',
        );
      }
      if (!received.add(claimId)) {
        throw FormatException(
          'Le serveur a répondu deux fois pour la récompense $claimId.',
        );
      }
      if (result.decision == ChallengeRewardValidationDecision.confirmed &&
          result.confirmedReward == null) {
        throw FormatException(
          'Le serveur n’a pas fourni la récompense confirmée pour $claimId.',
        );
      }
      if (result.decision == ChallengeRewardValidationDecision.rejected &&
          result.confirmedReward != null) {
        throw FormatException(
          'Le serveur a fourni un gain pour une récompense refusée : $claimId.',
        );
      }
      if (result.decision == ChallengeRewardValidationDecision.pending &&
          result.confirmedReward != null) {
        throw FormatException(
          'Le serveur a fourni un gain pour une validation encore en attente : '
          '$claimId.',
        );
      }
      if (result.confirmedReward != null &&
          !_isValidReward(result.confirmedReward!)) {
        throw FormatException(
          'Le serveur a fourni une récompense incorrecte pour $claimId.',
        );
      }
    }
    if (received.length != expected.length) {
      throw const FormatException(
        'La réponse du serveur ne couvre pas toutes les récompenses en attente.',
      );
    }
  }

  static bool _isValidReward(ChallengeReward reward) {
    final String? stampId = reward.stampId;
    final String? emblemId = reward.emblemId;
    return reward.xp >= 0 &&
        reward.coins >= 0 &&
        reward.diamonds >= 0 &&
        reward.progressionPoints >= 0 &&
        reward.cosmeticIds.every((String id) => id.trim().isNotEmpty) &&
        (stampId == null || stampId.trim().isNotEmpty) &&
        (emblemId == null || emblemId.trim().isNotEmpty);
  }

  static Future<ChallengeRewardSyncReport> _saveReport({
    required ChallengePlayerState originalState,
    required ChallengePlayerState updatedState,
    required ChallengeClockEvaluation clock,
    required ChallengeRewardSyncStatus status,
    required int pendingBefore,
    required int pendingAfter,
    int confirmedCount = 0,
    int rejectedCount = 0,
    String? failureReason,
  }) async {
    final bool saved = await ChallengeStorage.save(updatedState);
    if (!saved) {
      return ChallengeRewardSyncReport(
        status: ChallengeRewardSyncStatus.storageFailure,
        playerState: originalState,
        clock: clock,
        pendingBefore: pendingBefore,
        pendingAfter: pendingBefore,
        failureReason: 'La synchronisation n’a pas pu être sauvegardée.',
      );
    }
    return ChallengeRewardSyncReport(
      status: status,
      playerState: updatedState,
      clock: clock,
      pendingBefore: pendingBefore,
      pendingAfter: pendingAfter,
      confirmedCount: confirmedCount,
      rejectedCount: rejectedCount,
      failureReason: failureReason,
    );
  }
}

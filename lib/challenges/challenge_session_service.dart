import '../player/player_online_identity.dart';
import 'challenge_clock.dart';
import 'challenge_definition.dart';
import 'challenge_player_state.dart';
import 'challenge_ranking.dart';
import 'challenge_result.dart';
import 'challenge_ranking_sync.dart';
import 'challenge_reward_sync.dart';
import 'challenge_server_connection.dart';
import 'challenge_storage.dart';
import 'challenge_wallet.dart';

class ChallengeSessionOutcome {
  const ChallengeSessionOutcome({
    required this.performance,
    required this.evaluation,
    required this.playerState,
    required this.clock,
    required this.saved,
    this.rewardClaim,
    this.rewardDelivery,
    this.rankingEnqueue,
    this.rankingSync,
    this.rewardSync,
  });

  final ChallengePerformance performance;
  final ChallengeResultEvaluation evaluation;
  final ChallengePlayerState playerState;
  final ChallengeClockEvaluation clock;
  final ChallengeRewardClaimDecision? rewardClaim;
  final ChallengeRewardDeliveryDecision? rewardDelivery;
  final ChallengeRankingEnqueueDecision? rankingEnqueue;
  final ChallengeRankingSyncReport? rankingSync;
  final ChallengeRewardSyncReport? rewardSync;
  final bool saved;

  bool get succeeded => evaluation.succeeded;

  bool get rewardIsPending {
    final String? claimId = rewardClaim?.record?.claimId;
    if (claimId == null) return false;
    return playerState.rewardLedger.claims[claimId]?.status ==
        ChallengeRewardClaimStatus.pendingServerValidation;
  }

  bool get rewardWasAccepted => rewardClaim?.wasAccepted == true;

  bool get rewardCanBeDelivered {
    final String? claimId = rewardClaim?.record?.claimId;
    return saved &&
        claimId != null &&
        playerState.wallet.hasDelivered(claimId);
  }

  bool get rewardWasDelivered => rewardCanBeDelivered;

  ChallengeReward? get deliveredReward {
    final String? claimId = rewardClaim?.record?.claimId;
    if (claimId == null || !playerState.wallet.hasDelivered(claimId)) {
      return rewardDelivery?.reward;
    }
    return playerState.rewardLedger.claims[claimId]?.reward ??
        rewardDelivery?.reward;
  }

  bool get rankingAttemptIsBest {
    final ChallengeRankingSubmission? submission = rankingEnqueue?.submission;
    if (submission == null || rankingEnqueue?.wasEnqueued != true) {
      return false;
    }
    return playerState.rankingLedger
            .submissionForChallenge(submission.challengeId)
            ?.submissionId ==
        submission.submissionId;
  }
}

class ChallengeSessionService {
  const ChallengeSessionService._();

  static Future<ChallengeSessionOutcome> complete({
    required ChallengeDefinition challenge,
    required ChallengePerformance performance,
    required bool usedRewardedAdvertisementRetry,
    bool participateInRanking = false,
    String? officialSessionId,
    DateTime? deviceNow,
    DateTime? serverNow,
    ChallengeRankingGateway? rankingGateway,
    ChallengeRewardValidationGateway? rewardValidationGateway,
    PlayerOnlineIdentity? playerIdentity,
  }) async {
    final ChallengeResultEvaluation evaluation =
        ChallengeResultEvaluator.evaluate(
      challenge: challenge,
      performance: performance,
    );
    final ChallengePlayerState previous =
        await ChallengeStorage.load() ?? ChallengePlayerState.initial();
    final ChallengeClockEvaluation clock = ChallengeClock.evaluate(
      deviceNow: deviceNow ?? DateTime.now(),
      serverNow: serverNow,
      previousState: previous.clockState,
    );
    ChallengePlayerState updated = previous.registerAttempt(
      challengeId: challenge.id,
      score: performance.score,
      correctAnswers: performance.correctAnswers,
      succeeded: evaluation.succeeded,
      playedAt: clock.effectiveNowUtc,
      usedRewardedAdvertisementRetry:
          usedRewardedAdvertisementRetry,
    ).copyWith(clockState: clock.updatedState);

    ChallengeRewardClaimDecision? claim;
    ChallengeRewardDeliveryDecision? delivery;
    ChallengeRankingEnqueueDecision? rankingEnqueue;
    if (evaluation.succeeded) {
      claim = updated.rewardLedger.claim(
        challenge: challenge,
        completedSuccessfully: true,
        clock: clock,
      );
      updated = updated.copyWith(rewardLedger: claim.updatedLedger);
      final ChallengeRewardClaimRecord? record = claim.record;
      if (record != null && record.canDeliverReward) {
        delivery = updated.wallet.deliver(
          claimId: record.claimId,
          confirmed: true,
          reward: record.reward,
        );
        updated = updated.copyWith(wallet: delivery.updatedWallet);
      }
    }
    if (challenge.isRanked) {
      final ChallengeAttemptProgress progress =
          updated.progressFor(challenge.id);
      rankingEnqueue = updated.rankingLedger.enqueue(
        challenge: challenge,
        performance: performance,
        attemptNumber: progress.attemptsUsed,
        completedAtUtc: clock.effectiveNowUtc,
        participationEnabled: participateInRanking,
        officialSessionId: officialSessionId,
      );
      updated = updated.copyWith(
        rankingLedger: rankingEnqueue.updatedLedger,
        rankingParticipationEnabled: participateInRanking,
      );
    }

    final bool saved = await ChallengeStorage.save(updated);
    ChallengeRankingSyncReport? rankingSync;
    if (saved && rankingEnqueue?.wasEnqueued == true) {
      rankingSync = await ChallengeRankingSyncService.synchronize(
        playerState: updated,
        clock: clock,
        deviceNow: deviceNow ?? DateTime.now(),
        gateway: rankingGateway,
        playerIdentity: playerIdentity,
      );
      updated = rankingSync.playerState;
    }
    ChallengeRewardSyncReport? rewardSync;
    if (saved && claim?.wasAccepted == true) {
      rewardSync = await ChallengeRewardSyncService.synchronize(
        playerState: updated,
        deviceNow: deviceNow ?? DateTime.now(),
        trustedServerNow: rankingSync?.clock.effectiveNowUtc,
        gateway: rewardValidationGateway ??
            ChallengeServerConnection.rewardValidationGateway,
      );
      updated = rewardSync.playerState;
    }
    return ChallengeSessionOutcome(
      performance: performance,
      evaluation: evaluation,
      playerState: updated,
      clock: rewardSync?.clock ?? rankingSync?.clock ?? clock,
      rewardClaim: claim,
      rewardDelivery: delivery,
      rankingEnqueue: rankingEnqueue,
      rankingSync: rankingSync,
      rewardSync: rewardSync,
      saved: saved,
    );
  }
}

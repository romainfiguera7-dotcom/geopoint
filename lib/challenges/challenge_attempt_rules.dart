import 'challenge_definition.dart';
import 'challenge_player_state.dart';

enum ChallengeAttemptKind {
  free,
  diamondRetry,
  rewardedAdvertisementRetry,
}

enum ChallengeAttemptAuthorization {
  allowed,
  rejectedCompleted,
  rejectedAttemptsExhausted,
  rejectedFreeAttemptsRemaining,
  rejectedInsufficientDiamonds,
  rejectedAdvertisementsDisabled,
  rejectedChildAdvertisement,
}

class ChallengeAttemptDecision {
  const ChallengeAttemptDecision({
    required this.authorization,
    required this.kind,
    this.diamondCost = 0,
  });

  final ChallengeAttemptAuthorization authorization;
  final ChallengeAttemptKind kind;
  final int diamondCost;

  bool get isAllowed => authorization == ChallengeAttemptAuthorization.allowed;
}

class ChallengeAttemptRules {
  const ChallengeAttemptRules._();

  static ChallengeAttemptDecision authorize({
    required ChallengeDefinition challenge,
    required ChallengeAttemptProgress progress,
    required ChallengeAttemptKind kind,
    required int availableDiamonds,
    required bool isChildProfile,
  }) {
    final bool allowAfterCompletion = challenge.isRanked;
    if (progress.isCompleted && !allowAfterCompletion) {
      return ChallengeAttemptDecision(
        authorization: ChallengeAttemptAuthorization.rejectedCompleted,
        kind: kind,
      );
    }

    final ChallengeRetryPolicy policy = challenge.retryPolicy;
    switch (kind) {
      case ChallengeAttemptKind.free:
        return ChallengeAttemptDecision(
          authorization: progress.canUseFreeAttempt(
            policy,
            allowAfterCompletion: allowAfterCompletion,
          )
              ? ChallengeAttemptAuthorization.allowed
              : ChallengeAttemptAuthorization.rejectedAttemptsExhausted,
          kind: kind,
        );
      case ChallengeAttemptKind.diamondRetry:
        if (progress.canUseFreeAttempt(
          policy,
          allowAfterCompletion: allowAfterCompletion,
        )) {
          return ChallengeAttemptDecision(
            authorization:
                ChallengeAttemptAuthorization.rejectedFreeAttemptsRemaining,
            kind: kind,
          );
        }
        if (!progress.canUseDiamondRetry(
          policy,
          allowAfterCompletion: allowAfterCompletion,
        )) {
          return ChallengeAttemptDecision(
            authorization: ChallengeAttemptAuthorization.rejectedAttemptsExhausted,
            kind: kind,
          );
        }
        if (availableDiamonds < policy.diamondRetryCost) {
          return ChallengeAttemptDecision(
            authorization: ChallengeAttemptAuthorization.rejectedInsufficientDiamonds,
            kind: kind,
            diamondCost: policy.diamondRetryCost,
          );
        }
        return ChallengeAttemptDecision(
          authorization: ChallengeAttemptAuthorization.allowed,
          kind: kind,
          diamondCost: policy.diamondRetryCost,
        );
      case ChallengeAttemptKind.rewardedAdvertisementRetry:
        if (isChildProfile || challenge.audience == ChallengeAudience.child) {
          return ChallengeAttemptDecision(
            authorization: ChallengeAttemptAuthorization.rejectedChildAdvertisement,
            kind: kind,
          );
        }
        if (progress.canUseFreeAttempt(
          policy,
          allowAfterCompletion: allowAfterCompletion,
        )) {
          return ChallengeAttemptDecision(
            authorization:
                ChallengeAttemptAuthorization.rejectedFreeAttemptsRemaining,
            kind: kind,
          );
        }
        if (!progress.canUseRewardedAdvertisementRetry(
          policy,
          allowAfterCompletion: allowAfterCompletion,
        )) {
          return ChallengeAttemptDecision(
            authorization: policy.rewardedAdvertisementAllowed
                ? ChallengeAttemptAuthorization.rejectedAttemptsExhausted
                : ChallengeAttemptAuthorization.rejectedAdvertisementsDisabled,
            kind: kind,
          );
        }
        return ChallengeAttemptDecision(
          authorization: ChallengeAttemptAuthorization.allowed,
          kind: kind,
        );
    }
  }
}

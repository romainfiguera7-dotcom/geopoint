import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_attempt_rules.dart';
import 'package:geopoint/challenges/challenge_clock.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_player_state.dart';
import 'package:geopoint/challenges/challenge_result.dart';

import 'challenge_test_factory.dart';

void main() {
  final DateTime activeTime = DateTime.utc(2026, 9, 4, 12);

  test('les trois conditions de réussite sont toutes obligatoires', () {
    final ChallengeDefinition challenge = challengeFixture(
      successCondition: const ChallengeSuccessCondition(
        minimumCorrectAnswers: 4,
        minimumScore: 300,
        maximumAverageDistanceKilometers: 200,
      ),
    );
    final ChallengeResultEvaluation success =
        ChallengeResultEvaluator.evaluate(
      challenge: challenge,
      performance: const ChallengePerformance(
        score: 350,
        correctAnswers: 4,
        averageDistanceKilometers: 180,
      ),
    );
    final ChallengeResultEvaluation tooFar =
        ChallengeResultEvaluator.evaluate(
      challenge: challenge,
      performance: const ChallengePerformance(
        score: 350,
        correctAnswers: 4,
        averageDistanceKilometers: 250,
      ),
    );

    expect(success.succeeded, isTrue);
    expect(tooFar.succeeded, isFalse);
    expect(tooFar.distanceReached, isFalse);
  });

  test('la première tentative gratuite est autorisée', () {
    final ChallengeAttemptDecision decision = ChallengeAttemptRules.authorize(
      challenge: challengeFixture(),
      progress: const ChallengeAttemptProgress(challengeId: 'daily_test'),
      kind: ChallengeAttemptKind.free,
      availableDiamonds: 0,
      isChildProfile: false,
    );

    expect(decision.isAllowed, isTrue);
    expect(decision.diamondCost, 0);
  });

  test('une relance publicitaire attend le premier essai gratuit', () {
    final ChallengeAttemptDecision decision = ChallengeAttemptRules.authorize(
      challenge: challengeFixture(),
      progress: const ChallengeAttemptProgress(challengeId: 'daily_test'),
      kind: ChallengeAttemptKind.rewardedAdvertisementRetry,
      availableDiamonds: 10,
      isChildProfile: false,
    );

    expect(
      decision.authorization,
      ChallengeAttemptAuthorization.rejectedFreeAttemptsRemaining,
    );
  });

  test('les relances publicitaires restent autorisées sans plafond', () {
    final ChallengeDefinition challenge = challengeFixture();
    const ChallengeAttemptProgress failed = ChallengeAttemptProgress(
      challengeId: 'daily_test',
      attemptsUsed: 1,
    );
    final ChallengeAttemptDecision allowed = ChallengeAttemptRules.authorize(
      challenge: challenge,
      progress: failed,
      kind: ChallengeAttemptKind.rewardedAdvertisementRetry,
      availableDiamonds: 0,
      isChildProfile: false,
    );
    final ChallengeAttemptDecision stillAllowed =
        ChallengeAttemptRules.authorize(
      challenge: challenge,
      progress: const ChallengeAttemptProgress(
        challengeId: 'daily_test',
        attemptsUsed: 1001,
        rewardedAdvertisementRetriesUsed: 1000,
      ),
      kind: ChallengeAttemptKind.rewardedAdvertisementRetry,
      availableDiamonds: 0,
      isChildProfile: false,
    );

    expect(allowed.isAllowed, isTrue);
    expect(stillAllowed.isAllowed, isTrue);
  });

  test('un défi classé réussi peut être rejoué pour améliorer son score', () {
    final ChallengeAttemptDecision decision = ChallengeAttemptRules.authorize(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      progress: ChallengeAttemptProgress(
        challengeId: 'daily_test',
        attemptsUsed: 1,
        completedAtUtc: activeTime,
      ),
      kind: ChallengeAttemptKind.rewardedAdvertisementRetry,
      availableDiamonds: 0,
      isChildProfile: false,
    );

    expect(decision.isAllowed, isTrue);
  });

  test('un défi personnel réussi reste terminé', () {
    final ChallengeAttemptDecision decision = ChallengeAttemptRules.authorize(
      challenge: challengeFixture(),
      progress: ChallengeAttemptProgress(
        challengeId: 'daily_test',
        attemptsUsed: 1,
        completedAtUtc: activeTime,
      ),
      kind: ChallengeAttemptKind.rewardedAdvertisementRetry,
      availableDiamonds: 0,
      isChildProfile: false,
    );

    expect(
      decision.authorization,
      ChallengeAttemptAuthorization.rejectedCompleted,
    );
  });

  test('un profil enfant peut recommencer gratuitement sans plafond', () {
    final ChallengeDefinition challenge = challengeFixture(
      audience: ChallengeAudience.child,
      retryPolicy: const ChallengeRetryPolicy(
        maximumAttempts: 1,
        unlimitedFreeAttempts: true,
      ),
    );
    final ChallengeAttemptDecision decision = ChallengeAttemptRules.authorize(
      challenge: challenge,
      progress: const ChallengeAttemptProgress(
        challengeId: 'daily_test',
        attemptsUsed: 1000,
      ),
      kind: ChallengeAttemptKind.free,
      availableDiamonds: 0,
      isChildProfile: true,
    );

    expect(decision.isAllowed, isTrue);
  });

  test('la publicité est toujours refusée au profil enfant', () {
    final ChallengeAttemptDecision decision = ChallengeAttemptRules.authorize(
      challenge: challengeFixture(),
      progress: const ChallengeAttemptProgress(
        challengeId: 'daily_test',
        attemptsUsed: 1,
      ),
      kind: ChallengeAttemptKind.rewardedAdvertisementRetry,
      availableDiamonds: 0,
      isChildProfile: true,
    );

    expect(
      decision.authorization,
      ChallengeAttemptAuthorization.rejectedChildAdvertisement,
    );
  });

  test('une récompense connectée attend toujours la validation Firebase', () {
    final ChallengeClockEvaluation clock = ChallengeClock.evaluate(
      deviceNow: activeTime,
      serverNow: activeTime,
    );
    final ChallengeRewardClaimDecision decision =
        const ChallengeRewardLedger().claim(
      challenge: challengeFixture(),
      completedSuccessfully: true,
      clock: clock,
    );

    expect(decision.wasAccepted, isTrue);
    expect(decision.canDeliverReward, isFalse);
    expect(
      decision.record!.status,
      ChallengeRewardClaimStatus.pendingServerValidation,
    );
  });

  test('une récompense hors ligne reste en attente de validation', () {
    final ChallengeClockEvaluation clock = ChallengeClock.evaluate(
      deviceNow: activeTime,
    );
    final ChallengeRewardClaimDecision decision =
        const ChallengeRewardLedger().claim(
      challenge: challengeFixture(),
      completedSuccessfully: true,
      clock: clock,
    );

    expect(decision.wasAccepted, isTrue);
    expect(decision.canDeliverReward, isFalse);
    expect(
      decision.record!.status,
      ChallengeRewardClaimStatus.pendingServerValidation,
    );
  });

  test('la même récompense ne peut jamais être enregistrée deux fois', () {
    final ChallengeClockEvaluation clock = ChallengeClock.evaluate(
      deviceNow: activeTime,
      serverNow: activeTime,
    );
    final ChallengeRewardClaimDecision first =
        const ChallengeRewardLedger().claim(
      challenge: challengeFixture(),
      completedSuccessfully: true,
      clock: clock,
    );
    final ChallengeRewardClaimDecision duplicate = first.updatedLedger.claim(
      challenge: challengeFixture(),
      completedSuccessfully: true,
      clock: clock,
    );

    expect(duplicate.outcome, ChallengeRewardClaimOutcome.rejectedDuplicate);
    expect(duplicate.updatedLedger.claims, hasLength(1));
  });

  test('un défi échoué ou expiré ne crée aucune récompense', () {
    final ChallengeClockEvaluation activeClock = ChallengeClock.evaluate(
      deviceNow: activeTime,
      serverNow: activeTime,
    );
    final ChallengeClockEvaluation expiredClock = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 6),
      serverNow: DateTime.utc(2026, 9, 6),
    );
    final ChallengeRewardClaimDecision failed =
        const ChallengeRewardLedger().claim(
      challenge: challengeFixture(),
      completedSuccessfully: false,
      clock: activeClock,
    );
    final ChallengeRewardClaimDecision expired =
        const ChallengeRewardLedger().claim(
      challenge: challengeFixture(),
      completedSuccessfully: true,
      clock: expiredClock,
    );

    expect(failed.outcome, ChallengeRewardClaimOutcome.rejectedIncomplete);
    expect(expired.outcome, ChallengeRewardClaimOutcome.rejectedExpired);
    expect(failed.updatedLedger.claims, isEmpty);
    expect(expired.updatedLedger.claims, isEmpty);
  });

  test('les essais et le registre survivent à la sérialisation', () {
    final ChallengeClockEvaluation clock = ChallengeClock.evaluate(
      deviceNow: activeTime,
      serverNow: activeTime,
    );
    final ChallengeRewardClaimDecision claim =
        const ChallengeRewardLedger().claim(
      challenge: challengeFixture(),
      completedSuccessfully: true,
      clock: clock,
    );
    final ChallengePlayerState source = ChallengePlayerState.initial()
        .registerAttempt(
          challengeId: 'daily_test',
          score: 320,
          correctAnswers: 4,
          succeeded: true,
          playedAt: activeTime,
        )
        .copyWith(
          rewardLedger: claim.updatedLedger,
          clockState: clock.updatedState,
        );
    final ChallengePlayerState restored =
        ChallengePlayerState.fromJson(source.toJson());

    expect(restored.progressFor('daily_test').attemptsUsed, 1);
    expect(restored.progressFor('daily_test').isCompleted, isTrue);
    expect(restored.rewardLedger.claims, hasLength(1));
    expect(restored.wallet.coins, 0);
    expect(restored.clockState.lastTrustedServerUtc, activeTime);
  });

  test('une ancienne sauvegarde sans portefeuille reste compatible', () {
    final ChallengePlayerState restored = ChallengePlayerState.fromJson(
      <String, dynamic>{
        'schemaVersion': 1,
        'attempts': <Object>[],
        'rewardLedger': <String, dynamic>{},
        'clockState': <String, dynamic>{},
      },
    );

    expect(restored.wallet.coins, 0);
    expect(restored.wallet.diamonds, 0);
    expect(restored.wallet.deliveredClaimIds, isEmpty);
  });

  test('récupère un versement confirmé manquant sans le doubler', () {
    final ChallengeClockEvaluation clock = ChallengeClock.evaluate(
      deviceNow: activeTime,
      serverNow: activeTime,
    );
    final ChallengeRewardClaimDecision claim =
        const ChallengeRewardLedger().claim(
      challenge: challengeFixture(),
      completedSuccessfully: true,
      clock: clock,
    );
    final ChallengeRewardLedger confirmedLedger =
        claim.updatedLedger.confirm(claim.record!.claimId);
    final ChallengePlayerState state = ChallengePlayerState.initial().copyWith(
      rewardLedger: confirmedLedger,
    );

    final ChallengePlayerState delivered = state.deliverConfirmedRewards();
    final ChallengePlayerState repeated = delivered.deliverConfirmedRewards();

    expect(delivered.wallet.coins, 25);
    expect(repeated.wallet.coins, 25);
    expect(repeated.wallet.deliveredClaimIds, hasLength(1));
  });
}

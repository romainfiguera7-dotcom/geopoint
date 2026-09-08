import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_player_state.dart';
import 'package:geopoint/challenges/challenge_ranking.dart';
import 'package:geopoint/challenges/challenge_ranking_sync.dart';
import 'package:geopoint/challenges/challenge_result.dart';
import 'package:geopoint/challenges/challenge_reward_sync.dart';
import 'package:geopoint/challenges/challenge_session_service.dart';
import 'package:geopoint/challenges/challenge_storage.dart';
import 'package:geopoint/challenges/challenge_wallet.dart';
import 'package:geopoint/player/player_online_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'challenge_test_factory.dart';

class _ImmediateRankingGateway implements ChallengeRankingGateway {
  int calls = 0;

  @override
  Future<ChallengeRankingSyncResponse> submitRankedResults(
    List<ChallengeRankingSubmissionRequest> requests,
  ) async {
    calls += 1;
    return ChallengeRankingSyncResponse(
      serverNowUtc: DateTime.utc(2026, 9, 4, 12, 1),
      results: requests
          .map(
            (ChallengeRankingSubmissionRequest request) =>
                ChallengeRankingSubmissionResult(
              submissionId: request.submission.submissionId,
              decision: ChallengeRankingServerDecision.confirmed,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ImmediateRewardGateway implements ChallengeRewardValidationGateway {
  @override
  Future<ChallengeRewardValidationResponse> validatePendingRewards(
    List<ChallengeRewardValidationRequest> requests,
  ) async {
    final ChallengeRewardValidationRequest request = requests.single;
    return ChallengeRewardValidationResponse(
      serverNowUtc: DateTime.utc(2026, 9, 4, 12, 1),
      results: <ChallengeRewardValidationResult>[
        ChallengeRewardValidationResult(
          claimId: request.claimId,
          decision: ChallengeRewardValidationDecision.confirmed,
          confirmedReward: request.rewardSnapshot,
        ),
      ],
      authoritativeWallet: ChallengeWallet(
        coins: request.rewardSnapshot.coins,
        diamonds: request.rewardSnapshot.diamonds,
        progressionPoints: request.rewardSnapshot.progressionPoints,
        deliveredClaimIds: <String>{request.claimId},
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('un échec enregistre la tentative sans créer de récompense', () async {
    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(),
      performance: const ChallengePerformance(
        score: 100,
        correctAnswers: 1,
        averageDistanceKilometers: 800,
      ),
      usedRewardedAdvertisementRetry: false,
      deviceNow: DateTime.utc(2026, 9, 4, 12),
    );

    expect(outcome.succeeded, isFalse);
    expect(outcome.saved, isTrue);
    expect(outcome.rewardClaim, isNull);
    expect(
      outcome.playerState.progressFor('daily_test').attemptsUsed,
      1,
    );
    expect(outcome.playerState.rewardLedger.claims, isEmpty);
  });

  test('une réussite hors ligne conserve la récompense en attente', () async {
    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(),
      performance: const ChallengePerformance(
        score: 400,
        correctAnswers: 5,
        averageDistanceKilometers: 20,
      ),
      usedRewardedAdvertisementRetry: false,
      deviceNow: DateTime.utc(2026, 9, 4, 12),
    );

    expect(outcome.succeeded, isTrue);
    expect(outcome.rewardIsPending, isTrue);
    expect(outcome.rewardCanBeDelivered, isFalse);
    expect(outcome.playerState.wallet.coins, 0);
    expect(
      outcome.playerState.progressFor('daily_test').isCompleted,
      isTrue,
    );
  });

  test('une heure serveur fiable ne suffit pas à créditer la récompense',
      () async {
    final DateTime now = DateTime.utc(2026, 9, 4, 12);
    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(),
      performance: const ChallengePerformance(
        score: 400,
        correctAnswers: 5,
        averageDistanceKilometers: 20,
      ),
      usedRewardedAdvertisementRetry: false,
      deviceNow: now,
      serverNow: now,
    );

    expect(outcome.rewardCanBeDelivered, isFalse);
    expect(outcome.rewardWasDelivered, isFalse);
    expect(outcome.rewardIsPending, isTrue);
    expect(outcome.playerState.wallet.coins, 0);
  });

  test('la validation Firebase crédite immédiatement le portefeuille',
      () async {
    final DateTime now = DateTime.utc(2026, 9, 4, 12);
    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(),
      performance: const ChallengePerformance(
        score: 400,
        correctAnswers: 5,
        averageDistanceKilometers: 20,
      ),
      usedRewardedAdvertisementRetry: false,
      deviceNow: now,
      serverNow: now,
      rewardValidationGateway: _ImmediateRewardGateway(),
    );

    expect(outcome.rewardWasDelivered, isTrue);
    expect(outcome.rewardIsPending, isFalse);
    expect(outcome.playerState.wallet.coins, 25);
  });

  test('une relance publicitaire est comptabilisée sans plafond', () async {
    await ChallengeSessionService.complete(
      challenge: challengeFixture(),
      performance: const ChallengePerformance(
        score: 100,
        correctAnswers: 1,
      ),
      usedRewardedAdvertisementRetry: false,
      deviceNow: DateTime.utc(2026, 9, 4, 12),
    );
    final ChallengeSessionOutcome retry =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(),
      performance: const ChallengePerformance(
        score: 150,
        correctAnswers: 2,
      ),
      usedRewardedAdvertisementRetry: true,
      deviceNow: DateTime.utc(2026, 9, 4, 13),
    );
    final ChallengePlayerState? restored = await ChallengeStorage.load();

    expect(
      retry.playerState
          .progressFor('daily_test')
          .rewardedAdvertisementRetriesUsed,
      1,
    );
    expect(restored?.progressFor('daily_test').attemptsUsed, 2);
  });

  test('une réussite classée volontaire est placée dans la file serveur',
      () async {
    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: const ChallengePerformance(
        score: 400,
        correctAnswers: 5,
        averageDistanceKilometers: 20,
        elapsedSeconds: 44,
      ),
      usedRewardedAdvertisementRetry: false,
      participateInRanking: true,
      officialSessionId: 'cs_session_test',
      deviceNow: DateTime.utc(2026, 9, 4, 12),
    );

    expect(outcome.rankingEnqueue?.wasEnqueued, isTrue);
    expect(outcome.playerState.rankingLedger.pendingSubmissions, hasLength(1));
    expect(
      outcome.rankingEnqueue?.submission?.officialSessionId,
      'cs_session_test',
    );
    expect(outcome.playerState.rankingParticipationEnabled, isTrue);
  });

  test('envoie immédiatement une tentative classée à la fin', () async {
    final DateTime now = DateTime.utc(2026, 9, 4, 12);
    final _ImmediateRankingGateway gateway = _ImmediateRankingGateway();
    final PlayerOnlineIdentity identity = PlayerOnlineIdentity.local(
      installationId: 'install_immediate',
      localPlayerId: 'player_immediate',
      createdAtUtc: now,
    ).prepareOnlineMigration(
      providerId: 'firebase',
      onlinePlayerId: 'firebase_uid_immediate',
      requestedAtUtc: now,
    );

    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(rankingGroupId: 'daily_immediate'),
      performance: const ChallengePerformance(
        score: 410,
        correctAnswers: 5,
        averageDistanceKilometers: 18,
        elapsedSeconds: 44,
      ),
      usedRewardedAdvertisementRetry: false,
      participateInRanking: true,
      officialSessionId: 'cs_immediate',
      deviceNow: now,
      rankingGateway: gateway,
      playerIdentity: identity,
    );

    expect(gateway.calls, 1);
    expect(
      outcome.rankingSync?.status,
      ChallengeRankingSyncStatus.synchronized,
    );
    expect(outcome.rankingSync?.confirmedCount, 1);
    expect(outcome.playerState.rankingLedger.pendingSubmissions, isEmpty);
  });

  test('ancre la fin classée sur l’heure de la session Firebase', () async {
    final DateTime serverCompletion = DateTime.utc(2026, 9, 4, 12, 1);
    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(rankingGroupId: 'daily_server_clock'),
      performance: const ChallengePerformance(
        score: 410,
        correctAnswers: 5,
        averageDistanceKilometers: 18,
        elapsedSeconds: 44,
      ),
      usedRewardedAdvertisementRetry: false,
      participateInRanking: true,
      officialSessionId: 'cs_server_clock',
      deviceNow: DateTime.utc(2026, 9, 4, 15, 1),
      serverNow: serverCompletion,
    );

    expect(
      outcome.playerState.rankingLedger.pendingSubmissions.single
          .completedAtUtc,
      serverCompletion,
    );
  });

  test('toutes les tentatives classées sont enregistrées', () async {
    final ChallengeDefinition challenge =
        challengeFixture(rankingGroupId: 'weekly_test');
    final ChallengeSessionOutcome first =
        await ChallengeSessionService.complete(
      challenge: challenge,
      performance: const ChallengePerformance(
        score: 220,
        correctAnswers: 2,
        averageDistanceKilometers: 180,
        elapsedSeconds: 58,
      ),
      usedRewardedAdvertisementRetry: false,
      participateInRanking: true,
      deviceNow: DateTime.utc(2026, 9, 4, 12),
    );
    final ChallengeSessionOutcome second =
        await ChallengeSessionService.complete(
      challenge: challenge,
      performance: const ChallengePerformance(
        score: 460,
        correctAnswers: 5,
        averageDistanceKilometers: 22,
        elapsedSeconds: 43,
      ),
      usedRewardedAdvertisementRetry: true,
      participateInRanking: true,
      deviceNow: DateTime.utc(2026, 9, 4, 13),
    );

    expect(first.succeeded, isFalse);
    expect(first.rankingEnqueue?.wasEnqueued, isTrue);
    expect(first.rankingAttemptIsBest, isTrue);
    expect(second.rankingEnqueue?.wasEnqueued, isTrue);
    expect(second.rankingAttemptIsBest, isTrue);
    expect(second.playerState.rankingLedger.submissions, hasLength(2));
    expect(
      second.playerState.rankingLedger
          .submissionForChallenge(challenge.id)
          ?.score,
      460,
    );
    expect(second.rewardWasAccepted, isTrue);
  });

  test('une partie moins bonne ne remplace jamais le meilleur classement',
      () async {
    final ChallengeDefinition challenge =
        challengeFixture(rankingGroupId: 'weekly_test');
    await ChallengeSessionService.complete(
      challenge: challenge,
      performance: const ChallengePerformance(
        score: 520,
        correctAnswers: 5,
        averageDistanceKilometers: 18,
        elapsedSeconds: 40,
      ),
      usedRewardedAdvertisementRetry: false,
      participateInRanking: true,
      deviceNow: DateTime.utc(2026, 9, 4, 12),
    );
    final ChallengeSessionOutcome lower =
        await ChallengeSessionService.complete(
      challenge: challenge,
      performance: const ChallengePerformance(
        score: 410,
        correctAnswers: 5,
        averageDistanceKilometers: 12,
        elapsedSeconds: 35,
      ),
      usedRewardedAdvertisementRetry: true,
      participateInRanking: true,
      deviceNow: DateTime.utc(2026, 9, 4, 13),
    );

    expect(
      lower.playerState.rankingLedger
          .submissionForChallenge(challenge.id)
          ?.score,
      520,
    );
    expect(lower.playerState.rankingLedger.submissions, hasLength(2));
    expect(lower.rankingAttemptIsBest, isFalse);
  });

  test('une réussite classée reste privée lorsque le joueur refuse', () async {
    final ChallengeSessionOutcome outcome =
        await ChallengeSessionService.complete(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: const ChallengePerformance(
        score: 400,
        correctAnswers: 5,
        averageDistanceKilometers: 20,
        elapsedSeconds: 44,
      ),
      usedRewardedAdvertisementRetry: false,
      participateInRanking: false,
      deviceNow: DateTime.utc(2026, 9, 4, 12),
    );

    expect(
      outcome.rankingEnqueue?.outcome,
      ChallengeRankingEnqueueOutcome.ignoredOptedOut,
    );
    expect(outcome.playerState.rankingLedger.submissions, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_ranking.dart';
import 'package:geopoint/challenges/challenge_result.dart';

import 'challenge_test_factory.dart';

void main() {
  final DateTime completedAt = DateTime.utc(2026, 9, 8, 12);
  const ChallengePerformance performance = ChallengePerformance(
    score: 480,
    correctAnswers: 5,
    averageDistanceKilometers: 18.5,
    elapsedSeconds: 42,
    answerEvidence: <ChallengeAnswerEvidence>[
      ChallengeAnswerEvidence(
        modeId: 'find_country',
        isCorrect: true,
        elapsedSeconds: 3,
      ),
    ],
  );

  test('ignore un défi personnel', () {
    final ChallengeRankingEnqueueDecision decision =
        const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(),
      performance: performance,
      completedAtUtc: completedAt,
      participationEnabled: true,
    );

    expect(decision.outcome, ChallengeRankingEnqueueOutcome.ignoredNotRanked);
    expect(decision.updatedLedger.submissions, isEmpty);
  });

  test('respecte le refus de participer au classement', () {
    final ChallengeRankingEnqueueDecision decision =
        const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: performance,
      completedAtUtc: completedAt,
      participationEnabled: false,
    );

    expect(decision.outcome, ChallengeRankingEnqueueOutcome.ignoredOptedOut);
    expect(decision.updatedLedger.submissions, isEmpty);
  });

  test('enregistre uniquement les critères compétitifs', () {
    final ChallengeRankingEnqueueDecision decision =
        const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: performance,
      completedAtUtc: completedAt,
      participationEnabled: true,
      officialSessionId: 'cs_ranking_test',
    );
    final ChallengeRankingSubmission submission = decision.submission!;

    expect(decision.wasEnqueued, isTrue);
    expect(submission.rankingGroupId, 'weekly_test');
    expect(submission.score, 480);
    expect(submission.correctAnswers, 5);
    expect(submission.averageDistanceKilometers, 18.5);
    expect(submission.elapsedSeconds, 42);
    expect(submission.competitiveSignature, isNotEmpty);
    expect(submission.officialSessionId, 'cs_ranking_test');
    expect(submission.answerEvidence.single.modeId, 'find_country');
  });

  test('refuse une performance sans temps mesuré', () {
    final ChallengeRankingEnqueueDecision decision =
        const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: const ChallengePerformance(
        score: 480,
        correctAnswers: 5,
      ),
      completedAtUtc: completedAt,
      participationEnabled: true,
    );

    expect(
      decision.outcome,
      ChallengeRankingEnqueueOutcome.rejectedInvalidPerformance,
    );
  });

  test('ne crée jamais deux envois pour la même tentative', () {
    final challenge = challengeFixture(rankingGroupId: 'weekly_test');
    final ChallengeRankingEnqueueDecision first =
        const ChallengeRankingLedger().enqueue(
      challenge: challenge,
      performance: performance,
      completedAtUtc: completedAt,
      participationEnabled: true,
    );
    final ChallengeRankingEnqueueDecision duplicate =
        first.updatedLedger.enqueue(
      challenge: challenge,
      performance: performance,
      completedAtUtc: completedAt.add(const Duration(minutes: 1)),
      participationEnabled: true,
    );

    expect(
      duplicate.outcome,
      ChallengeRankingEnqueueOutcome.rejectedDuplicate,
    );
    expect(duplicate.updatedLedger.submissions, hasLength(1));
  });

  test('enregistre chaque tentative et conserve le meilleur score', () {
    final challenge = challengeFixture(rankingGroupId: 'weekly_test');
    final ChallengeRankingEnqueueDecision first =
        const ChallengeRankingLedger().enqueue(
      challenge: challenge,
      performance: performance,
      attemptNumber: 1,
      completedAtUtc: completedAt,
      participationEnabled: true,
    );
    final ChallengeRankingEnqueueDecision second =
        first.updatedLedger.enqueue(
      challenge: challenge,
      performance: const ChallengePerformance(
        score: 520,
        correctAnswers: 5,
        averageDistanceKilometers: 24,
        elapsedSeconds: 46,
      ),
      attemptNumber: 2,
      completedAtUtc: completedAt.add(const Duration(minutes: 2)),
      participationEnabled: true,
    );

    expect(second.wasEnqueued, isTrue);
    expect(second.updatedLedger.submissions, hasLength(2));
    expect(
      second.updatedLedger.submissionForChallenge(challenge.id)?.score,
      520,
    );
    expect(second.submission?.attemptNumber, 2);
  });

  test('départage un score égal par la distance puis par le temps', () {
    final challenge = challengeFixture(rankingGroupId: 'weekly_test');
    final ChallengeRankingLedger first = const ChallengeRankingLedger()
        .enqueue(
          challenge: challenge,
          performance: const ChallengePerformance(
            score: 500,
            correctAnswers: 5,
            averageDistanceKilometers: 30,
            elapsedSeconds: 45,
          ),
          attemptNumber: 1,
          completedAtUtc: completedAt,
          participationEnabled: true,
        )
        .updatedLedger;
    final ChallengeRankingLedger second = first
        .enqueue(
          challenge: challenge,
          performance: const ChallengePerformance(
            score: 500,
            correctAnswers: 5,
            averageDistanceKilometers: 18,
            elapsedSeconds: 55,
          ),
          attemptNumber: 2,
          completedAtUtc: completedAt.add(const Duration(minutes: 2)),
          participationEnabled: true,
        )
        .updatedLedger;
    final ChallengeRankingLedger ledger = second
        .enqueue(
          challenge: challenge,
          performance: const ChallengePerformance(
            score: 500,
            correctAnswers: 5,
            averageDistanceKilometers: 18,
            elapsedSeconds: 41,
          ),
          attemptNumber: 3,
          completedAtUtc: completedAt.add(const Duration(minutes: 3)),
          participationEnabled: true,
        )
        .updatedLedger;

    final ChallengeRankingSubmission best =
        ledger.submissionForChallenge(challenge.id)!;
    expect(best.attemptNumber, 3);
    expect(best.averageDistanceKilometers, 18);
    expect(best.elapsedSeconds, 41);
  });

  test('mémorise la position et son évolution', () {
    final ChallengeRankingEnqueueDecision queued =
        const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: performance,
      completedAtUtc: completedAt,
      participationEnabled: true,
    );
    final ChallengeRankingLedger confirmed = queued.updatedLedger.confirm(
      queued.submission!.submissionId,
      const ChallengeLeaderboardPosition(
        rank: 18,
        totalParticipants: 420,
        score: 480,
        previousRank: 25,
      ),
    );
    final ChallengeRankingSubmission submission =
        confirmed.submissions.values.single;

    expect(submission.status, ChallengeRankingSubmissionStatus.confirmed);
    expect(submission.position?.movement, 7);
  });

  test('le classement survit à la sérialisation', () {
    final ChallengeRankingEnqueueDecision queued =
        const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: performance,
      completedAtUtc: completedAt,
      participationEnabled: true,
    );
    final ChallengeRankingLedger quarantined = queued.updatedLedger.quarantine(
      queued.submission!.submissionId,
      reason: 'Vérification automatique.',
    );
    final ChallengeRankingLedger restored =
        ChallengeRankingLedger.fromJson(quarantined.toJson());
    final ChallengeRankingSubmission submission =
        restored.submissions.values.single;

    expect(submission.status, ChallengeRankingSubmissionStatus.quarantined);
    expect(submission.reviewReason, contains('Vérification'));
    expect(submission.attemptNumber, 1);
    expect(submission.answerEvidence.single.elapsedSeconds, 3);
  });

  test('une ancienne sauvegarde devient la tentative numéro 1', () {
    final ChallengeRankingLedger restored = ChallengeRankingLedger.fromJson(
      <String, dynamic>{
        'schemaVersion': 1,
        'submissions': <Map<String, dynamic>>[
          <String, dynamic>{
            'submissionId': 'ranking:legacy',
            'challengeId': 'weekly_legacy',
            'rankingGroupId': 'weekly_legacy',
            'competitiveSignature': 'legacy',
            'completedAtUtc': completedAt.toIso8601String(),
            'score': 420,
            'correctAnswers': 4,
            'averageDistanceKilometers': 32,
            'elapsedSeconds': 50,
            'status': 'confirmed',
          },
        ],
      },
    );

    expect(restored.schemaVersion, ChallengeRankingLedger.currentSchemaVersion);
    expect(restored.submissions.values.single.attemptNumber, 1);
  });

  test('clôt une ancienne tentative sans preuve serveur', () {
    final ChallengeRankingLedger restored = ChallengeRankingLedger.fromJson(
      <String, dynamic>{
        'schemaVersion': 3,
        'submissions': <Map<String, dynamic>>[
          <String, dynamic>{
            'submissionId': 'ranking:legacy:attempt:1',
            'challengeId': 'weekly_legacy',
            'rankingGroupId': 'weekly_legacy',
            'attemptNumber': 1,
            'competitiveSignature': 'legacy',
            'completedAtUtc': completedAt.toIso8601String(),
            'score': 420,
            'correctAnswers': 4,
            'averageDistanceKilometers': 32,
            'elapsedSeconds': 50,
            'status': 'pending_server_validation',
          },
        ],
      },
    );

    final ChallengeRankingSubmission submission =
        restored.submissions.values.single;
    expect(submission.status, ChallengeRankingSubmissionStatus.rejected);
    expect(submission.reviewReason, contains('non vérifiable'));
    expect(restored.pendingSubmissions, isEmpty);
  });

  test('ne requalifie pas une sauvegarde créée avec le schéma courant', () {
    final ChallengeRankingEnqueueDecision queued =
        const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: performance,
      completedAtUtc: completedAt,
      participationEnabled: true,
    );

    final ChallengeRankingLedger restored = ChallengeRankingLedger.fromJson(
      queued.updatedLedger.toJson(),
    );

    expect(restored.pendingSubmissions, hasLength(1));
    expect(
      restored.pendingSubmissions.single.score,
      performance.score,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_clock.dart';
import 'package:geopoint/challenges/challenge_player_state.dart';
import 'package:geopoint/challenges/challenge_ranking.dart';
import 'package:geopoint/challenges/challenge_ranking_sync.dart';
import 'package:geopoint/challenges/challenge_result.dart';
import 'package:geopoint/player/player_online_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'challenge_test_factory.dart';

class _FakeRankingGateway implements ChallengeRankingGateway {
  _FakeRankingGateway({this.response, this.error});

  final ChallengeRankingSyncResponse? response;
  final Object? error;
  int callCount = 0;
  List<ChallengeRankingSubmissionRequest>? receivedRequests;

  @override
  Future<ChallengeRankingSyncResponse> submitRankedResults(
    List<ChallengeRankingSubmissionRequest> requests,
  ) async {
    callCount += 1;
    receivedRequests = requests;
    if (error != null) {
      throw error!;
    }
    return response!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime.utc(2026, 9, 8, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ChallengeClockEvaluation clock() {
    return ChallengeClock.evaluate(deviceNow: now);
  }

  PlayerOnlineIdentity linkedIdentity() {
    return PlayerOnlineIdentity.local(
      installationId: 'install_test',
      localPlayerId: 'player_local_test',
      createdAtUtc: now,
    ).prepareOnlineMigration(
      providerId: 'test',
      onlinePlayerId: 'player_online_test',
      requestedAtUtc: now,
    ).confirmMigration(migratedAtUtc: now);
  }

  PlayerOnlineIdentity pendingIdentity() {
    return PlayerOnlineIdentity.local(
      installationId: 'install_pending',
      localPlayerId: 'player_local_pending',
      createdAtUtc: now,
    ).prepareOnlineMigration(
      providerId: 'firebase',
      onlinePlayerId: 'player_pending_test',
      requestedAtUtc: now,
    );
  }

  ChallengePlayerState pendingState() {
    final decision = const ChallengeRankingLedger().enqueue(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      performance: const ChallengePerformance(
        score: 480,
        correctAnswers: 5,
        averageDistanceKilometers: 18.5,
        elapsedSeconds: 42,
      ),
      completedAtUtc: now,
      participationEnabled: true,
    );
    return ChallengePlayerState.initial().copyWith(
      rankingLedger: decision.updatedLedger,
      rankingParticipationEnabled: true,
      clockState: clock().updatedState,
    );
  }

  ChallengeRankingSyncResponse responseFor(
    ChallengePlayerState state, {
    ChallengeRankingServerDecision decision =
        ChallengeRankingServerDecision.confirmed,
    int score = 480,
  }) {
    final ChallengeRankingSubmission submission =
        state.rankingLedger.pendingSubmissions.single;
    return ChallengeRankingSyncResponse(
      serverNowUtc: now.add(const Duration(minutes: 2)),
      results: <ChallengeRankingSubmissionResult>[
        ChallengeRankingSubmissionResult(
          submissionId: submission.submissionId,
          decision: decision,
          position: decision == ChallengeRankingServerDecision.confirmed
              ? ChallengeLeaderboardPosition(
                  rank: 18,
                  totalParticipants: 420,
                  score: score,
                  previousRank: 25,
                )
              : null,
          reason: decision == ChallengeRankingServerDecision.quarantined
              ? 'Score en cours de vérification.'
              : null,
        ),
      ],
    );
  }

  test('ne contacte pas le serveur sans résultat en attente', () async {
    final _FakeRankingGateway gateway = _FakeRankingGateway(
      error: StateError('ne doit pas être appelé'),
    );
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: ChallengePlayerState.initial(),
      clock: clock(),
      deviceNow: now,
      playerIdentity: linkedIdentity(),
      gateway: gateway,
    );

    expect(report.status, ChallengeRankingSyncStatus.upToDate);
    expect(gateway.callCount, 0);
  });

  test('conserve le résultat lorsque le serveur n’est pas branché', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
    );

    expect(report.status, ChallengeRankingSyncStatus.pendingConnection);
    expect(report.pendingAfter, 1);
  });

  test('attend une identité en ligne avant de contacter le serveur', () async {
    final ChallengePlayerState state = pendingState();
    final _FakeRankingGateway gateway = _FakeRankingGateway(
      error: StateError('ne doit pas être appelé'),
    );
    final PlayerOnlineIdentity localIdentity = PlayerOnlineIdentity.local(
      installationId: 'install_local',
      localPlayerId: 'player_local',
      createdAtUtc: now,
    );
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: localIdentity,
      gateway: gateway,
    );

    expect(report.status, ChallengeRankingSyncStatus.pendingPlayerIdentity);
    expect(report.pendingAfter, 1);
    expect(gateway.callCount, 0);
  });

  test('envoie le résultat et mémorise la position autoritaire', () async {
    final ChallengePlayerState state = pendingState();
    final _FakeRankingGateway gateway = _FakeRankingGateway(
      response: responseFor(state),
    );
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: linkedIdentity(),
      gateway: gateway,
    );
    final ChallengeRankingSubmission submission =
        report.playerState.rankingLedger.submissions.values.single;

    expect(report.status, ChallengeRankingSyncStatus.synchronized);
    expect(report.confirmedCount, 1);
    expect(report.clock.source, ChallengeClockSource.server);
    expect(submission.position?.rank, 18);
    expect(
      gateway.receivedRequests!.single.toJson()['playerId'],
      'player_online_test',
    );
    expect(gateway.receivedRequests!.single.toJson()['attemptNumber'], 1);
    expect(gateway.receivedRequests!.single.toJson(), isNot(contains('xp')));
  });

  test('envoie aussi pendant la validation de migration', () async {
    final ChallengePlayerState state = pendingState();
    final _FakeRankingGateway gateway = _FakeRankingGateway(
      response: responseFor(state),
    );

    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: pendingIdentity(),
      gateway: gateway,
    );

    expect(report.status, ChallengeRankingSyncStatus.synchronized);
    expect(
      gateway.receivedRequests!.single.playerId,
      'player_pending_test',
    );
  });

  test('confirme une tentative moins bonne sans nouvelle position', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRankingSubmission submission =
        state.rankingLedger.pendingSubmissions.single;
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: linkedIdentity(),
      gateway: _FakeRankingGateway(
        response: ChallengeRankingSyncResponse(
          serverNowUtc: now,
          results: <ChallengeRankingSubmissionResult>[
            ChallengeRankingSubmissionResult(
              submissionId: submission.submissionId,
              decision: ChallengeRankingServerDecision.confirmed,
            ),
          ],
        ),
      ),
    );

    expect(report.status, ChallengeRankingSyncStatus.synchronized);
    expect(
      report.playerState.rankingLedger.submissions.values.single.status,
      ChallengeRankingSubmissionStatus.confirmed,
    );
    expect(
      report.playerState.rankingLedger.submissions.values.single.position,
      isNull,
    );
  });

  test('place un score suspect en vérification sans position', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: linkedIdentity(),
      gateway: _FakeRankingGateway(
        response: responseFor(
          state,
          decision: ChallengeRankingServerDecision.quarantined,
        ),
      ),
    );
    final ChallengeRankingSubmission submission =
        report.playerState.rankingLedger.submissions.values.single;

    expect(report.quarantinedCount, 1);
    expect(submission.status, ChallengeRankingSubmissionStatus.quarantined);
    expect(submission.position, isNull);
  });

  test('une panne conserve le résultat dans la file', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: linkedIdentity(),
      gateway: _FakeRankingGateway(error: StateError('hors ligne')),
    );

    expect(report.status, ChallengeRankingSyncStatus.serverUnavailable);
    expect(report.pendingAfter, 1);
  });

  test('ignore intégralement une réponse incomplète', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: linkedIdentity(),
      gateway: _FakeRankingGateway(
        response: ChallengeRankingSyncResponse(
          serverNowUtc: now,
          results: const <ChallengeRankingSubmissionResult>[],
        ),
      ),
    );

    expect(report.status, ChallengeRankingSyncStatus.invalidServerResponse);
    expect(report.pendingAfter, 1);
  });

  test('refuse une position associée à un score différent', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRankingSyncReport report =
        await ChallengeRankingSyncService.synchronize(
      playerState: state,
      clock: clock(),
      deviceNow: now,
      playerIdentity: linkedIdentity(),
      gateway: _FakeRankingGateway(
        response: responseFor(state, score: 999999),
      ),
    );

    expect(report.status, ChallengeRankingSyncStatus.invalidServerResponse);
    expect(report.pendingAfter, 1);
  });
}

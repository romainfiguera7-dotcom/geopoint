import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/admin/geopoint_admin_control.dart';
import 'package:geopoint/challenges/challenge_official_session.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_leaderboard.dart';
import 'package:geopoint/challenges/challenge_ranking.dart';
import 'package:geopoint/challenges/challenge_ranking_sync.dart';
import 'package:geopoint/challenges/challenge_result.dart';
import 'package:geopoint/challenges/challenge_reward_sync.dart';
import 'package:geopoint/challenges/challenge_server_connection.dart';
import 'package:geopoint/server/firebase_callable_gateway.dart';
import 'package:geopoint/server/flutterfire_callable_transport.dart';
import 'package:geopoint/server/geopoint_server_contract.dart';
import 'package:geopoint/social/geopoint_friends.dart';

class _FakeCallableTransport implements GeoPointCallableTransport {
  _FakeCallableTransport(this.responses);

  final Map<String, Map<String, dynamic>> responses;
  final List<String> calls = <String>[];
  Map<String, dynamic>? lastData;

  @override
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    calls.add(functionName);
    lastData = data;
    return responses[functionName] ?? <String, dynamic>{};
  }
}

void main() {
  final DateTime now = DateTime.utc(2026, 9, 10, 12);

  setUp(ChallengeServerConnection.clear);

  test('décode l’état du serveur Firebase', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.serverStatus: <String, dynamic>{
          'apiVersion': 1,
          'schemaVersion': 1,
          'region': 'europe-west1',
          'serverNowUtc': now.toIso8601String(),
          'capabilities': <String>['identity_registration'],
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final GeoPointServerStatus status = await gateway.getStatus();

    expect(status.schemaVersion, 1);
    expect(transport.calls.single, FirebaseCallableNames.serverStatus);
    expect(transport.lastData, <String, dynamic>{'apiVersion': 1});
  });

  test('décode un pack de défis publié par Firebase', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.activeChallengePack: <String, dynamic>{
          'apiVersion': 1,
          'serverNowUtc': now.toIso8601String(),
          'pack': <String, dynamic>{
            'revision': 7,
            'publishedAtUtc': now.subtract(const Duration(days: 1))
                .toIso8601String(),
            'jsonSource': '{"schemaVersion":1}',
          },
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final pack = await gateway.fetchActivePack();

    expect(pack, isNotNull);
    expect(pack!.revision, 7);
    expect(pack.jsonSource, '{"schemaVersion":1}');
  });

  test('accepte l’absence temporaire de pack distant', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.activeChallengePack: <String, dynamic>{
          'apiVersion': 1,
          'serverNowUtc': now.toIso8601String(),
          'pack': null,
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    expect(await gateway.fetchActivePack(), isNull);
  });

  test('synchronise le portefeuille de récompenses Firebase', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.validateChallengeRewards: <String, dynamic>{
          'apiVersion': 1,
          'serverNowUtc': now.toIso8601String(),
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'claimId': 'daily_test@2026-09-10T00:00:00.000Z',
              'decision': 'confirmed',
              'confirmedReward': <String, dynamic>{
                'xp': 60,
                'coins': 25,
                'diamonds': 0,
                'cosmeticIds': <String>[],
                'progressionPoints': 1,
              },
            },
          ],
          'wallet': <String, dynamic>{
            'schemaVersion': 1,
            'coins': 25,
            'diamonds': 0,
            'progressionPoints': 1,
            'cosmeticIds': <String>[],
            'stampIds': <String>[],
            'emblemIds': <String>[],
            'deliveredClaimIds': <String>[
              'daily_test@2026-09-10T00:00:00.000Z',
            ],
          },
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final ChallengeRewardValidationResponse response =
        await gateway.validatePendingRewards(
      <ChallengeRewardValidationRequest>[
        ChallengeRewardValidationRequest(
          claimId: 'daily_test@2026-09-10T00:00:00.000Z',
          challengeId: 'daily_test',
          claimedAtUtc: now,
          attemptsUsed: 1,
          rewardedAdvertisementRetriesUsed: 0,
          bestScore: 350,
          bestCorrectAnswers: 5,
          rewardSnapshot: const ChallengeReward(coins: 25),
        ),
      ],
    );

    expect(response.results.single.decision,
        ChallengeRewardValidationDecision.confirmed);
    expect(response.authoritativeWallet!.coins, 25);
    expect(transport.calls.single,
        FirebaseCallableNames.validateChallengeRewards);
  });

  test('crée et décode une session officielle Firebase', () async {
    final DateTime expiresAt = now.add(const Duration(minutes: 45));
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.startOfficialChallengeSession:
            <String, dynamic>{
          'apiVersion': 1,
          'sessionId': 'cs_gateway_test',
          'challengeId': 'weekly_02',
          'rankingGroupId': 'weekly_02',
          'competitiveSignature': 'signature_test',
          'startedAtUtc': now.toIso8601String(),
          'expiresAtUtc': expiresAt.toIso8601String(),
          'serverNowUtc': now.toIso8601String(),
          'rankingEligible': true,
          'migrationStatus': 'completed',
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final ChallengeOfficialSession session =
        await gateway.startOfficialSession(
      const ChallengeOfficialSessionRequest(
        launchId: 'launch_gateway_test',
        challengeId: 'weekly_02',
        rankingGroupId: 'weekly_02',
        competitiveSignature: 'signature_test',
      ),
    );

    expect(session.sessionId, 'cs_gateway_test');
    expect(
      transport.calls.single,
      FirebaseCallableNames.startOfficialChallengeSession,
    );
    expect(transport.lastData?['launchId'], 'launch_gateway_test');
  });

  test('envoie les preuves et décode la validation du score', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.submitRankedResults: <String, dynamic>{
          'apiVersion': 1,
          'serverNowUtc': now.toIso8601String(),
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'submissionId': 'ranking:weekly_01:attempt:1',
              'decision': 'confirmed',
              'bestUpdated': true,
            },
          ],
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);
    final ChallengeRankingSubmission submission = ChallengeRankingSubmission(
      submissionId: 'ranking:weekly_01:attempt:1',
      challengeId: 'weekly_01',
      rankingGroupId: 'weekly_01',
      attemptNumber: 1,
      competitiveSignature: 'signature_test',
      officialSessionId: 'cs_gateway_test',
      completedAtUtc: now,
      score: 120,
      correctAnswers: 1,
      averageDistanceKilometers: 0,
      elapsedSeconds: 3,
      status: ChallengeRankingSubmissionStatus.pendingServerValidation,
      answerEvidence: const <ChallengeAnswerEvidence>[
        ChallengeAnswerEvidence(
          modeId: 'find_country',
          isCorrect: true,
          elapsedSeconds: 3,
        ),
      ],
    );

    final ChallengeRankingSyncResponse response =
        await gateway.submitRankedResults(
      <ChallengeRankingSubmissionRequest>[
        ChallengeRankingSubmissionRequest(
          playerId: 'firebase_uid_test',
          submission: submission,
        ),
      ],
    );

    expect(
      response.results.single.decision,
      ChallengeRankingServerDecision.confirmed,
    );
    expect(
      transport.calls.single,
      FirebaseCallableNames.submitRankedResults,
    );
    final Object? rawSubmissions = transport.lastData?['submissions'];
    expect(rawSubmissions, isA<List<dynamic>>());
    final List<dynamic> sentSubmissions = rawSubmissions! as List<dynamic>;
    final Map<dynamic, dynamic> sent =
        sentSubmissions.single as Map<dynamic, dynamic>;
    expect(sent['officialSessionId'], 'cs_gateway_test');
    expect(sent['answerEvidence'], hasLength(1));
  });

  test('charge les classements quotidien, hebdomadaire et saisonnier',
      () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.challengeLeaderboards: <String, dynamic>{
          'apiVersion': 1,
          'serverNowUtc': now.toIso8601String(),
          'scope': 'friends',
          'currentPlayerHistory': <Map<String, dynamic>>[
            <String, dynamic>{
              'submissionId': 'ranking:daily:attempt:1',
              'challengeId': 'daily_2026_09_10',
              'challengeTitle': 'Défi du jour',
              'completedAtUtc': now.toIso8601String(),
              'score': 500,
              'correctAnswers': 5,
              'elapsedSeconds': 60,
              'status': 'validated',
              'isBest': true,
              'reason': null,
            },
          ],
          'seasonRewardPolicy': <String, dynamic>{
            'version': 1,
            'claimOpensAtUtc': '2026-10-01T01:00:00.000Z',
            'tiers': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'participant',
                'label': 'Explorateur',
                'maximumRank': null,
                'coins': 75,
                'diamonds': 0,
              },
            ],
          },
          'boards': <Map<String, dynamic>>[
            <String, dynamic>{
              'boardId': 'daily_2026_09_10',
              'type': 'daily',
              'title': 'Défi du jour',
              'seasonKey': '2026-09',
              'totalParticipants': 0,
              'entries': <Map<String, dynamic>>[],
              'currentPlayerEntry': null,
            },
            <String, dynamic>{
              'boardId': 'season_2026_09',
              'type': 'season',
              'title': 'Saison 2026-09',
              'seasonKey': '2026-09',
              'totalParticipants': 0,
              'entries': <Map<String, dynamic>>[],
              'currentPlayerEntry': null,
            },
          ],
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final ChallengeLeaderboardSnapshot snapshot =
        await gateway.fetchLeaderboards(
      rankingGroupIds: const <String>['daily_2026_09_10'],
      seasonKey: '2026-09',
      scope: ChallengeLeaderboardScope.friends,
    );

    expect(snapshot.boards, hasLength(2));
    expect(snapshot.scope, ChallengeLeaderboardScope.friends);
    expect(snapshot.currentPlayerHistory, hasLength(1));
    expect(snapshot.seasonRewardTiers.single.coins, 75);
    expect(
      snapshot.boardFor(ChallengeLeaderboardKind.season),
      isNotNull,
    );
    expect(
      transport.calls.single,
      FirebaseCallableNames.challengeLeaderboards,
    );
    expect(transport.lastData?['seasonKey'], '2026-09');
    expect(transport.lastData?['scope'], 'friends');
  });

  test('charge le code, les demandes et la liste d’amis', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.friendDashboard: <String, dynamic>{
          'apiVersion': 1,
          'serverNowUtc': now.toIso8601String(),
          'friendCode': 'GP-ABCD-2345',
          'limits': <String, dynamic>{
            'maximumFriends': 50,
            'maximumPendingRequests': 20,
          },
          'friends': <Map<String, dynamic>>[],
          'receivedRequests': <Map<String, dynamic>>[],
          'sentRequests': <Map<String, dynamic>>[],
          'blockedPlayers': <Map<String, dynamic>>[],
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final GeoPointFriendDashboard dashboard =
        await gateway.fetchFriendDashboard();

    expect(dashboard.friendCode, 'GP-ABCD-2345');
    expect(transport.calls.single, FirebaseCallableNames.friendDashboard);
  });

  test('envoie un code ami et accepte une demande', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.sendFriendRequest: <String, dynamic>{
          'apiVersion': 1,
          'status': 'sent',
        },
        FirebaseCallableNames.updateFriendRelation: <String, dynamic>{
          'apiVersion': 1,
          'status': 'updated',
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    await gateway.sendFriendRequest('GP-ABCD-2345');
    expect(transport.lastData?['friendCode'], 'GP-ABCD-2345');
    await gateway.updateFriendRelation(
      action: GeoPointFriendRelationAction.accept,
      requestId: 'request_1',
    );
    expect(transport.lastData?['action'], 'accept');
    expect(transport.lastData?['requestId'], 'request_1');
  });

  test('réclame une récompense de saison confirmée par Firebase', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.claimSeasonReward: <String, dynamic>{
          'apiVersion': 1,
          'status': 'claimed',
          'serverNowUtc': now.toIso8601String(),
          'seasonKey': '2026-08',
          'claimId': 'season_reward:2026-08',
          'rank': 4,
          'challengeCount': 12,
          'claimedAtUtc': now.toIso8601String(),
          'alreadyClaimed': false,
          'reward': <String, dynamic>{
            'tierId': 'top_10',
            'tierLabel': 'Top 10',
            'xp': 0,
            'coins': 250,
            'diamonds': 2,
            'cosmeticIds': <String>[],
            'progressionPoints': 0,
          },
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final response = await gateway.claimSeasonReward('2026-08');

    expect(response.rank, 4);
    expect(response.reward?.coins, 250);
    expect(transport.calls.single, FirebaseCallableNames.claimSeasonReward);
    expect(transport.lastData?['seasonKey'], '2026-08');
  });

  test('branche et débranche le service Firebase central', () {
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(
      transport: _FakeCallableTransport(<String, Map<String, dynamic>>{}),
    );

    ChallengeServerConnection.configure(
      server: gateway,
      packs: gateway,
      officialSessions: gateway,
      rankings: gateway,
      leaderboards: gateway,
      seasonRewards: gateway,
      friends: gateway,
      administration: gateway,
    );

    expect(ChallengeServerConnection.isConfigured, isTrue);
    expect(ChallengeServerConnection.coreGateway, same(gateway));
    expect(ChallengeServerConnection.packGateway, same(gateway));
    expect(ChallengeServerConnection.officialSessionGateway, same(gateway));
    expect(ChallengeServerConnection.rankingGateway, same(gateway));
    expect(ChallengeServerConnection.leaderboardGateway, same(gateway));
    expect(ChallengeServerConnection.seasonRewardGateway, same(gateway));
    expect(ChallengeServerConnection.friendGateway, same(gateway));
    expect(ChallengeServerConnection.adminGateway, same(gateway));

    ChallengeServerConnection.clear();
    expect(ChallengeServerConnection.isConfigured, isFalse);
  });

  test('charge le contrôle interne et transmet une décision tracée', () async {
    final _FakeCallableTransport transport = _FakeCallableTransport(
      <String, Map<String, dynamic>>{
        FirebaseCallableNames.adminControlDashboard: <String, dynamic>{
          'apiVersion': 1,
          'serverNowUtc': now.toIso8601String(),
          'counters': <String, dynamic>{
            'pendingReviews': 1,
            'rejectedSubmissions': 0,
            'activeSessions': 2,
          },
          'player': null,
          'competition': null,
          'submissions': <Map<String, dynamic>>[],
          'auditLogs': <Map<String, dynamic>>[],
        },
        FirebaseCallableNames.adminUpdateRankedSubmission: <String, dynamic>{
          'apiVersion': 1,
          'status': 'updated',
        },
      },
    );
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);

    final GeoPointAdminDashboard dashboard =
        await gateway.fetchDashboard(query: 'daily_01');
    expect(dashboard.counters.activeSessions, 2);
    expect(transport.lastData?['query'], 'daily_01');

    await gateway.updateSubmission(
      playerId: 'uid_player',
      submissionId: 'ranking:daily:1',
      action: GeoPointAdminScoreAction.invalidate,
      reason: 'Contrôle manuel du résultat',
    );
    expect(transport.lastData?['action'], 'invalidate');
    expect(transport.lastData?['reason'], 'Contrôle manuel du résultat');
  });

  test('normalise une réponse native reçue des fonctions', () {
    final Map<String, dynamic> response =
        FlutterFireCallableTransport.normalizeResponse(
      <Object?, Object?>{
        'apiVersion': 1,
        'serverNowUtc': now.toIso8601String(),
      },
    );

    expect(response['apiVersion'], 1);
    expect(response['serverNowUtc'], now.toIso8601String());
  });

  test('refuse une réponse callable qui n’est pas un objet', () {
    expect(
      () => FlutterFireCallableTransport.normalizeResponse('invalide'),
      throwsFormatException,
    );
  });

  test('renouvelle les jetons et rejoue un appel non authentifié', () async {
    int callCount = 0;
    int refreshCount = 0;
    final FlutterFireCallableTransport transport =
        FlutterFireCallableTransport(
      callableInvoker: (
        String functionName,
        Map<String, dynamic> data,
      ) async {
        callCount += 1;
        if (callCount == 1) {
          throw StateError('jeton expiré');
        }
        return <String, dynamic>{
          'apiVersion': data['apiVersion'],
          'functionName': functionName,
        };
      },
      refreshAuthentication: () async {
        refreshCount += 1;
      },
      authenticationErrorTest: (Object error) => error is StateError,
    );

    final Map<String, dynamic> response = await transport.call(
      'submitRankedResults',
      const <String, dynamic>{'apiVersion': 1},
    );

    expect(callCount, 2);
    expect(refreshCount, 1);
    expect(response['apiVersion'], 1);
    expect(response['functionName'], 'submitRankedResults');
  });

  test(
    'ne rejoue pas une erreur sans rapport avec l’authentification',
    () async {
      int refreshCount = 0;
      final FlutterFireCallableTransport transport =
          FlutterFireCallableTransport(
        callableInvoker: (
          String functionName,
          Map<String, dynamic> data,
        ) async {
          throw const FormatException('réponse invalide');
        },
        refreshAuthentication: () async {
          refreshCount += 1;
        },
        authenticationErrorTest: (Object error) => error is StateError,
      );

      await expectLater(
        transport.call(
          'submitRankedResults',
          const <String, dynamic>{'apiVersion': 1},
        ),
        throwsFormatException,
      );
      expect(refreshCount, 0);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_official_session.dart';

import 'challenge_test_factory.dart';

class _FakeSessionGateway implements ChallengeOfficialSessionGateway {
  _FakeSessionGateway({required this.now});

  final DateTime now;
  ChallengeOfficialSessionRequest? received;

  @override
  Future<ChallengeOfficialSession> startOfficialSession(
    ChallengeOfficialSessionRequest request,
  ) async {
    received = request;
    return ChallengeOfficialSession(
      sessionId: 'cs_test_001',
      challengeId: request.challengeId,
      rankingGroupId: request.rankingGroupId,
      competitiveSignature: request.competitiveSignature,
      startedAtUtc: now,
      expiresAtUtc: now.add(const Duration(minutes: 45)),
      serverNowUtc: now,
      rankingEligible: true,
      migrationStatus: 'completed',
    );
  }
}

class _WrongSessionGateway implements ChallengeOfficialSessionGateway {
  _WrongSessionGateway(this.now);

  final DateTime now;

  @override
  Future<ChallengeOfficialSession> startOfficialSession(
    ChallengeOfficialSessionRequest request,
  ) async {
    return ChallengeOfficialSession(
      sessionId: 'cs_wrong',
      challengeId: 'another_challenge',
      rankingGroupId: request.rankingGroupId,
      competitiveSignature: request.competitiveSignature,
      startedAtUtc: now,
      expiresAtUtc: now.add(const Duration(minutes: 1)),
      serverNowUtc: now,
      rankingEligible: true,
      migrationStatus: 'completed',
    );
  }
}

void main() {
  final DateTime now = DateTime.utc(2026, 9, 5, 12);

  test('demande une session distincte avant une tentative classée', () async {
    final _FakeSessionGateway gateway = _FakeSessionGateway(now: now);
    final challenge = challengeFixture(
      rankingGroupId: 'weekly_test',
      validUntilUtc: DateTime.utc(2026, 9, 8),
    );

    final ChallengeOfficialSessionStartReport report =
        await ChallengeOfficialSessionService.start(
      challenge: challenge,
      participationEnabled: true,
      launchId: 'launch_test_1',
      gateway: gateway,
    );

    expect(report.wasStarted, isTrue);
    expect(report.session?.sessionId, 'cs_test_001');
    expect(gateway.received?.challengeId, challenge.id);
    expect(
      gateway.received?.competitiveSignature,
      challenge.competitiveSignature,
    );
  });

  test('ne contacte pas le serveur après refus du classement', () async {
    final _FakeSessionGateway gateway = _FakeSessionGateway(now: now);

    final ChallengeOfficialSessionStartReport report =
        await ChallengeOfficialSessionService.start(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      participationEnabled: false,
      launchId: 'launch_test_2',
      gateway: gateway,
    );

    expect(
      report.status,
      ChallengeOfficialSessionStartStatus.ignoredOptedOut,
    );
    expect(gateway.received, isNull);
  });

  test('refuse une réponse correspondant à un autre défi', () async {
    final ChallengeOfficialSessionGateway gateway = _WrongSessionGateway(now);

    final ChallengeOfficialSessionStartReport report =
        await ChallengeOfficialSessionService.start(
      challenge: challengeFixture(rankingGroupId: 'weekly_test'),
      participationEnabled: true,
      launchId: 'launch_test_3',
      gateway: gateway,
    );

    expect(report.status, ChallengeOfficialSessionStartStatus.serverRejected);
    expect(report.session, isNull);
  });

  test('décode et contrôle les dates renvoyées par Firebase', () {
    final ChallengeOfficialSession session =
        ChallengeOfficialSession.fromJson(<String, dynamic>{
      'apiVersion': 1,
      'sessionId': 'cs_test_004',
      'challengeId': 'weekly_test',
      'rankingGroupId': 'weekly_test',
      'competitiveSignature': 'signature',
      'startedAtUtc': now.toIso8601String(),
      'expiresAtUtc': now.add(const Duration(minutes: 45)).toIso8601String(),
      'serverNowUtc': now.add(const Duration(seconds: 1)).toIso8601String(),
      'rankingEligible': false,
      'migrationStatus': 'pending_server_validation',
    });

    expect(session.isActiveAtServerTime, isTrue);
    expect(session.rankingEligible, isFalse);
  });
}

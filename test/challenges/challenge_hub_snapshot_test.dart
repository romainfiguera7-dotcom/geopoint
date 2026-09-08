import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_clock.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_hub_service.dart';
import 'package:geopoint/challenges/challenge_pack.dart';
import 'package:geopoint/challenges/challenge_pack_validator.dart';
import 'package:geopoint/challenges/challenge_player_state.dart';

import 'challenge_test_factory.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 4, 12);

  ChallengeHubSnapshot snapshotWith({
    required List<ChallengeDefinition> challenges,
    ChallengePlayerState playerState = const ChallengePlayerState(),
  }) {
    return ChallengeHubSnapshot(
      pack: ChallengePack(
        schemaVersion: 1,
        id: 'test_pack',
        title: 'Pack test',
        monthKey: '2026-09',
        validFromUtc: DateTime.utc(2026, 9),
        validUntilUtc: DateTime.utc(2026, 10),
        challenges: challenges,
      ),
      playerState: playerState,
      clock: ChallengeClock.evaluate(deviceNow: now, serverNow: now),
      activeChallenges: challenges,
      validationIssues: const <ChallengeValidationIssue>[],
    );
  }

  test('classe les défis actifs selon leur période', () {
    final ChallengeDefinition daily = challengeFixture(id: 'daily');
    final ChallengeDefinition weekly = challengeFixture(
      id: 'weekly',
      period: ChallengePeriod.weekly,
    );
    final ChallengeDefinition monthly = challengeFixture(
      id: 'monthly',
      period: ChallengePeriod.monthly,
    );
    final ChallengeDefinition permanent = challengeFixture(
      id: 'permanent',
      period: ChallengePeriod.permanent,
    );
    final ChallengeHubSnapshot snapshot = snapshotWith(
      challenges: <ChallengeDefinition>[daily, weekly, monthly, permanent],
    );

    expect(snapshot.dailyChallenge, same(daily));
    expect(snapshot.challengesFor(ChallengePeriod.weekly), <Object>[weekly]);
    expect(snapshot.challengesFor(ChallengePeriod.monthly), <Object>[monthly]);
    expect(
      snapshot.challengesFor(ChallengePeriod.permanent),
      <Object>[permanent],
    );
  });

  test('l’historique récent contient uniquement les défis terminés', () {
    final ChallengeDefinition completed = challengeFixture(id: 'completed');
    final ChallengeDefinition active = challengeFixture(id: 'active');
    final ChallengePlayerState state = ChallengePlayerState.initial()
        .registerAttempt(
          challengeId: completed.id,
          score: 400,
          correctAnswers: 5,
          succeeded: true,
          playedAt: now,
        );
    final ChallengeHubSnapshot snapshot = snapshotWith(
      challenges: <ChallengeDefinition>[completed, active],
      playerState: state,
    );

    expect(snapshot.recentlyCompletedChallenges, <Object>[completed]);
  });

  test('l’historique ignore les définitions réservées aux enfants', () {
    final ChallengeDefinition child = challengeFixture(
      id: 'daily__child',
      audience: ChallengeAudience.child,
    );
    final ChallengePlayerState state = ChallengePlayerState.initial()
        .registerAttempt(
          challengeId: child.id,
          score: 400,
          correctAnswers: 5,
          succeeded: true,
          playedAt: now,
        );
    final ChallengeHubSnapshot snapshot = snapshotWith(
      challenges: <ChallengeDefinition>[child],
      playerState: state,
    );

    expect(snapshot.recentlyCompletedChallenges, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_clock.dart';

void main() {
  test('l’heure serveur devient la référence de confiance', () {
    final ChallengeClockEvaluation result = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 4, 12, 3),
      serverNow: DateTime.utc(2026, 9, 4, 12),
    );

    expect(result.source, ChallengeClockSource.server);
    expect(result.effectiveNowUtc, DateTime.utc(2026, 9, 4, 12));
    expect(result.canStartChallenge, isTrue);
    expect(result.canClaimReward, isTrue);
    expect(result.requiresServerValidation, isFalse);
  });

  test('hors ligne le temps avance depuis la dernière heure serveur', () {
    final ChallengeClockEvaluation trusted = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 4, 12),
      serverNow: DateTime.utc(2026, 9, 4, 11, 58),
    );
    final ChallengeClockEvaluation offline = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 4, 14),
      previousState: trusted.updatedState,
    );

    expect(offline.source, ChallengeClockSource.offlineEstimate);
    expect(offline.effectiveNowUtc, DateTime.utc(2026, 9, 4, 13, 58));
    expect(offline.requiresServerValidation, isTrue);
  });

  test('un recul important de l’heure bloque le défi et la récompense', () {
    final ChallengeClockEvaluation trusted = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 4, 12),
      serverNow: DateTime.utc(2026, 9, 4, 12),
    );
    final ChallengeClockEvaluation rollback = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 3, 12),
      previousState: trusted.updatedState,
    );

    expect(rollback.source, ChallengeClockSource.blockedRollback);
    expect(rollback.canStartChallenge, isFalse);
    expect(rollback.canClaimReward, isFalse);
    expect(rollback.requiresServerValidation, isTrue);
  });

  test('une variation inférieure à cinq minutes reste tolérée', () {
    final ChallengeClockEvaluation trusted = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 4, 12),
      serverNow: DateTime.utc(2026, 9, 4, 12),
    );
    final ChallengeClockEvaluation result = ChallengeClock.evaluate(
      deviceNow: DateTime.utc(2026, 9, 4, 11, 57),
      previousState: trusted.updatedState,
    );

    expect(result.source, ChallengeClockSource.offlineEstimate);
    expect(result.canStartChallenge, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_pack.dart';
import 'package:geopoint/challenges/challenge_pack_validator.dart';

import 'challenge_test_factory.dart';

void main() {
  ChallengePack packWith(List<ChallengeDefinition> challenges) {
    return ChallengePack(
      schemaVersion: ChallengePack.currentSchemaVersion,
      id: 'test_pack',
      title: 'Pack de test',
      monthKey: '2026-09',
      validFromUtc: DateTime.utc(2026, 9),
      validUntilUtc: DateTime.utc(2026, 10),
      challenges: challenges,
    );
  }

  final ChallengePackValidationContext context =
      const ChallengePackValidationContext(
    countryIds: <String>{'FRA', 'ESP'},
  );

  test('refuse un pays absent des données géographiques', () {
    final ChallengeDefinition challenge = challengeFixture(
      continentId: null,
      countryIds: const <String>['XXX'],
    );
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      packWith(<ChallengeDefinition>[challenge]),
      context: context,
    );

    expect(
      issues.map((ChallengeValidationIssue issue) => issue.code),
      contains('unknown_country'),
    );
  });

  test('refuse GeoBrain dans un défi classé', () {
    final ChallengeDefinition challenge = challengeFixture(
      rankingGroupId: 'ranking_1',
      geoBrainPersonalizationAllowed: true,
    );
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      packWith(<ChallengeDefinition>[challenge]),
      context: context,
    );

    expect(
      issues.map((ChallengeValidationIssue issue) => issue.code),
      contains('ranked_geobrain_forbidden'),
    );
  });

  test('refuse deux règles différentes dans le même classement', () {
    final ChallengeDefinition first = challengeFixture(
      id: 'ranked_a',
      rankingGroupId: 'ranking_1',
    );
    final ChallengeDefinition second = challengeFixture(
      id: 'ranked_b',
      rankingGroupId: 'ranking_1',
      questionCount: 10,
    );
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      packWith(<ChallengeDefinition>[first, second]),
      context: context,
    );

    expect(
      issues.map((ChallengeValidationIssue issue) => issue.code),
      contains('unequal_ranked_rules'),
    );
  });

  test('refuse toute publicité dans une variante enfant', () {
    final ChallengeDefinition child = challengeFixture(
      audience: ChallengeAudience.child,
      retryPolicy: const ChallengeRetryPolicy(
        maximumAttempts: 1,
        rewardedAdvertisementAllowed: true,
        maximumRewardedAdvertisementRetries: 1,
      ),
    );
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      packWith(<ChallengeDefinition>[child]),
      context: context,
    );

    expect(
      issues.map((ChallengeValidationIssue issue) => issue.code),
      contains('child_advertisement_forbidden'),
    );
  });

  test('refuse deux défis du même rythme actifs en même temps', () {
    final ChallengeDefinition first = challengeFixture(id: 'daily_a');
    final ChallengeDefinition second = challengeFixture(
      id: 'daily_b',
      validFromUtc: DateTime.utc(2026, 9, 4, 12),
      validUntilUtc: DateTime.utc(2026, 9, 6),
    );
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      packWith(<ChallengeDefinition>[first, second]),
      context: context,
    );

    expect(
      issues.map((ChallengeValidationIssue issue) => issue.code),
      contains('overlapping_period_challenges'),
    );
  });

  test('accepte une règle publicitaire explicitement illimitée', () {
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      packWith(<ChallengeDefinition>[challengeFixture()]),
      context: context,
    );

    expect(
      issues.map((ChallengeValidationIssue issue) => issue.code),
      isNot(contains('advertisement_retry_missing_limit')),
    );
  });

  test('refuse une variante enfant ayant d’autres dates', () {
    final ChallengeDefinition parent = challengeFixture(
      id: 'parent',
      childVariantId: 'child',
    );
    final ChallengeDefinition child = challengeFixture(
      id: 'child',
      audience: ChallengeAudience.child,
      validFromUtc: DateTime.utc(2026, 9, 5),
      validUntilUtc: DateTime.utc(2026, 9, 6),
    );
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      packWith(<ChallengeDefinition>[parent, child]),
      context: context,
    );

    expect(
      issues.map((ChallengeValidationIssue issue) => issue.code),
      contains('child_variant_period_mismatch'),
    );
  });
}

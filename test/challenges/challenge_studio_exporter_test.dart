import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_studio_draft.dart';
import 'package:geopoint/challenges/challenge_studio_exporter.dart';

void main() {
  ChallengeStudioDraft draft({
    required String id,
    required ChallengePeriod period,
    required DateTime start,
    required DateTime end,
  }) {
    return ChallengeStudioDraft(
      id: id,
      period: period,
      title: 'Défi $id',
      description: 'Configuration de test.',
      validFromUtc: start,
      validUntilUtc: end,
      modeId: 'find_country',
      difficultyId: 'easy',
      continentId: 'world',
      countryIds: const <String>[],
      questionCount: 5,
      minimumCorrectAnswers: 3,
      minimumScore: 0,
      rewardXp: 100,
      rewardCoins: 25,
      rewardDiamonds: 0,
      progressionPoints: 1,
      ranked: false,
      geoBrainPersonalizationAllowed: true,
    );
  }

  test('exporte les trois rythmes avec leurs variantes enfant', () {
    final ChallengeStudioExport export = ChallengeStudioExporter.build(
      drafts: <ChallengeStudioDraft>[
        draft(
          id: 'daily_1',
          period: ChallengePeriod.daily,
          start: DateTime.utc(2026, 9, 4),
          end: DateTime.utc(2026, 9, 5),
        ),
        draft(
          id: 'weekly_1',
          period: ChallengePeriod.weekly,
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 8),
        ),
        draft(
          id: 'monthly_1',
          period: ChallengePeriod.monthly,
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 10, 1),
        ),
      ],
      countryIds: const <String>{'FRA'},
    );

    expect(export.isValid, isTrue);
    expect(export.pack.challenges, hasLength(6));
    expect(jsonDecode(export.json), isA<Map<String, dynamic>>());
  });

  test('refuse deux défis quotidiens qui se chevauchent', () {
    final ChallengeStudioExport export = ChallengeStudioExporter.build(
      drafts: <ChallengeStudioDraft>[
        draft(
          id: 'daily_a',
          period: ChallengePeriod.daily,
          start: DateTime.utc(2026, 9, 4),
          end: DateTime.utc(2026, 9, 5),
        ),
        draft(
          id: 'daily_b',
          period: ChallengePeriod.daily,
          start: DateTime.utc(2026, 9, 4, 12),
          end: DateTime.utc(2026, 9, 5, 12),
        ),
      ],
      countryIds: const <String>{'FRA'},
    );

    expect(export.isValid, isFalse);
    expect(
      export.issues.map((issue) => issue.code),
      contains('overlapping_period_challenges'),
    );
  });
}

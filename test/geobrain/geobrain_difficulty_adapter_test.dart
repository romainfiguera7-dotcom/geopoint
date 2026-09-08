import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_difficulty_adapter.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';

void main() {
  final DateTime start = DateTime.utc(2026, 8, 30, 12);

  GeoBrainAttempt attempt({
    required int index,
    required String difficultyId,
    bool isCorrect = true,
    String? helpId,
    GeoBrainAttemptContext context = GeoBrainAttemptContext.training,
  }) {
    return GeoBrainAttempt(
      countryId: 'FRA',
      theme: GeoBrainTheme.location,
      answeredAt: start.add(Duration(minutes: index)),
      modeId: 'find_country',
      difficultyId: difficultyId,
      isCorrect: isCorrect,
      helpId: helpId,
      context: context,
    );
  }

  const GeoBrainDifficultyAdapter adapter = GeoBrainDifficultyAdapter();

  test('un nouveau joueur commence au niveau facile', () {
    final GeoBrainDifficultyRecommendation result = adapter.recommend(
      attempts: const <GeoBrainAttempt>[],
    );

    expect(result.difficultyId, 'easy');
    expect(result.reason, GeoBrainAdaptiveReason.newPlayer);
    expect(result.analyzedAttemptCount, 0);
  });

  test('une seule réussite ne suffit pas à augmenter la difficulté', () {
    final GeoBrainDifficultyRecommendation result = adapter.recommend(
      attempts: <GeoBrainAttempt>[
        for (int index = 0; index < 5; index++)
          attempt(index: index, difficultyId: 'intermediate'),
      ],
    );

    expect(result.difficultyId, 'easy');
    expect(result.reason, GeoBrainAdaptiveReason.newPlayer);
  });

  test('des réussites régulières réduisent les aides d’un seul palier', () {
    final GeoBrainDifficultyRecommendation result = adapter.recommend(
      attempts: <GeoBrainAttempt>[
        for (int index = 0; index < 8; index++)
          attempt(index: index, difficultyId: 'intermediate'),
      ],
    );

    expect(result.difficultyId, 'hard');
    expect(result.reason, GeoBrainAdaptiveReason.strongResults);
    expect(result.usesContinentalTargeting, isFalse);
  });

  test('trois erreurs récentes rendent la séance temporairement accessible',
      () {
    final GeoBrainDifficultyRecommendation result = adapter.recommend(
      attempts: <GeoBrainAttempt>[
        for (int index = 0; index < 5; index++)
          attempt(index: index, difficultyId: 'hard'),
        for (int index = 5; index < 8; index++)
          attempt(
            index: index,
            difficultyId: 'hard',
            isCorrect: false,
          ),
      ],
    );

    expect(result.difficultyId, 'intermediate');
    expect(result.reason, GeoBrainAdaptiveReason.recentStruggles);
  });

  test('les réussites assistées ne font pas monter le niveau', () {
    final GeoBrainDifficultyRecommendation result = adapter.recommend(
      attempts: <GeoBrainAttempt>[
        for (int index = 0; index < 8; index++)
          attempt(
            index: index,
            difficultyId: 'intermediate',
            helpId: 'continent_hint',
          ),
      ],
    );

    expect(result.difficultyId, 'easy');
    expect(result.weightedAccuracy, closeTo(0.45, 0.001));
  });

  test('les tutoriels et le mode enfant sont exclus de la recommandation', () {
    final GeoBrainDifficultyRecommendation result = adapter.recommend(
      attempts: <GeoBrainAttempt>[
        for (int index = 0; index < 6; index++)
          attempt(
            index: index,
            difficultyId: 'expert',
            context: GeoBrainAttemptContext.tutorial,
          ),
        for (int index = 6; index < 12; index++)
          attempt(
            index: index,
            difficultyId: 'expert',
            context: GeoBrainAttemptContext.childMode,
          ),
      ],
    );

    expect(result.difficultyId, 'easy');
    expect(result.analyzedAttemptCount, 0);
  });

  test('seules les douze réponses les plus récentes déterminent le niveau', () {
    final GeoBrainDifficultyRecommendation result = adapter.recommend(
      attempts: <GeoBrainAttempt>[
        for (int index = 0; index < 10; index++)
          attempt(
            index: index,
            difficultyId: 'easy',
            isCorrect: false,
          ),
        for (int index = 10; index < 22; index++)
          attempt(index: index, difficultyId: 'intermediate'),
      ],
    );

    expect(result.difficultyId, 'hard');
    expect(result.analyzedAttemptCount, 12);
  });

  test('la précision des capitales augmente avec le niveau annoncé', () {
    const GeoBrainDifficultyRecommendation easy =
        GeoBrainDifficultyRecommendation(
      difficultyId: 'easy',
      reason: GeoBrainAdaptiveReason.newPlayer,
      analyzedAttemptCount: 0,
      weightedAccuracy: 0,
    );
    const GeoBrainDifficultyRecommendation expert =
        GeoBrainDifficultyRecommendation(
      difficultyId: 'expert',
      reason: GeoBrainAdaptiveReason.strongResults,
      analyzedAttemptCount: 12,
      weightedAccuracy: 1,
    );

    expect(easy.capitalPrecisionInKilometers, 220);
    expect(easy.usesContinentalTargeting, isTrue);
    expect(expert.capitalPrecisionInKilometers, 50);
    expect(expert.usesContinentalTargeting, isFalse);
    expect(
      expert.rulesSummary(theme: GeoBrainTheme.capital),
      contains('précision 50 km'),
    );
  });
}

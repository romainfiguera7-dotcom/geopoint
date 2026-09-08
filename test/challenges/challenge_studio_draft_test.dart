import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_studio_draft.dart';

void main() {
  ChallengeStudioDraft fixture({
    String id = 'daily_studio_test',
    ChallengePeriod period = ChallengePeriod.daily,
    DateTime? validFromUtc,
    DateTime? validUntilUtc,
  }) {
    return ChallengeStudioDraft(
      id: id,
      period: period,
      title: 'Test Studio',
      description: 'Un défi créé dans le Studio.',
      validFromUtc: validFromUtc ?? DateTime.utc(2026, 9, 4),
      validUntilUtc: validUntilUtc ?? DateTime.utc(2026, 9, 5),
      modeId: 'find_country',
      difficultyId: 'intermediate',
      continentId: 'europe',
      countryIds: const <String>[],
      questionCount: 10,
      minimumCorrectAnswers: 8,
      minimumScore: 1000,
      rewardXp: 150,
      rewardCoins: 40,
      rewardDiamonds: 0,
      progressionPoints: 1,
      ranked: false,
      geoBrainPersonalizationAllowed: true,
    );
  }

  test('conserve toutes les informations après sérialisation', () {
    final ChallengeStudioDraft source = fixture();
    final ChallengeStudioDraft restored =
        ChallengeStudioDraft.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.period, source.period);
    expect(restored.validFromUtc, source.validFromUtc);
    expect(restored.questionCount, 10);
    expect(restored.rewardXp, 150);
    expect(restored.ranked, isTrue);
    expect(restored.geoBrainPersonalizationAllowed, isFalse);
    expect(restored.minimumPlayerLevel, 1);
  });

  test('génère une relance adulte illimitée par publicité', () {
    final ChallengeDefinition standard = fixture().toDefinitions().first;

    expect(standard.audience, ChallengeAudience.standard);
    expect(standard.retryPolicy.maximumAttempts, 1);
    expect(standard.retryPolicy.rewardedAdvertisementAllowed, isTrue);
    expect(standard.isRanked, isTrue);
    expect(standard.minimumPlayerLevel, 1);
    expect(
      standard.retryPolicy.unlimitedRewardedAdvertisementRetries,
      isTrue,
    );
    expect(standard.childVariantId, '${standard.id}__child');
  });

  test('génère une variante enfant sans aucune publicité', () {
    final ChallengeDefinition child = fixture().toDefinitions().last;

    expect(child.audience, ChallengeAudience.child);
    expect(child.retryPolicy.unlimitedFreeAttempts, isTrue);
    expect(child.retryPolicy.rewardedAdvertisementAllowed, isFalse);
    expect(child.retryPolicy.childAdvertisementsAllowed, isFalse);
    expect(child.rankingGroupId, isNull);
    expect(child.successCondition.minimumCorrectAnswers, 6);
  });

  test('désactive toujours GeoBrain pour un défi adulte classé', () {
    final ChallengeDefinition standard =
        fixture().toDefinitions().first;

    expect(standard.isRanked, isTrue);
    expect(standard.geoBrainPersonalizationAllowed, isFalse);
  });

  test('conserve la désactivation dans le JSON et les variantes', () {
    final ChallengeStudioDraft disabled = fixture().copyWith(disabled: true);
    final ChallengeStudioDraft restored =
        ChallengeStudioDraft.fromJson(disabled.toJson());

    expect(restored.disabled, isTrue);
    expect(
      restored.toDefinitions().every(
        (ChallengeDefinition challenge) => challenge.disabled,
      ),
      isTrue,
    );
  });

  test('supprime le verrou XP et la variante débutant', () {
    final List<ChallengeDefinition> definitions = fixture()
        .copyWith(minimumPlayerLevel: 12)
        .toDefinitions();
    final ChallengeDefinition standard = definitions.first;

    expect(standard.minimumPlayerLevel, 1);
    expect(standard.beginnerVariantId, isNull);
    expect(
      definitions.where(
        (ChallengeDefinition challenge) =>
            challenge.audience == ChallengeAudience.beginner,
      ),
      isEmpty,
    );
  });
}

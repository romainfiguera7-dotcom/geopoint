import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_forgetting_calculator.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';

void main() {
  final DateTime start = DateTime.utc(2026, 1, 1, 12);

  GeoBrainAttempt attempt({
    required bool isCorrect,
    required DateTime answeredAt,
    String countryId = 'FRA',
  }) {
    return GeoBrainAttempt(
      countryId: countryId,
      theme: GeoBrainTheme.location,
      answeredAt: answeredAt,
      modeId: 'find_country',
      difficultyId: 'intermediate',
      isCorrect: isCorrect,
      context: GeoBrainAttemptContext.classicGame,
    );
  }

  CountryMastery learnedCountry({
    String countryId = 'FRA',
    DateTime? learningStart,
  }) {
    final DateTime resolvedStart = learningStart ?? start;
    CountryMastery mastery = CountryMastery.initial(countryId);
    for (int index = 0; index < 10; index++) {
      mastery = mastery.registerAttempt(
        attempt(
          isCorrect: true,
          answeredAt: resolvedStart.add(Duration(days: index)),
          countryId: countryId,
        ),
      );
    }
    return mastery;
  }

  test('un nouveau joueur ne possède aucune connaissance oubliée', () {
    final CountryMastery mastery = CountryMastery.initial('FRA');

    expect(mastery.needsReviewAt(start), isFalse);
    expect(mastery.themesToReviewAt(start), isEmpty);
    expect(mastery.reviewLabelAt(start), 'À jour');
  });

  test('un joueur régulier conserve sa maîtrise avant la date prévue', () {
    final CountryMastery mastery = learnedCountry();
    final DateTime beforeReview = mastery.nextReviewAt!.subtract(
      const Duration(hours: 1),
    );

    expect(mastery.status, GeoBrainMasteryStatus.mastered);
    expect(mastery.statusAt(beforeReview), GeoBrainMasteryStatus.mastered);
    expect(mastery.needsReviewAt(beforeReview), isFalse);
    expect(
      mastery.retainedGeneralScoreAt(beforeReview),
      closeTo(mastery.generalScore, 0.0001),
    );
  });

  test('le retour après plusieurs semaines fait baisser doucement la confiance',
      () {
    final CountryMastery mastery = learnedCountry();
    final DateTime lastAnswer = start.add(const Duration(days: 9));
    final double afterTwoMonths = mastery.retainedGeneralScoreAt(
      lastAnswer.add(const Duration(days: 60)),
    );
    final double afterFourMonths = mastery.retainedGeneralScoreAt(
      lastAnswer.add(const Duration(days: 120)),
    );

    expect(afterTwoMonths, lessThan(mastery.generalScore));
    expect(afterFourMonths, lessThan(afterTwoMonths));
    expect(afterFourMonths, greaterThan(0));
    expect(mastery.generalScore, greaterThanOrEqualTo(80));
    expect(
      mastery.reviewLabelAt(lastAnswer.add(const Duration(days: 60))),
      'À réviser',
    );
  });

  test('la baisse de confiance possède un plancher et ne supprime pas les acquis',
      () {
    final CountryMastery mastery = learnedCountry();
    final DateTime lastAnswer = start.add(const Duration(days: 9));
    final double retained = mastery.retainedGeneralScoreAt(
      lastAnswer.add(const Duration(days: 500)),
    );

    expect(retained, closeTo(mastery.generalScore * 0.65, 0.0001));
    expect(retained, greaterThan(0));
    expect(
      mastery.statusAt(lastAnswer.add(const Duration(days: 500))),
      isNot(GeoBrainMasteryStatus.unknown),
    );
    expect(mastery.generalScore, greaterThanOrEqualTo(80));
  });

  test('une erreur occasionnelle ne devient pas un oubli répété', () {
    CountryMastery mastery = learnedCountry();
    final DateTime errorDate = start.add(const Duration(days: 10));
    mastery = mastery.registerAttempt(
      attempt(isCorrect: false, answeredAt: errorDate),
    );
    final GeoBrainForgettingEvaluation retention = mastery.retentionForTheme(
      GeoBrainTheme.location,
      errorDate,
    );

    expect(retention.isOccasionalError, isTrue);
    expect(retention.isRepeatedForgetting, isFalse);
  });

  test('plusieurs erreurs récentes signalent positivement une révision', () {
    CountryMastery mastery = learnedCountry();
    final DateTime firstError = start.add(const Duration(days: 10));
    mastery = mastery.registerAttempt(
      attempt(isCorrect: false, answeredAt: firstError),
    );
    mastery = mastery.registerAttempt(
      attempt(
        isCorrect: false,
        answeredAt: firstError.add(const Duration(minutes: 1)),
      ),
    );
    final DateTime evaluationDate = firstError.add(const Duration(minutes: 1));
    final GeoBrainForgettingEvaluation retention = mastery.retentionForTheme(
      GeoBrainTheme.location,
      evaluationDate,
    );

    expect(retention.isRepeatedForgetting, isTrue);
    expect(retention.state, GeoBrainRetentionState.repeatedForgetting);
    expect(retention.playerLabel, 'À réviser');
    expect(mastery.hasRepeatedForgettingAt(evaluationDate), isTrue);
    expect(mastery.reviewLabelAt(evaluationDate), 'À réviser');
  });

  test('le profil ne propose que les pays réellement arrivés à révision', () {
    final DateTime evaluationDate = start.add(const Duration(days: 100));
    final CountryMastery oldLearning = learnedCountry();
    final CountryMastery freshLearning = learnedCountry(
      countryId: 'JPN',
      learningStart: start.add(const Duration(days: 91)),
    );
    final GeoBrainProfile profile = GeoBrainProfile(
      schemaVersion: GeoBrainProfile.currentSchemaVersion,
      countries: <String, CountryMastery>{
        'FRA': oldLearning,
        'JPN': freshLearning,
      },
      createdAt: start,
      updatedAt: evaluationDate,
    );

    expect(
      profile
          .countriesDueForReviewAt(evaluationDate)
          .map<String>((CountryMastery mastery) => mastery.countryId),
      <String>['FRA'],
    );
    expect(profile.reviewCountryCountAt(evaluationDate), 1);
  });
}

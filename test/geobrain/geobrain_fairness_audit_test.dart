import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_difficulty_adapter.dart';
import 'package:geopoint/geobrain/geobrain_forgetting_calculator.dart';
import 'package:geopoint/geobrain/geobrain_mastery_calculator.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/geobrain/geobrain_training_suggestion.dart';
import 'package:geopoint/geobrain/theme_mastery.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 31, 12);

  GeoBrainAttempt attempt({
    required String countryId,
    required DateTime answeredAt,
    required bool isCorrect,
    double? distanceInKilometers,
    String difficultyId = 'intermediate',
    GeoBrainAttemptContext context = GeoBrainAttemptContext.classicGame,
    String? helpId,
  }) {
    return GeoBrainAttempt(
      countryId: countryId,
      theme: GeoBrainTheme.location,
      answeredAt: answeredAt,
      modeId: 'find_country',
      difficultyId: difficultyId,
      isCorrect: isCorrect,
      distanceInKilometers: distanceInKilometers,
      helpId: helpId,
      context: context,
    );
  }

  List<GeoBrainAttempt> successes({
    required String countryId,
    int count = 10,
    double? distanceInKilometers,
    String difficultyId = 'intermediate',
    GeoBrainAttemptContext context = GeoBrainAttemptContext.classicGame,
    String? helpId,
  }) {
    return List<GeoBrainAttempt>.generate(
      count,
      (int index) => attempt(
        countryId: countryId,
        answeredAt: now.subtract(Duration(hours: index * 18)),
        isCorrect: true,
        distanceInKilometers: distanceInKilometers,
        difficultyId: difficultyId,
        context: context,
        helpId: helpId,
      ),
    );
  }

  CountryMastery masteryFrom(List<GeoBrainAttempt> attempts) {
    CountryMastery mastery = CountryMastery.initial(attempts.first.countryId);
    final List<GeoBrainAttempt> ordered = attempts.toList()
      ..sort(
        (GeoBrainAttempt first, GeoBrainAttempt second) =>
            first.answeredAt.compareTo(second.answeredAt),
      );
    for (final GeoBrainAttempt value in ordered) {
      mastery = mastery.registerAttempt(value);
    }
    return mastery;
  }

  GeoBrainProfile profileFor(CountryMastery mastery) {
    return GeoBrainProfile(
      schemaVersion: GeoBrainProfile.currentSchemaVersion,
      countries: <String, CountryMastery>{mastery.countryId: mastery},
      createdAt: now.subtract(const Duration(days: 120)),
      updatedAt: now,
    );
  }

  test('un petit pays n’est pas pénalisé par sa taille ou la distance enregistrée',
      () {
    final GeoBrainMasteryEvaluation france =
        const GeoBrainMasteryCalculator().evaluate(
      attempts: successes(
        countryId: 'FRA',
        distanceInKilometers: 4,
      ),
      now: now,
    );
    final GeoBrainMasteryEvaluation sanMarino =
        const GeoBrainMasteryCalculator().evaluate(
      attempts: successes(
        countryId: 'SMR',
        distanceInKilometers: 85,
      ),
      now: now,
    );

    expect(sanMarino.score, closeTo(france.score, 0.0001));
    expect(sanMarino.weightedAccuracy, france.weightedAccuracy);
    expect(sanMarino.effectiveAttemptWeight, france.effectiveAttemptWeight);
  });

  test('les seuils de maîtrise sont strictement communs à tous les pays', () {
    final CountryMastery france = masteryFrom(successes(countryId: 'FRA'));
    final CountryMastery sanMarino = masteryFrom(successes(countryId: 'SMR'));

    expect(sanMarino.generalScore, closeTo(france.generalScore, 0.0001));
    expect(sanMarino.status, france.status);
    expect(sanMarino.masteryLevel, france.masteryLevel);
  });

  test('les aides enfant font progresser sans créer une fausse maîtrise', () {
    final GeoBrainMasteryEvaluation autonomous =
        const GeoBrainMasteryCalculator().evaluate(
      attempts: successes(countryId: 'FRA', count: 12),
      now: now,
    );
    final GeoBrainMasteryEvaluation childAssisted =
        const GeoBrainMasteryCalculator().evaluate(
      attempts: successes(
        countryId: 'FRA',
        count: 12,
        difficultyId: 'discovery',
        context: GeoBrainAttemptContext.childMode,
        helpId: 'guided_target',
      ),
      now: now,
    );
    final GeoBrainMasteryStatus childStatus = ThemeMastery.statusFor(
      score: childAssisted.score,
      totalAttempts: 12,
    );

    expect(childAssisted.score, greaterThan(0));
    expect(childAssisted.score, lessThan(autonomous.score / 2));
    expect(childStatus, isNot(GeoBrainMasteryStatus.mastered));
  });

  test('une erreur en mode enfant reste informative malgré les aides', () {
    final List<GeoBrainAttempt> learned = successes(
      countryId: 'FRA',
      count: 12,
      difficultyId: 'discovery',
      context: GeoBrainAttemptContext.childMode,
      helpId: 'guided_target',
    );
    final GeoBrainMasteryEvaluation beforeError =
        const GeoBrainMasteryCalculator().evaluate(
      attempts: learned,
      now: now,
    );
    final GeoBrainMasteryEvaluation afterErrors =
        const GeoBrainMasteryCalculator().evaluate(
      attempts: <GeoBrainAttempt>[
        ...learned,
        attempt(
          countryId: 'FRA',
          answeredAt: now.add(const Duration(minutes: 1)),
          isCorrect: false,
          difficultyId: 'discovery',
          context: GeoBrainAttemptContext.childMode,
          helpId: 'guided_target',
        ),
        attempt(
          countryId: 'FRA',
          answeredAt: now.add(const Duration(minutes: 2)),
          isCorrect: false,
          difficultyId: 'discovery',
          context: GeoBrainAttemptContext.childMode,
          helpId: 'guided_target',
        ),
      ],
      now: now.add(const Duration(minutes: 2)),
    );

    expect(afterErrors.effectiveAttemptWeight,
        greaterThan(beforeError.effectiveAttemptWeight));
    expect(afterErrors.recentErrorPenalty, greaterThan(0));
    expect(afterErrors.score, lessThan(beforeError.score));
  });

  test('le mode enfant ne force jamais une hausse de difficulté adulte', () {
    final GeoBrainDifficultyRecommendation recommendation =
        const GeoBrainDifficultyAdapter().recommend(
      attempts: successes(
        countryId: 'FRA',
        count: 20,
        difficultyId: 'expert',
        context: GeoBrainAttemptContext.childMode,
      ),
    );

    expect(recommendation.difficultyId, 'easy');
    expect(recommendation.reason, GeoBrainAdaptiveReason.newPlayer);
    expect(recommendation.analyzedAttemptCount, 0);
  });

  test('huit preuves restent nécessaires avant le statut Maîtrisé', () {
    expect(
      ThemeMastery.statusFor(score: 95, totalAttempts: 7),
      GeoBrainMasteryStatus.acquired,
    );
    expect(
      ThemeMastery.statusFor(score: 95, totalAttempts: 8),
      GeoBrainMasteryStatus.mastered,
    );
  });

  test('un acquis stable n’est suggéré qu’au moment où sa révision devient utile',
      () {
    final CountryMastery mastery = masteryFrom(successes(countryId: 'FRA'));
    final GeoBrainProfile profile = profileFor(mastery);
    final List<GeoCountry> catalog = <GeoCountry>[
      GeoCountry(
        id: 'FRA',
        isoA2: 'FR',
        name: 'France',
        continent: 'Europe',
        polygons: const [],
      ),
    ];
    final List<GeoBrainTrainingSuggestion> whileStable =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: profile,
      countries: catalog,
      now: now,
    );
    final DateTime returnDate = now.add(const Duration(days: 90));
    final List<GeoBrainTrainingSuggestion> afterAbsence =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: profile,
      countries: catalog,
      now: returnDate,
    );
    final GeoBrainForgettingEvaluation retention = mastery.retentionForTheme(
      GeoBrainTheme.location,
      returnDate,
    );

    expect(whileStable, isEmpty);
    expect(afterAbsence.single.id, 'review_priorities');
    expect(afterAbsence.single.countryIds, <String>{'FRA'});
    expect(retention.retainedScore, greaterThan(0));
    expect(retention.playerLabel, 'À réviser');
    expect(retention.playerLabel, isNot(contains('Perdu')));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_mastery_calculator.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/geobrain/theme_mastery.dart';

void main() {
  const GeoBrainMasteryCalculator calculator = GeoBrainMasteryCalculator();
  final DateTime now = DateTime.utc(2026, 8, 29, 12);

  GeoBrainAttempt attempt({
    required bool isCorrect,
    required DateTime answeredAt,
    String countryId = 'FRA',
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
      helpId: helpId,
      context: context,
    );
  }

  List<GeoBrainAttempt> successes({
    required int count,
    required bool spreadAcrossDays,
    String countryId = 'FRA',
    String difficultyId = 'intermediate',
    GeoBrainAttemptContext context = GeoBrainAttemptContext.classicGame,
    String? helpId,
  }) {
    return List<GeoBrainAttempt>.generate(count, (int index) {
      final DateTime answeredAt = spreadAcrossDays
          ? now.subtract(Duration(hours: index * 18))
          : now.subtract(Duration(minutes: index));
      return attempt(
        isCorrect: true,
        answeredAt: answeredAt,
        countryId: countryId,
        difficultyId: difficultyId,
        context: context,
        helpId: helpId,
      );
    });
  }

  test('une seule bonne réponse ne suffit jamais à maîtriser un pays', () {
    final GeoBrainMasteryEvaluation result = calculator.evaluate(
      attempts: <GeoBrainAttempt>[
        attempt(isCorrect: true, answeredAt: now),
      ],
      now: now,
    );

    expect(result.score, lessThan(25));
    expect(
      ThemeMastery.statusFor(score: result.score, totalAttempts: 1),
      GeoBrainMasteryStatus.discovered,
    );
  });

  test('la régularité sur plusieurs jours vaut plus que le volume en une fois',
      () {
    final GeoBrainMasteryEvaluation sameDay = calculator.evaluate(
      attempts: successes(count: 10, spreadAcrossDays: false),
      now: now,
    );
    final GeoBrainMasteryEvaluation regular = calculator.evaluate(
      attempts: successes(count: 10, spreadAcrossDays: true),
      now: now,
    );

    expect(regular.distinctPracticeDays, greaterThanOrEqualTo(4));
    expect(regular.score, greaterThan(sameDay.score + 10));
    expect(regular.score, greaterThanOrEqualTo(80));
  });

  test('les réponses récentes pèsent davantage que les anciennes', () {
    final List<GeoBrainAttempt> oldSuccessesRecentErrors = <GeoBrainAttempt>[
      for (int index = 0; index < 8; index++)
        attempt(
          isCorrect: true,
          answeredAt: now.subtract(Duration(days: 100 + index)),
        ),
      attempt(
        isCorrect: false,
        answeredAt: now.subtract(const Duration(days: 1)),
      ),
      attempt(isCorrect: false, answeredAt: now),
    ];
    final List<GeoBrainAttempt> oldErrorsRecentSuccesses = <GeoBrainAttempt>[
      for (int index = 0; index < 2; index++)
        attempt(
          isCorrect: false,
          answeredAt: now.subtract(Duration(days: 100 + index)),
        ),
      for (int index = 0; index < 8; index++)
        attempt(
          isCorrect: true,
          answeredAt: now.subtract(Duration(hours: index * 18)),
        ),
    ];

    final GeoBrainMasteryEvaluation recentErrors = calculator.evaluate(
      attempts: oldSuccessesRecentErrors,
      now: now,
    );
    final GeoBrainMasteryEvaluation recentSuccesses = calculator.evaluate(
      attempts: oldErrorsRecentSuccesses,
      now: now,
    );

    expect(recentSuccesses.score, greaterThan(recentErrors.score + 25));
  });

  test('les tutoriels et les aides ont une influence volontairement limitée',
      () {
    final GeoBrainMasteryEvaluation autonomous = calculator.evaluate(
      attempts: successes(count: 12, spreadAcrossDays: true),
      now: now,
    );
    final GeoBrainMasteryEvaluation assisted = calculator.evaluate(
      attempts: successes(
        count: 12,
        spreadAcrossDays: true,
        difficultyId: 'discovery',
        context: GeoBrainAttemptContext.tutorial,
        helpId: 'guided_target',
      ),
      now: now,
    );

    expect(autonomous.score, greaterThanOrEqualTo(80));
    expect(assisted.score, lessThan(40));
    expect(assisted.score, lessThan(autonomous.score / 2));
  });

  test('une erreur isolée est tolérée mais une série fait baisser la confiance',
      () {
    final List<GeoBrainAttempt> learned = successes(
      count: 10,
      spreadAcrossDays: true,
    );
    final GeoBrainMasteryEvaluation mastered = calculator.evaluate(
      attempts: learned,
      now: now,
    );
    final GeoBrainMasteryEvaluation oneError = calculator.evaluate(
      attempts: <GeoBrainAttempt>[
        ...learned,
        attempt(
          isCorrect: false,
          answeredAt: now.add(const Duration(minutes: 1)),
        ),
      ],
      now: now.add(const Duration(minutes: 1)),
    );
    final GeoBrainMasteryEvaluation repeatedErrors = calculator.evaluate(
      attempts: <GeoBrainAttempt>[
        ...learned,
        attempt(
          isCorrect: false,
          answeredAt: now.add(const Duration(minutes: 1)),
        ),
        attempt(
          isCorrect: false,
          answeredAt: now.add(const Duration(minutes: 2)),
        ),
      ],
      now: now.add(const Duration(minutes: 2)),
    );

    expect(mastered.score, greaterThanOrEqualTo(80));
    expect(oneError.score, greaterThanOrEqualTo(80));
    expect(repeatedErrors.score, lessThan(oneError.score - 10));
  });

  test('les mêmes réponses donnent le même score à tous les pays', () {
    CountryMastery france = CountryMastery.initial('FRA');
    CountryMastery japan = CountryMastery.initial('JPN');
    final List<GeoBrainAttempt> franceAttempts = successes(
      count: 9,
      spreadAcrossDays: true,
      countryId: 'FRA',
    );
    final List<GeoBrainAttempt> japanAttempts = successes(
      count: 9,
      spreadAcrossDays: true,
      countryId: 'JPN',
    );
    for (int index = franceAttempts.length - 1; index >= 0; index--) {
      france = france.registerAttempt(franceAttempts[index]);
      japan = japan.registerAttempt(japanAttempts[index]);
    }

    expect(japan.generalScore, closeTo(france.generalScore, 0.0001));
    expect(japan.status, france.status);
  });
}

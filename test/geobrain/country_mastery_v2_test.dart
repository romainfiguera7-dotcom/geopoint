import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';

void main() {
  GeoBrainAttempt attempt({
    required GeoBrainTheme theme,
    required bool isCorrect,
    required DateTime answeredAt,
  }) {
    return GeoBrainAttempt(
      countryId: 'FRA',
      theme: theme,
      answeredAt: answeredAt,
      modeId: theme.id,
      difficultyId: 'intermediate',
      isCorrect: isCorrect,
      context: GeoBrainAttemptContext.classicGame,
    );
  }

  test('chaque thème progresse indépendamment et le détail reste accessible', () {
    final DateTime start = DateTime.utc(2026, 8, 29, 18);
    CountryMastery mastery = CountryMastery.initial('FRA');
    mastery = mastery.registerAttempt(
      attempt(
        theme: GeoBrainTheme.location,
        isCorrect: true,
        answeredAt: start,
      ),
    );
    mastery = mastery.registerAttempt(
      attempt(
        theme: GeoBrainTheme.location,
        isCorrect: true,
        answeredAt: start.add(const Duration(minutes: 1)),
      ),
    );
    mastery = mastery.registerAttempt(
      attempt(
        theme: GeoBrainTheme.flag,
        isCorrect: false,
        answeredAt: start.add(const Duration(minutes: 2)),
      ),
    );

    expect(mastery.totalAttempts, 3);
    expect(mastery.attempts, hasLength(3));
    expect(mastery.masteryForTheme(GeoBrainTheme.location).totalAttempts, 2);
    expect(
      mastery.masteryForTheme(GeoBrainTheme.location).score,
      closeTo(26.05, 0.1),
    );
    expect(mastery.masteryForTheme(GeoBrainTheme.flag).totalAttempts, 1);
    expect(mastery.masteryForTheme(GeoBrainTheme.flag).score, 0);
    expect(mastery.masteryForTheme(GeoBrainTheme.capital).totalAttempts, 0);
    expect(mastery.attemptsForTheme(GeoBrainTheme.location), hasLength(2));
    expect(mastery.generalScore, closeTo(13.02, 0.1));
    expect(mastery.status, GeoBrainMasteryStatus.discovered);
    expect(
      mastery.generalScoreFor(GeoBrainTheme.values),
      closeTo(3.72, 0.1),
    );
  });

  test('une ancienne fiche est migrée sans perdre ses compteurs ni ses listes', () {
    final DateTime reviewedAt = DateTime.utc(2026, 7, 1);
    final CountryMastery migrated = CountryMastery.fromJson(
      <String, dynamic>{
        'countryId': 'FRA',
        'masteryLevel': 5,
        'correctAnswers': 8,
        'wrongAnswers': 2,
        'totalAttempts': 10,
        'currentStreak': 3,
        'bestStreak': 5,
        'lastReviewedAt': reviewedAt.toIso8601String(),
        'nextReviewAt': reviewedAt
            .add(const Duration(days: 45))
            .toIso8601String(),
        'isWishlisted': true,
        'isVisited': false,
      },
    );

    expect(migrated.masteryLevel, 5);
    expect(migrated.correctAnswers, 8);
    expect(migrated.wrongAnswers, 2);
    expect(migrated.totalAttempts, 10);
    expect(migrated.isWishlisted, isTrue);
    expect(migrated.attempts, isEmpty);
    expect(migrated.masteryForTheme(GeoBrainTheme.location).score, 100);
    expect(
      migrated.masteryForTheme(GeoBrainTheme.location).totalAttempts,
      10,
    );
    expect(migrated.status, GeoBrainMasteryStatus.mastered);
  });

  test('une nouvelle réponse après migration ajoute seulement son propre thème',
      () {
    final DateTime reviewedAt = DateTime.utc(2026, 7, 1);
    final CountryMastery migrated = CountryMastery.fromJson(
      <String, dynamic>{
        'countryId': 'FRA',
        'masteryLevel': 3,
        'correctAnswers': 5,
        'wrongAnswers': 2,
        'totalAttempts': 7,
        'currentStreak': 2,
        'bestStreak': 3,
        'lastReviewedAt': reviewedAt.toIso8601String(),
      },
    );
    final CountryMastery updated = migrated.registerAttempt(
      attempt(
        theme: GeoBrainTheme.capital,
        isCorrect: true,
        answeredAt: reviewedAt.add(const Duration(days: 1)),
      ),
    );

    expect(updated.totalAttempts, 8);
    expect(updated.masteryForTheme(GeoBrainTheme.location).totalAttempts, 7);
    expect(updated.masteryForTheme(GeoBrainTheme.capital).totalAttempts, 1);
    expect(updated.attempts, hasLength(1));
  });
}

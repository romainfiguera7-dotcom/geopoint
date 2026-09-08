import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/player/player_statistics.dart';
import 'package:geopoint/player/player_xp_ledger.dart';

void main() {
  test('ventile une partie par thème, continent, pays et période', () {
    final DetailedPlayerStatistics statistics = DetailedPlayerStatistics
        .initial()
        .registerGame(
          modeId: 'mixed',
          difficultyId: 'hard',
          playedAt: DateTime(2026, 8, 29, 18),
          questions: const <QuestionStatisticsResult>[
            QuestionStatisticsResult(
              countryId: 'FRA',
              continentId: 'europe',
              themeId: 'location',
              isCorrect: true,
              elapsedSeconds: 4,
            ),
            QuestionStatisticsResult(
              countryId: 'JPN',
              continentId: 'asia',
              themeId: 'capital',
              isCorrect: false,
              elapsedSeconds: 9,
              distanceInKilometers: 42.5,
            ),
          ],
        );

    expect(statistics.allTime.gamesPlayed, 1);
    expect(statistics.allTime.questionsPlayed, 2);
    expect(statistics.allTime.correctAnswers, 1);
    expect(statistics.allTime.bestStreak, 1);
    expect(statistics.statisticsForTheme('capital').questionsPlayed, 1);
    expect(statistics.statisticsForContinent('europe').correctAnswers, 1);
    expect(statistics.statisticsForCountry('JPN').correctAnswers, 0);
    expect(statistics.statisticsForMode('mixed').gamesPlayed, 1);
    expect(statistics.statisticsForDifficulty('hard').questionsPlayed, 2);
    expect(
      statistics
          .statisticsForRecentDays(7, now: DateTime(2026, 8, 29))
          .questionsPlayed,
      2,
    );
  });

  test('la sérialisation détaillée conserve distances et séries', () {
    final DetailedPlayerStatistics original = DetailedPlayerStatistics
        .initial()
        .registerGame(
          modeId: 'find_capital',
          difficultyId: 'expert',
          playedAt: DateTime(2026, 8, 28),
          questions: const <QuestionStatisticsResult>[
            QuestionStatisticsResult(
              countryId: 'ESP',
              continentId: 'europe',
              themeId: 'capital',
              isCorrect: true,
              elapsedSeconds: 6,
              distanceInKilometers: 3.2,
            ),
            QuestionStatisticsResult(
              countryId: 'PRT',
              continentId: 'europe',
              themeId: 'capital',
              isCorrect: true,
              elapsedSeconds: 5,
              distanceInKilometers: 1.4,
            ),
          ],
        );

    final DetailedPlayerStatistics restored =
        DetailedPlayerStatistics.fromJson(original.toJson());

    expect(restored.allTime.bestDistanceInKilometers, 1.4);
    expect(restored.allTime.currentStreak, 2);
    expect(restored.allTime.bestStreak, 2);
    expect(restored.allTime.placementsUnder10Kilometers, 2);
    expect(restored.allTime.placementsUnder50Kilometers, 2);
    expect(restored.statisticsForCountry('ESP').questionsPlayed, 1);
    expect(restored.byDay, hasLength(1));
  });

  test('une ancienne sauvegarde garde tous ses compteurs', () {
    final PlayerProfile migrated = PlayerProfile.fromJson(<String, dynamic>{
      'schemaVersion': 2,
      'playerId': 'local_player',
      'displayName': 'Voyageur',
      'avatarId': 'default',
      'totalXp': 18010,
      'gamesPlayed': 180,
      'correctAnswers': 640,
      'totalAnswers': 900,
      'totalScore': 56000,
      'totalDistanceInKilometers': 12345.5,
      'totalElapsedSeconds': 45678,
      'createdAt': '2026-01-01T00:00:00.000',
    });

    expect(migrated.schemaVersion, PlayerProfile.currentSchemaVersion);
    expect(migrated.totalXp, 0);
    expect(migrated.gamesPlayed, 180);
    expect(migrated.correctAnswers, 640);
    expect(migrated.totalAnswers, 900);
    expect(migrated.totalElapsedSeconds, 45678);
    expect(migrated.detailedStatistics.allTime.questionsPlayed, 0);
  });

  test('le profil enregistre le vrai mode et la vraie difficulté', () {
    final PlayerProfile updated = PlayerProfile.initial(
      createdAt: DateTime(2026, 1, 1),
    ).registerGameResult(
      earnedXp: 100,
      updatedXpLedger: const PlayerXpLedger(),
      gameScore: 500,
      gameCorrectAnswers: 1,
      gameTotalAnswers: 2,
      modeId: 'find_flag',
      difficultyId: 'intermediate',
      gameDistanceInKilometers: 20,
      gameElapsedSeconds: 12,
      playedAt: DateTime(2026, 8, 29),
      questionResults: const <QuestionStatisticsResult>[
        QuestionStatisticsResult(
          countryId: 'FRA',
          continentId: 'europe',
          themeId: 'flag',
          isCorrect: true,
          elapsedSeconds: 5,
        ),
        QuestionStatisticsResult(
          countryId: 'ESP',
          continentId: 'europe',
          themeId: 'flag',
          isCorrect: false,
          elapsedSeconds: 7,
          distanceInKilometers: 20,
        ),
      ],
    );

    expect(updated.statisticsForMode('find_flag').gamesPlayed, 1);
    expect(
      updated
          .statisticsForMode('find_flag')
          .statisticsForDifficulty('intermediate')
          .questionsPlayed,
      2,
    );
    expect(updated.detailedStatistics.statisticsForTheme('flag').correctAnswers, 1);
  });

  test('une question Silhouettes enrichit les totaux sans créer de partie', () {
    final PlayerProfile updated =
        PlayerProfile.initial().registerStandaloneQuestionResult(
      modeId: 'ultimate',
      difficultyId: 'easy',
      answeredAt: DateTime(2026, 8, 29),
      result: const QuestionStatisticsResult(
        countryId: 'BRA',
        continentId: 'americas',
        themeId: 'silhouette',
        isCorrect: true,
        elapsedSeconds: 4,
      ),
    );

    expect(updated.gamesPlayed, 0);
    expect(updated.totalAnswers, 1);
    expect(updated.correctAnswers, 1);
    expect(updated.detailedStatistics.allTime.gamesPlayed, 0);
    expect(updated.detailedStatistics.allTime.questionsPlayed, 1);
    expect(
      updated.detailedStatistics.statisticsForTheme('silhouette').correctAnswers,
      1,
    );
  });
}

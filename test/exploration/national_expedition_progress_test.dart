import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/exploration/france/national_expedition_progress.dart';

void main() {
  test('une ancienne sauvegarde France conserve sa progression', () {
    final NationalExpeditionProgress progress =
        NationalExpeditionProgress.fromJson(<String, dynamic>{
      'starsByLevel': <String, int>{'france_regions_1': 2},
      'bestScoresByLevel': <String, int>{'france_regions_1': 420},
    });

    expect(progress.starsFor('france_regions_1'), 2);
    expect(progress.bestScore, 420);
    expect(progress.gamesPlayed, 0);
    expect(progress.accuracyPercent, 0);
  });

  test('les statistiques France cumulent les parties terminées', () {
    final NationalExpeditionProgress progress =
        NationalExpeditionProgress.initial()
            .register(
              levelId: 'regions',
              stars: 2,
              score: 500,
              correctAnswers: 7,
              totalAnswers: 10,
            )
            .register(
              levelId: 'departements',
              stars: 1,
              score: 350,
              correctAnswers: 5,
              totalAnswers: 10,
            );

    expect(progress.gamesPlayed, 2);
    expect(progress.correctAnswers, 12);
    expect(progress.totalAnswers, 20);
    expect(progress.accuracyPercent, 60);
    expect(progress.bestScore, 500);
  });
}
